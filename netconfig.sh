#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/settings.env"

log() {
  echo "[netconfig] $1"
}

# Get all ETHx interfaces from settings.env
eth_ifaces=$(grep -oP '^ETH\d+_ENABLED' "$SCRIPT_DIR/settings.env" | cut -d_ -f1 | sort -u)

# Get all WLANx interfaces from settings.env
wlan_ifaces=$(grep -oP '^WLAN\d+_MODE' "$SCRIPT_DIR/settings.env" | cut -d_ -f1 | sort -u)

configure_eth() {
  IFACE=$1
  PREFIX=${IFACE^^}
  ENABLED_VAR="${PREFIX}_ENABLED"
  TIMEOUT_VAR="${PREFIX}_TIMEOUT"
  FALLBACK_VAR="${PREFIX}_FALLBACK_IP"

  if [[ "${!ENABLED_VAR}" == "true" ]]; then
    log "Configuring $IFACE..."

    if ! nmcli connection show "$IFACE" &>/dev/null; then
      nmcli connection add type ethernet ifname "$IFACE" con-name "$IFACE"
    fi

    nmcli connection modify "$IFACE" ipv4.method auto
    nmcli connection up "$IFACE"

    TIMEOUT=${!TIMEOUT_VAR}
    while [[ $TIMEOUT -gt 0 ]]; do
      ip=$(nmcli -t -f IP4.ADDRESS dev show "$IFACE" | grep -oE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' || true)
      if [[ -n "$ip" ]]; then
        log "$IFACE got IP: $ip"
        return
      fi
      sleep 1
      ((TIMEOUT--))
    done

    FALLBACK_IP=${!FALLBACK_VAR}
    log "$IFACE fallback to static IP: $FALLBACK_IP"
    nmcli connection modify "$IFACE" ipv4.addresses "$FALLBACK_IP"
    nmcli connection modify "$IFACE" ipv4.method manual
    nmcli connection up "$IFACE"

    DHCP_VAR="${PREFIX}_DHCP_SERVER_ENABLED"
    if [[ "${!DHCP_VAR}" == "true" ]]; then
      log "DHCP server requested on $IFACE (not implemented – use dnsmasq or NM shared mode)"
    fi
  fi
}

configure_wlan() {
  IFACE=$1
  PREFIX=${IFACE^^}
  MODE_VAR="${PREFIX}_MODE"
  MODE=${!MODE_VAR}

  log "Configuring $IFACE – mode: $MODE"

  if [[ "$MODE" == "client" ]]; then
    nmcli dev wifi rescan ifname "$IFACE"
    sleep 2
    available=$(nmcli -t -f ssid dev wifi list ifname "$IFACE" | sort | uniq)

    connected=false
    PROFILES_VAR="${PREFIX}_CLIENT_PROFILES[@]"
    for entry in "${!PROFILES_VAR}"; do
      ssid="${entry%%:*}"
      pass="${entry##*:}"
      if echo "$available" | grep -q "^$ssid$"; then
        log "Connecting $IFACE to WiFi: $ssid"
        nmcli dev wifi connect "$ssid" password "$pass" ifname "$IFACE"
        connected=true
        break
      fi
    done

    if [[ "$connected" == "false" ]]; then
      log "No known SSID found – switching $IFACE to AP mode"
      MODE="ap"
    fi
  fi

  if [[ "$MODE" == "ap" ]]; then
    SSID_VAR="${PREFIX}_AP_SSID"
    PASS_VAR="${PREFIX}_AP_PASSWORD"
    IP_VAR="${PREFIX}_AP_IP"
    SSID=${!SSID_VAR}
    PASS=${!PASS_VAR}
    IP=${!IP_VAR}
    CON_NAME="${IFACE}-AP"

    log "Setting up AP on $IFACE with SSID $SSID"
    if ! nmcli connection show "$CON_NAME" &>/dev/null; then
      nmcli connection add type wifi ifname "$IFACE" con-name "$CON_NAME" autoconnect yes ssid "$SSID"
    fi

    nmcli connection modify "$CON_NAME" \
      wifi.mode ap \
      ipv4.addresses "$IP" \
      ipv4.method shared \
      wifi-sec.key-mgmt wpa-psk \
      wifi-sec.psk "$PASS"

    nmcli connection up "$CON_NAME"
  fi
}

log "Starting CompanionPi dynamic network configuration..."

for IFACE in $eth_ifaces; do
  configure_eth "$IFACE"
done

for IFACE in $wlan_ifaces; do
  configure_wlan "$IFACE"
done

sudo bash /usr/local/bin/generate-dnsmasq.sh

log "Network configuration complete."
