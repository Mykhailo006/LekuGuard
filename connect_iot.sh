#!/bin/bash
# Simulates IoT device connecting to network
echo "[*] IoT device connecting to network..."
sudo ip netns exec ns_iot python3 -c "
from scapy.all import *
# Send gratuitous ARP — device announcing itself
pkt = ARP(op=1, pdst='10.0.2.1', psrc='10.0.2.2')
sendp(Ether(dst='ff:ff:ff:ff:ff:ff')/pkt, iface='veth_iot_gw', verbose=False)
print('[+] IoT device announced itself on network')
"
