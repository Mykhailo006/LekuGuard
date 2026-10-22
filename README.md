[README.md](https://github.com/user-attachments/files/33842021/README.md)
# Network Guard — Zero Trust IoT Protection

A hands-on demo of a **Zero Trust micro-segmentation network** with real-time
ARP spoofing detection and automatic blocking — built with Linux network
namespaces, `iptables`, and Scapy.

The idea: an IoT device (a "smart lightbulb") sits on its own network segment,
isolated from a trusted device by default. If the IoT device is compromised
and tries to perform a **Man-in-the-Middle ARP spoofing attack** — impersonating
the gateway to intercept traffic — the detector catches the forged packet and
blocks the attacker's MAC address before any real damage is done.

## How it works

```
┌─────────────┐        ┌─────────────┐        ┌─────────────┐
│   Trusted   │◄──────►│   Gateway   │◄──────►│     IoT     │
│ 10.0.1.2/24 │        │  10.0.1.1   │        │ 10.0.2.2/24 │
│             │        │  10.0.2.1   │        │ (quarantine)│
└─────────────┘        └─────────────┘        └─────────────┘
```

- **`setup_network.sh`** — builds three isolated `netns` namespaces (gateway,
  trusted, IoT) connected by veth pairs, simulating a segmented home/office
  network.
- **`install.sh`** — one-command setup: creates the namespaces and applies
  Zero Trust `iptables` rules (IoT → Trusted is blocked by default, IoT →
  Internet is allowed, Trusted → everything is allowed).
- **`detector.py`** — sniffs ARP traffic on the gateway-IoT link. It
  distinguishes normal ARP chatter (a device announcing itself, asking
  "who has this IP") from a genuine spoofing attempt: a forged ARP **reply**
  claiming to *be* the gateway's IP while using a different MAC address.
  Only real spoofing gets blocked — by MAC address, via `iptables -m mac`.
- **`arp_attack.py`** — simulates a compromised IoT device launching an ARP
  spoofing attack against the trusted device, impersonating the gateway.
- **`connect_iot.sh`** — simulates a normal, legitimate device announcing
  itself on the network (used to verify the detector doesn't false-positive
  on everyday traffic).
- **`api.py`** — a small Flask API that tails the detector's log and exposes
  `/api/status`, `/api/devices`, and `/api/alerts` for a live dashboard
  (`app.html`).
- **`watchdog.sh`** — keeps the detector alive, restarting it if it crashes.

## Quick start

Requires Kali Linux (or any Linux with `iptables`, `ip netns`, Python 3, and
Scapy).

```bash
sudo ./install.sh     # one-time setup: namespaces + firewall rules
sudo ./start.sh       # starts the detector + API
```

Then open `http://localhost:5000` for the live dashboard.

### Run the attack demo

```bash
sudo ip netns exec ns_iot python3 arp_attack.py
```

Watch `tail -f /tmp/network-guard.log` — you'll see the forged packet get
flagged and the attacker's MAC blocked within milliseconds.

### Verify normal traffic isn't affected

```bash
sudo ./connect_iot.sh
```

This should only log the device as "quarantined" (new device seen), never
blocked — normal ARP announcements are not attacks.

### Stop everything

```bash
sudo ./stop.sh
```

## Detection logic

ARP spoofing has a specific signature: an attacker sends an ARP **reply**
(`op=2`, "is-at") claiming the gateway's IP address, but signed with its own
MAC address instead of the gateway's real one. `detector.py` flags exactly
this pattern — not just "any ARP packet from a non-gateway device", which
would also catch perfectly normal network behavior (every device has to ARP
for the gateway before it can send it anything).

```python
if op == 2 and src_ip == GATEWAY_IP and src_mac != gw_mac:
    # genuine spoofing attempt — block by MAC
```

Because the spoofed packet's source IP is deliberately faked to match the
gateway, blocking is done by **MAC address**, not IP.

## Disclaimer

This project is for educational / demo purposes — showing Zero Trust network
segmentation and attack detection concepts in an isolated lab environment
(Linux network namespaces). Don't run the attack script against real networks
or devices you don't own or have permission to test.
