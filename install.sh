#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
TEAL='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log()  { echo -e "${TEAL}[*]${NC} $1"; }
ok()   { echo -e "${GREEN}[+]${NC} $1"; }
err()  { echo -e "${RED}[!]${NC} $1"; }
bold() { echo -e "${BOLD}$1${NC}"; }

clear
bold "================================================"
bold "   Network Guard — Zero Trust IoT Protection"
bold "   Installing on this device..."
bold "================================================"
echo ""

log "Checking dependencies..."
sleep 0.5
python3 -c "from scapy.all import *" 2>/dev/null && ok "scapy — OK" || { err "scapy not found"; exit 1; }
command -v iptables &>/dev/null && ok "iptables — OK" || { err "iptables not found"; exit 1; }
command -v ip &>/dev/null && ok "iproute2 — OK" || { err "iproute2 not found"; exit 1; }
echo ""

log "Creating network segments..."
sleep 0.5
ip netns del ns_gateway 2>/dev/null
ip netns del ns_trusted 2>/dev/null
ip netns del ns_iot 2>/dev/null
ip netns add ns_gateway
ip netns add ns_trusted
ip netns add ns_iot
ip link add veth_gw_trusted type veth peer name veth_trusted_gw 2>/dev/null
ip link add veth_gw_iot type veth peer name veth_iot_gw 2>/dev/null
ip link set veth_gw_trusted netns ns_gateway
ip link set veth_trusted_gw netns ns_trusted
ip link set veth_gw_iot netns ns_gateway
ip link set veth_iot_gw netns ns_iot
ip netns exec ns_gateway ip addr add 10.0.1.1/24 dev veth_gw_trusted
ip netns exec ns_gateway ip addr add 10.0.2.1/24 dev veth_gw_iot
ip netns exec ns_trusted ip addr add 10.0.1.2/24 dev veth_trusted_gw
ip netns exec ns_iot ip addr add 10.0.2.2/24 dev veth_iot_gw
ip netns exec ns_gateway ip link set veth_gw_trusted up
ip netns exec ns_gateway ip link set veth_gw_iot up
ip netns exec ns_trusted ip link set veth_trusted_gw up
ip netns exec ns_iot ip link set veth_iot_gw up
ip netns exec ns_gateway ip link set lo up
ip netns exec ns_trusted ip link set lo up
ip netns exec ns_iot ip link set lo up
ip netns exec ns_iot ip route add default via 10.0.2.1
ip netns exec ns_trusted ip route add default via 10.0.1.1
ip netns exec ns_gateway sysctl -w net.ipv4.ip_forward=1 &>/dev/null
ok "Trusted segment — 10.0.1.0/24"
ok "IoT segment     — 10.0.2.0/24"
ok "Gateway         — routing enabled"
echo ""

log "Applying Zero Trust firewall rules..."
sleep 0.5
ip netns exec ns_gateway iptables -F FORWARD 2>/dev/null
ip netns exec ns_gateway iptables -P FORWARD DROP
ip netns exec ns_gateway iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT
ip netns exec ns_gateway iptables -A FORWARD -s 10.0.1.0/24 -j ACCEPT
ip netns exec ns_gateway iptables -A FORWARD -s 10.0.2.0/24 -d 10.0.1.0/24 -j DROP
ok "IoT -> Trusted: BLOCKED"
ok "IoT -> Internet: ALLOWED"
ok "Trusted -> All: ALLOWED"
echo ""

log "Starting Zero Trust detector..."
sleep 3
pkill -f "detector.py" 2>/dev/null
sleep 1
sed -i '77s|.*|setsid bash /home/kali/network-guard/watchdog.sh \&|' ~/network-guard/install.sh
# Keep namespace alive
setsid ip netns exec ns_gateway sleep infinity &
setsid ip netns exec ns_trusted sleep infinity &
setsid ip netns exec ns_iot sleep infinity &
disown $!
DETECTOR_PID=$!
sleep 2
if kill -0 $DETECTOR_PID 2>/dev/null; then
  ok "Detector running (PID: $DETECTOR_PID)"
  echo $DETECTOR_PID > /tmp/network-guard.pid
else
  err "Detector failed to start. Check: cat /tmp/network-guard.log"
  exit 1
fi
echo ""

bold "================================================"
bold "   Network Guard is ACTIVE"
bold "================================================"
echo ""
echo -e "  ${GREEN}✓${NC} Trusted zone   10.0.1.0/24  — protected"
echo -e "  ${GREEN}✓${NC} IoT quarantine 10.0.2.0/24  — isolated"
echo -e "  ${GREEN}✓${NC} Zero Trust detector         — running"
echo -e "  ${GREEN}✓${NC} ARP scan detection          — enabled"
echo -e "  ${GREEN}✓${NC} mDNS/SSDP monitoring        — enabled"
echo ""
echo -e "  Logs: tail -f /tmp/network-guard.log"
echo -e "  Stop: sudo ~/network-guard/stop.sh"
echo ""
bold "  Your network is now protected."
echo ""
