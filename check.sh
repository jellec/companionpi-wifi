#!/bin/bash
set -e

SETTINGS_FILE="/etc/companionpi/settings.env"

echo "=== CompanionPi System Check (Extended) ==="
echo ""

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
echo "[Interfaces & IP Addresses]"
for iface in $(ls /sys/class/net | grep -E '^eth|^wlan'); do
  ip=$(ip -4 addr show "$iface" | grep -oP '(?<=inet\s)\d+(\.\d+){3}' || true)
  mac=$(cat /sys/class/net/$iface/address)
  state=$(cat "/sys/class/net/$iface/operstate")
  echo "$iface: IP=$ip, MAC=$mac ($state)"
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
echo "[dnsmasq Status]"
if pgrep dnsmasq >/dev/null; then
  echo "dnsmasq: running"
  echo "Configured interfaces in /etc/dnsmasq.d:"
  grep -h 'interface=' /etc/dnsmasq.d/*.conf 2>/dev/null || echo "No interface entries found"
else
  echo "dnsmasq: not running"
fi

echo ""
echo "[DHCP Leases]"
for leasefile in /var/lib/misc/dnsmasq.leases*; do
  if [ -f "$leasefile" ]; then
    echo "$leasefile:"
    cat "$leasefile"
  fi
done

echo ""
echo "[/etc/companionpi/settings.env]"
if [ -f "$SETTINGS_FILE" ]; then
  grep -v '^#' "$SETTINGS_FILE" | grep -v '^$'
else
  echo "settings.env not found."
fi

echo ""
echo "[Recent Logs: netconfig.service]"
journalctl -u netconfig.service --no-pager -n 10 || echo "No logs found."

echo ""
echo "[Recent Logs: dnsmasq]"
journalctl -u dnsmasq --no-pager -n 10 || echo "No logs found."

echo ""
echo "[Open TCP/UDP Ports]"
ss -tuln | grep -E ':53|:67|:8001' || echo "No relevant ports are open."

echo ""
echo "=== Full Check Complete ==="
