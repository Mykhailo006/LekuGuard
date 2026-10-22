#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
TEAL='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log()  { echo -e "${TEAL}[*]${NC} $1"; }
ok()   { echo -e "${GREEN}[+]${NC} $1"; }
bold() { echo -e "${BOLD}$1${NC}"; }

clear
bold "================================================"
bold "   Network Guard — Starting all services..."
bold "================================================"
echo ""

log "Setting up network..."
sudo /home/kali/network-guard/install.sh > /dev/null 2>&1
ok "Network ready"
echo ""

log "Starting detector..."
sudo ip netns exec ns_gateway python3 /home/kali/network-guard/detector.py >> /tmp/network-guard.log 2>&1 &
DETECTOR_PID=$!
sleep 2
if kill -0 $DETECTOR_PID 2>/dev/null; then
  ok "Detector running (PID: $DETECTOR_PID)"
else
  echo -e "${RED}[!]${NC} Detector failed"
  exit 1
fi
echo ""

log "Starting API..."
pkill -f api.py 2>/dev/null
sleep 0.5
python3 /home/kali/network-guard/api.py > /tmp/api.log 2>&1 &
API_PID=$!
sleep 1
if kill -0 $API_PID 2>/dev/null; then
  ok "API running (PID: $API_PID)"
else
  echo -e "${RED}[!]${NC} API failed"
  exit 1
fi
echo ""

bold "================================================"
bold "   Everything is running"
bold "================================================"
echo ""
echo -e "  ${GREEN}v${NC} Network segmentation — active"
echo -e "  ${GREEN}v${NC} Zero Trust detector  — active"
echo -e "  ${GREEN}v${NC} API                  — http://localhost:5000"
echo ""
echo -e "  Logs: tail -f /tmp/network-guard.log"
echo -e "  Stop: sudo /home/kali/network-guard/stop.sh"
echo ""
bold "  Attack demo command:"
echo ""
echo -e "  ${TEAL}sudo ip netns exec ns_iot python3 /home/kali/network-guard/arp_attack.py${NC}"
echo ""
