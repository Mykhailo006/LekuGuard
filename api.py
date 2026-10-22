#!/usr/bin/env python3
from flask import Flask, jsonify
from flask_cors import CORS
import re, os

app = Flask(__name__)
CORS(app, origins="*")

@app.after_request
def add_headers(response):
    response.headers['ngrok-skip-browser-warning'] = 'true'
    response.headers['Access-Control-Allow-Origin'] = '*'
    return response
LOG_FILE = "/tmp/network-guard.log"
PID_FILE = "/tmp/network-guard.pid"

def detector_alive():
    try:
        pid = int(open(PID_FILE).read().strip())
        os.kill(pid, 0)
        return True
    except:
        return False

def parse_log():
    alerts = []
    devices = {}
    if not os.path.exists(LOG_FILE):
        return devices, alerts
    with open(LOG_FILE, "r") as f:
        lines = f.readlines()
    for line in lines:
        line = line.strip()
        if not line or line.startswith("WARNING"):
            continue
        m = re.match(r'\[(\d{2}:\d{2}:\d{2})\] (.+)', line)
        if not m:
            continue
        time, msg = m.groups()
        if "BLOCKED" in msg:
            ip = re.search(r'BLOCKED (\S+)', msg)
            if ip:
                devices[ip.group(1)] = "blocked"
            alerts.append({"time": time, "type": "danger", "msg": msg})
        elif "QUARANTINE" in msg:
            ip = re.search(r'new device (\S+)', msg)
            if ip and ip.group(1) not in devices:
                devices[ip.group(1)] = "quarantine"
            alerts.append({"time": time, "type": "warning", "msg": msg})
        elif "ARP from IoT" in msg:
            ip = re.search(r'ARP from IoT (\S+)', msg)
            if ip and ip.group(1) not in devices:
                devices[ip.group(1)] = "blocked"
            alerts.append({"time": time, "type": "danger", "msg": msg})
        elif "Network Guard started" in msg:
            alerts.append({"time": time, "type": "info", "msg": msg})
    return devices, alerts

@app.route('/api/status')
def status():
    devices, _ = parse_log()
    blocked_count = sum(1 for v in devices.values() if v == "blocked")
    quarantine_count = sum(1 for v in devices.values() if v == "quarantine")
    alive = detector_alive()
    if not alive:
        status_val = "offline"
    elif blocked_count > 0:
        status_val = "alert"
    elif quarantine_count > 0:
        status_val = "warning"
    else:
        status_val = "protected"
    return jsonify({
        "status": status_val,
        "detector": alive,
        "blocked": blocked_count,
        "quarantine": quarantine_count,
        "trusted": 2
    })

@app.route('/api/devices')
def devices():
    devs, _ = parse_log()
    result = [
        {"ip": "10.0.1.2", "name": "Laptop", "status": "trusted"},
        {"ip": "10.0.1.1", "name": "Gateway", "status": "trusted"}
    ]
    for ip, st in devs.items():
        result.append({"ip": ip, "name": "Smart Bulb", "status": st})
    return jsonify(result)

@app.route('/api/alerts')
def alerts():
    _, alert_list = parse_log()
    return jsonify(list(reversed(alert_list))[:20])

@app.route('/api/reset', methods=['POST'])
def reset():
    try:
        with open(LOG_FILE, 'w') as f:
            f.write('')
        return jsonify({"status": "ok"})
    except Exception as e:
        return jsonify({"status": "error", "msg": str(e)}), 500

@app.route('/')
@app.route('/app')
def serve_app():
    return open('/home/kali/network-guard/app.html').read()

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
