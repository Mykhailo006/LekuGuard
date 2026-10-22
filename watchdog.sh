#!/bin/bash
while true; do
  if ! ip netns exec ns_gateway python3 /home/kali/network-guard/detector.py >> /tmp/network-guard.log 2>&1; then
    echo "[$(date +%H:%M:%S)] Detector crashed, restarting..." >> /tmp/network-guard.log
    sleep 2
  fi
done
