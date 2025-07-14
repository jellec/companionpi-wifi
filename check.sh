#!/bin/bash
set -e

SETTINGS_FILE="/etc/companionpi-wifi/settings.env"

echo ""
echo ""
echo "=== CompanionPi-WiFi System Check ==="
echo ""

# 1. Systemd Services
echo "[Systemd Services]"
for svc in netconfig config-web dnsmasq; do
  if systemctl list-units --type=service | grep -q "$svc"; then
    status=$(systemctl is-active "$svc")
    echo "$svc: $status"
  else
    echo "$svc: not installed"
  fi
done

echo ""
# 2. Interfaces & IPs
echo "[Interfaces & IP Configuration]"
for iface in $(ls /sys/class/net | grep -E '^eth|^wlan'); do
  ip=$(ip -4 addr show "$iface" | grep -oP '(?<=inet\s)\d+(\.\d+){3}' || echo "-")
  mac=$(cat /sys/class/net/$iface/address)
  state=$(cat "/sys/class/net/$iface/operstate")
  gw=$(nmcli -g IP4.GATEWAY device show "$iface" 2>/dev/null | grep -v '^--' || echo "-")
  dns=$(nmcli -g IP4.DNS device show "$iface" 2>/dev/null | grep -v '^--' | paste -sd "," - || echo "-")
  echo "$iface: IP=$ip, MAC=$mac, GATEWAY=$gw, DNS=$dns ($state)"
done

echo ""
# 3. Active connections
echo "[Active nmcli Connections]"
nmcli -t -f NAME,DEVICE,STATE connection show --active || echo "No active connections."

echo ""
# 4. Expected connection profiles
echo "[Configured Connection Profiles]"
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
# 5. Wi-Fi status
echo "[WiFi Status (nmcli)]"
nmcli -t -f DEVICE,STATE,CONNECTION dev status | grep wlan || echo "No wlan interface connected."

echo ""
# 6. dnsmasq
echo "[dnsmasq Status]"
if pgrep dnsmasq >/dev/null; then
  echo "dnsmasq: running"
  echo "Configured interfaces in /etc/dnsmasq.d:"
  grep -h 'interface=' /etc/dnsmasq.d/*.conf 2>/dev/null || echo "No interface entries found"
else
  echo "dnsmasq: not running"
fi

echo ""
# 7. DHCP leases
echo "[DHCP Leases]"
for leasefile in /var/lib/misc/dnsmasq.leases*; do
  if [ -f "$leasefile" ]; then
    echo "$leasefile:"
    cat "$leasefile"
  fi
done

echo ""
# 8. Settings file
echo "[/etc/companionpi-wifi/settings.env]"
if [ -f "$SETTINGS_FILE" ]; then
  grep -E '^(NETCONFIG_SKIP_INTERFACES|WIFI_COUNTRY)' "$SETTINGS_FILE" || true
  echo "--- full (non-comment) dump:"
  grep -v '^#' "$SETTINGS_FILE" | grep -v '^$'
else
  echo "settings.env not found."
fi

echo ""
# 9. Logs
echo "[Recent Logs: netconfig.service]"
journalctl -u netconfig.service --no-pager -n 10 || echo "No logs found."

echo ""
echo "[Recent Logs: dnsmasq]"
journalctl -u dnsmasq --no-pager -n 10 || echo "No logs found."

echo ""
# 10. Open ports
echo "[Open TCP/UDP Ports (dns:53, dhcp:67, flask:8001)]"
ss -tuln | grep -E ':53|:67|:8001' || echo "No relevant ports are open."

echo ""
echo "=== System Check Complete ==="
echo ""
echo ""
