#!/bin/bash
# netconfig.sh – Configure Ethernet and Wi-Fi interfaces at boot

set -e

SETTINGS_FILE="/etc/companionpi/settings.env"
source "$SETTINGS_FILE"

log() {
  echo "[netconfig] $1"
}

check_ip() {
  IFACE=$1
  ip addr show "$IFACE" | grep -q 'inet '
}

configure_eth_interface() {
  IFACE=$1
  PREFIX=${IFACE^^}
  MODE_VAR="${PREFIX}_MODE"
  TIMEOUT_VAR="${PREFIX}_TIMEOUT"
  FALLBACK_VAR="${PREFIX}_FALLBACK_IP"
  AUTO_CONN="${IFACE}-auto"
  FIX_CONN="${IFACE}-fix"

  MODE=${!MODE_VAR:-auto}
  TIMEOUT=${!TIMEOUT_VAR:-30}
  FALLBACK_IP=${!FALLBACK_VAR}

  log "Configuring $IFACE in mode: $MODE"

  # Clean up previous connections
  nmcli connection delete "$AUTO_CONN" &>/dev/null || true
  nmcli connection delete "$FIX_CONN" &>/dev/null || true

  # Create both profiles
  nmcli connection add type ethernet ifname "$IFACE" con-name "$AUTO_CONN" ipv4.method auto
  nmcli connection add type ethernet ifname "$IFACE" con-name "$FIX_CONN" ipv4.method manual ipv4.addresses "$FALLBACK_IP"

  if [[ "$MODE" == "fix" ]]; then
    log "$IFACE: Static mode – activating static IP"
    nmcli connection up "$FIX_CONN"

  elif [[ "$MODE" == "auto" ]]; then
    log "$IFACE: Attempting DHCP first..."
    nmcli connection up "$AUTO_CONN"
    sleep "$TIMEOUT"

    if check_ip "$IFACE"; then
      IP=$(ip -4 addr show "$IFACE" | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
      log "$IFACE obtained DHCP IP: $IP"
    else
      log "$IFACE: No DHCP response after $TIMEOUT seconds – switching to fallback IP"
      nmcli connection up "$FIX_CONN"
    fi

  else
    log "$IFACE: Unknown mode '$MODE' – skipping configuration"
  fi

  # Enable and start eth_monitor@<IFACE>.service
  systemctl enable "eth_monitor@${IFACE}.service"
  systemctl start "eth_monitor@${IFACE}.service"
}

configure_wlan_interface() {
  IFACE=$1
  PREFIX=${IFACE^^}
  MODE_VAR="${PREFIX}_MODE"
  MODE=${!MODE_VAR}
  TIMEOUT=${WLAN0_TIMEOUT}

  CLIENT_PROFILES_VAR="${PREFIX}_CLIENT_PROFILES[@]"
  SSID_VAR="${PREFIX}_AP_SSID"
  PASS_VAR="${PREFIX}_AP_PASSWORD"
  IP_VAR="${PREFIX}_AP_IP"

  SSID=${!SSID_VAR}
  PASS=${!PASS_VAR}
  IP=${!IP_VAR}

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
        nmcli dev wifi connect "$ssid" password "$pass" ifname "$IFACE" || continue
        connected=true
        break
      fi
    done

    if [[ "$connected" == "false" ]]; then
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
    log "Access Point started on $IFACE with SSID '$SSID'"
  fi
}

log "🔧 Starting full network configuration..."

eth_ifaces=$(grep -oP '^ETH\d+_TIMEOUT' "$SETTINGS_FILE" | cut -d_ -f1 | tr '[:upper:]' '[:lower:]' | sort -u)
wlan_ifaces=$(grep -oP '^WLAN\d+_MODE' "$SETTINGS_FILE" | cut -d_ -f1 | tr '[:upper:]' '[:lower:]' | sort -u)

for iface in $eth_ifaces; do
  PREFIX=${iface^^}
  ENABLED_VAR="${PREFIX}_ENABLED"
  if [[ "${!ENABLED_VAR}" == "true" ]]; then
    configure_eth_interface "$iface"
  else
    log "$iface is disabled via $ENABLED_VAR"
  fi
done

for iface in $wlan_ifaces; do
  PREFIX=${iface^^}
  ENABLED_VAR="${PREFIX}_ENABLED"
  if [[ "${!ENABLED_VAR}" == "true" ]]; then
    configure_wlan_interface "$iface"
  else
    log "$iface is disabled via $ENABLED_VAR"
  fi
done

log "✅ Network configuration finished."