#!/usr/bin/env python3
from scapy.all import sniff, ARP, IP, UDP, get_if_hwaddr
import subprocess, datetime, os

MULTICAST_PORTS = {5353: "mDNS", 1900: "SSDP"}
GATEWAY_IP = "10.0.2.1"
LOG_FILE = "/tmp/network-guard.log"

blocked_macs = set()   # MAC-адреса, которые мы заблокировали
seen = set()           # IP, которые уже видели (для QUARANTINE-лога)

def log(msg):
    t = datetime.datetime.now().strftime("%H:%M:%S")
    line = f"[{t}] {msg}"
    # Только print: start.sh/watchdog.sh и так запускают detector.py с
    # редиректом ">> LOG_FILE", так что ручная запись в файл здесь
    # приводила к дублированию каждой строки лога.
    print(line, flush=True)

def block_mac(mac, reason):
    """Блокируем по MAC-адресу, т.к. при ARP-спуфинге IP подделан
    (атакующий выдаёт себя за GATEWAY_IP), а MAC — нет."""
    if mac in blocked_macs:
        return
    blocked_macs.add(mac)
    result = subprocess.run([
        "ip", "netns", "exec", "ns_gateway",
        "iptables", "-I", "FORWARD",
        "-m", "mac", "--mac-source", mac,
        "-j", "DROP"
    ], capture_output=True, text=True)
    if result.returncode != 0:
        log(f"ERROR blocking {mac}: {result.stderr.strip()}")
    else:
        log(f"BLOCKED {mac} | {reason}")

def analyze(pkt):
    if pkt.haslayer(ARP):
        src_ip  = pkt[ARP].psrc
        src_mac = pkt[ARP].hwsrc
        op      = pkt[ARP].op  # 1 = who-has (запрос), 2 = is-at (ответ)

        try:
            gw_mac = get_if_hwaddr("veth_gw_iot")
        except Exception:
            gw_mac = ""

        # Трафик от самого шлюза — пропускаем молча
        if src_mac == gw_mac:
            return

        # Новое устройство в сети — просто фиксируем, НЕ блокируем.
        # Обычный ARP (who-has/is-at про себя самого) — это нормальная
        # часть работы сети, а не атака.
        if src_ip not in seen and src_mac not in blocked_macs:
            seen.add(src_ip)
            log(f"QUARANTINE: new device {src_ip} ({src_mac}) — isolated automatically")

        # Настоящий признак ARP-спуфинга: кто-то отвечает (op=2),
        # утверждая, что IP шлюза принадлежит ему, хотя MAC — не шлюзовский.
        # Логируем и баним только один раз на MAC — иначе на каждый
        # следующий поддельный пакет лог будет спамиться заново.
        if op == 2 and src_ip == GATEWAY_IP and src_mac != gw_mac:
            if src_mac not in blocked_macs:
                log(f"ARP SPOOF: {src_mac} claims to be gateway {GATEWAY_IP}")
                block_mac(src_mac, "ARP spoofing: fake gateway identity")

    if pkt.haslayer(IP):
        src_ip = pkt[IP].src
        if src_ip != GATEWAY_IP and src_ip not in seen:
            seen.add(src_ip)
            log(f"QUARANTINE: new device {src_ip} — isolated automatically")

    if pkt.haslayer(UDP) and pkt.haslayer(IP):
        port = pkt[UDP].dport
        src_ip = pkt[IP].src
        if port in MULTICAST_PORTS and src_ip != GATEWAY_IP:
            log(f"{MULTICAST_PORTS[port]} from {src_ip} — device revealing itself")

log("Network Guard started — Zero Trust mode")
log("Monitoring: ARP + mDNS + SSDP on veth_gw_iot")
log("-" * 50)

sniff(iface="veth_gw_iot", prn=analyze, store=False)
