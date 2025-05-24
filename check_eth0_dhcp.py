#!/usr/bin/env python3
import os
import time
import subprocess

# Load settings.env
settings = {}
from pathlib import Path
settings_file = Path(__file__).parent.parent / "settings.env"
with open(settings_file) as f:
    for line in f:
        if '=' in line and not line.strip().startswith('#'):
            key, val = line.strip().split('=', 1)
            settings[key] = val

timeout = int(settings.get("ETH0_TIMEOUT", 30))
fallback_ip = settings.get("ETH0_FALLBACK_IP", "192.168.10.1")
subnet = settings.get("ETH0_SUBNET", "255.255.255.0")

print(f"Waiting for DHCP lease on eth0 ({timeout}s)...")
for i in range(timeout):
    result = subprocess.run(["ip", "addr", "show", "eth0"], capture_output=True, text=True)
    if "inet " in result.stdout:
        print("DHCP successful.")
        break
    time.sleep(1)
else:
    print("No DHCP lease. Assigning fallback IP.")
    subprocess.run(["ip", "addr", "add", f"{fallback_ip}/24", "dev", "eth0"])
    subprocess.run(["ip", "link", "set", "eth0", "up"])