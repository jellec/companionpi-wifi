#!/usr/bin/env python3
import os
import time
import subprocess

timeout = 30
fallback_ip = "192.168.10.1/24"

print(f"Waiting for DHCP lease on eth0 ({timeout}s)...")
for i in range(timeout):
    result = subprocess.run(["ip", "addr", "show", "eth0"], capture_output=True, text=True)
    if "inet " in result.stdout:
        print("DHCP successful.")
        break
    time.sleep(1)
else:
    print("No DHCP lease. Assigning fallback IP.")
    subprocess.run(["ip", "addr", "add", fallback_ip, "dev", "eth0"])
    subprocess.run(["ip", "link", "set", "eth0", "up"])
