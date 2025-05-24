#!/bin/bash
set -e

echo "=== CompanionPi System Check ==="

echo ""
echo "[Systemd Services]"
for svc in netconfig config-web dnsmasq; do
  if systemctl list-units --type=service | grep -q "$svc"; then
    systemctl is-active "$svc" && echo "$svc: active" || echo "$svc: inactive or failed"
  else
    echo "$svc: not installed"
  fi
done

echo ""
echo "[Interfaces & IP Addresses]"
for iface in $(ls /sys/class/net | grep -E '^eth|^wlan'); do
  ip=$(ip -4 addr show "$iface" | grep -oP '(?<=inet\s)\d+(\.\d+){3}' || true)
  state=$(cat "/sys/class/net/$iface/operstate")
  echo "$iface: $ip ($state)"
done

echo ""
echo "[Active nmcli Connections]"
nmcli -t -f NAME,DEVICE,STATE connection show --active || echo "No active connections."

echo ""
echo "[Configured Connections Check]"
for iface in $(ls /sys/class/net | grep -E '^eth|^wlan'); do
  for mode in auto fix ap; do
    name="${iface}-${mode}"
    if nmcli connection show "$name" &>/dev/null; then
      echo "$name: OK"
    else
      echo "$name: MISSING"
    fi
  done
done

echo ""
echo "[WiFi SSID]"
nmcli -t -f DEVICE,STATE,CONNECTION dev status | grep wlan || echo "No wlan interface connected."

echo ""
echo "[dnsmasq status]"
if pgrep dnsmasq >/dev/null; then
  echo "dnsmasq: running"
  echo "Configured interfaces in /etc/dnsmasq.d:"
  grep -h 'interface=' /etc/dnsmasq.d/*.conf 2>/dev/null || echo "No interface entries found"
else
  echo "dnsmasq: not running"
fi

echo ""
echo "[Open TCP Ports (DNS 53, DHCP 67, Flask 8001)]"
ss -tuln | grep -E ':53|:67|:8001' || echo "No relevant ports are open."

echo ""
echo "=== Check complete ==="
