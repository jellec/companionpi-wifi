#!/bin/bash
# netconfig.sh – Configure Ethernet and Wi-Fi interfaces at boot

set -e

SETTINGS_FILE="/etc/companionpi/settings.env"
source "$SETTINGS_FILE"

log() {
  echo ""
  echo "[netconfig] $1"
}

# ================================
# Ethernet (currently disabled)
# ================================
# configure_eth_interface() {
#   IFACE=$1
#   PREFIX=${IFACE^^}
#   MODE_VAR="${PREFIX}_MODE"
#   TIMEOUT_VAR="${PREFIX}_TIMEOUT"
#   FALLBACK_VAR="${PREFIX}_FALLBACK_IP"
#   AUTO_CONN="${IFACE}-auto"
#   FIX_CONN="${IFACE}-fix"
#
#   MODE=${!MODE_VAR:-auto}
#   TIMEOUT=${!TIMEOUT_VAR:-30}
#   FALLBACK_IP=${!FALLBACK_VAR}
#
#   log "Configuring $IFACE in mode: $MODE"
#
#   # Clean up previous connections
#   nmcli connection delete "$AUTO_CONN" &>/dev/null || true
#   nmcli connection delete "$FIX_CONN" &>/dev/null || true
#
#   # Create both profiles
#   nmcli connection add type ethernet ifname "$IFACE" con-name "$AUTO_CONN" ipv4.method auto
#   nmcli connection add type ethernet ifname "$IFACE" con-name "$FIX_CONN" ipv4.method manual ipv4.addresses "$FALLBACK_IP"
#
#   if [[ "$MODE" == "fix" ]]; then
#     log "$IFACE: Static mode – activating static IP"
#     nmcli connection up "$FIX_CONN"
#   elif [[ "$MODE" == "auto" ]]; then
#     log "$IFACE: Attempting DHCP first..."
#     nmcli connection up "$AUTO_CONN"
#     sleep "$TIMEOUT"
#
#     if ip addr show "$IFACE" | grep -q 'inet '; then
#       log "$IFACE obtained DHCP IP"
#     else
#       log "$IFACE: No DHCP after $TIMEOUT sec – switching to fallback"
#       nmcli connection up "$FIX_CONN"
#     fi
#   else
#     log "$IFACE: Unknown mode '$MODE' – skipping"
#   fi
# }
#!/bin/bash
# netconfig.sh – Configure Wi-Fi interfaces at boot (eth0 is ignored for now)


configure_wlan_interface() {
  IFACE=$1
  PREFIX=${IFACE^^}

  MODE_VAR="${PREFIX}_MODE"
  TIMEOUT_VAR="${PREFIX}_TIMEOUT"
  CLIENT_PROFILES_VAR="${PREFIX}_CLIENT_PROFILES[@]"
  SSID_VAR="${PREFIX}_AP_SSID"
  PASS_VAR="${PREFIX}_AP_PASSWORD"
  IP_VAR="${PREFIX}_AP_IP"

  DHCP_ENABLED_VAR="${PREFIX}_DHCP_SERVER_ENABLED"
  DHCP_START_VAR="${PREFIX}_DHCP_RANGE_START"
  DHCP_END_VAR="${PREFIX}_DHCP_RANGE_END"
  DHCP_LEASE_VAR="${PREFIX}_DHCP_LEASE_TIME"
  DHCP_ROUTER_VAR="${PREFIX}_DHCP_ROUTER"
  DHCP_DNS_VAR="${PREFIX}_DHCP_DNS"

  MODE=${!MODE_VAR}
  TIMEOUT=${!TIMEOUT_VAR:-30}
  SSID=${!SSID_VAR}
  PASS=${!PASS_VAR}
  IP=${!IP_VAR}

  DHCP_ENABLED=${!DHCP_ENABLED_VAR}
  DHCP_START=${!DHCP_START_VAR}
  DHCP_END=${!DHCP_END_VAR}
  DHCP_LEASE=${!DHCP_LEASE_VAR:-12h}
  DHCP_ROUTER=${!DHCP_ROUTER_VAR:-$IP}
  DHCP_DNS=${!DHCP_DNS_VAR:-$IP}

  log "Configuring $IFACE in mode: $MODE"

  if [[ "$MODE" == "client" ]]; then
    nmcli dev wifi rescan ifname "$IFACE"
    sleep 2
    available=$(nmcli -t -f ssid dev wifi list ifname "$IFACE" | sort | uniq)
    connected=false

    for entry in "${!CLIENT_PROFILES_VAR}"; do
      ssid="${entry%%:*}"
      pass="${entry##*:}"
      if echo "$available" | grep -q "^$ssid$"; then
        log "Connecting to known Wi-Fi SSID: $ssid"
        nmcli dev wifi connect "$ssid" password "$pass" ifname "$IFACE" && connected=true && break
      fi
    done

    if [[ "$connected" == false ]]; then
      log "No known SSIDs found – switching to AP mode"
      MODE="ap"
    fi
  fi

  if [[ "$MODE" == "ap" ]]; then
    AP_CONN="${IFACE}-ap"
    nmcli connection delete "$AP_CONN" &>/dev/null || true
    nmcli connection add type wifi ifname "$IFACE" con-name "$AP_CONN" autoconnect yes ssid "$SSID"
    nmcli connection modify "$AP_CONN" \
      wifi.mode ap \
      ipv4.addresses "$IP" \
      ipv4.method shared \
      wifi-sec.key-mgmt wpa-psk \
      wifi-sec.psk "$PASS"
    nmcli connection up "$AP_CONN"
    log "Access Point started on $IFACE with SSID '$SSID' and IP $IP"

    if [[ "$DHCP_ENABLED" == "true" ]]; then
      log "Configuring dnsmasq for DHCP on $IFACE"
      sudo tee /etc/dnsmasq.d/${IFACE}_ap.conf > /dev/null <<EOT
interface=$IFACE
dhcp-range=$DHCP_START,$DHCP_END,$DHCP_LEASE
dhcp-option=3,$DHCP_ROUTER
dhcp-option=6,$DHCP_DNS
EOT
      sudo systemctl restart dnsmasq
    fi
  fi
}

log "🔧 Starting Wi-Fi network configuration..."

wlan_ifaces=$(grep -oP '^WLAN\d+_MODE' "$SETTINGS_FILE" | cut -d_ -f1 | tr '[:upper:]' '[:lower:]' | sort -u)

for iface in $wlan_ifaces; do
  PREFIX=${iface^^}
  ENABLED_VAR="${PREFIX}_ENABLED"
  if [[ "${!ENABLED_VAR}" == "true" ]]; then
    configure_wlan_interface "$iface"
  else
    log "$iface is disabled via $ENABLED_VAR"
  fi
done

log "✅ Wi-Fi configuration complete."