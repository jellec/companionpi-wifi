#!/bin/bash
set -e

echo "=== CompanionPi Network Status ==="

# ETH0
echo
echo "[ETH0]"
nmcli device show eth0 | grep -E 'GENERAL.STATE|IP4.ADDRESS\[|IP4.GATEWAY' || echo "eth0 not connected"

# WLAN0
echo
echo "[WLAN0]"
nmcli device show wlan0 | grep -E 'GENERAL.STATE|IP4.ADDRESS\[|IP4.GATEWAY|WI-FI.SSID' || echo "wlan0 not connected"

# Active connections
echo
echo "[Active connections]"
nmcli connection show --active

# IP addresses
echo
echo "[IP Addresses]"
nmcli -f DEVICE,STATE,IP4.ADDRESS dev show | grep -v "::" || echo "No IPv4 addresses assigned"

echo
echo "Check complete."