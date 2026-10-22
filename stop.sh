#!/bin/bash
echo "[*] Stopping Network Guard..."
sudo pkill -9 -f "detector.py" 2>/dev/null
sudo pkill -9 -f "watchdog.sh" 2>/dev/null
sleep 1
sudo ip netns del ns_gateway 2>/dev/null
sudo ip netns del ns_trusted 2>/dev/null
sudo ip netns del ns_iot 2>/dev/null
rm -f /tmp/network-guard.pid /tmp/network-guard.log
echo "[+] Network Guard stopped."
screen -S ng-detector -X quit 2>/dev/null
