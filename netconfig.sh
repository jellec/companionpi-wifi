#!/bin/bash
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
  TIMEOUT_VAR="${PREFIX}_TIMEOUT"
  FALLBACK_VAR="${PREFIX}_FALLBACK_IP"
  AUTO_CONN="${IFACE}-auto"
  FIX_CONN="${IFACE}-fix"

  TIMEOUT=${!TIMEOUT_VAR}
  FALLBACK_IP=${!FALLBACK_VAR}

  log "Setting up $IFACE with fallback to static IP if no DHCP..."

  nmcli connection delete "$AUTO_CONN" &>/dev/null || true
  nmcli connection delete "$FIX_CONN" &>/dev/null || true

  nmcli connection add type ethernet ifname "$IFACE" con-name "$AUTO_CONN" ipv4.method auto
  nmcli connection add type ethernet ifname "$IFACE" con-name "$FIX_CONN" ipv4.method manual ipv4.addresses "$FALLBACK_IP"

  nmcli connection up "$AUTO_CONN"
  sleep "$TIMEOUT"

  if check_ip "$IFACE"; then
    IP=$(ip -4 addr show "$IFACE" | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
    log "$IFACE got DHCP IP: $IP"
  else
    log "No DHCP on $IFACE, switching to fallback: $FALLBACK_IP"
    nmcli connection up "$FIX_CONN"
  fi
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

  log "Setting up $IFACE in mode: $MODE"

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
      log "No known SSID found. Switching to AP mode on $IFACE"
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
    log "Started AP on $IFACE with SSID $SSID"
  fi
}

log "Starting full network config..."

eth_ifaces=$(grep -oP '^ETH\d+_TIMEOUT' "$SETTINGS_FILE" | cut -d_ -f1 | tr '[:upper:]' '[:lower:]' | sort -u)
wlan_ifaces=$(grep -oP '^WLAN\d+_MODE' "$SETTINGS_FILE" | cut -d_ -f1 | tr '[:upper:]' '[:lower:]' | sort -u)

for iface in $eth_ifaces; do
  configure_eth_interface "$iface"
done

for iface in $wlan_ifaces; do
  configure_wlan_interface "$iface"
done

log "Network configuration done."
