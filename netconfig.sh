#!/bin/bash
set -e
source /home/pi/companionpi-wifi/settings.env

log() {
  echo "[netconfig] $1"
}

if [[ "$ETH0_ENABLED" == "true" ]]; then
  log "Configuring eth0..."
  nmcli con delete eth0 || true
  nmcli con add type ethernet ifname eth0 con-name eth0

  log "Trying DHCP on eth0 for ${ETH0_TIMEOUT}s..."
  nmcli con mod eth0 ipv4.method auto
  nmcli con up eth0

  timeout=$ETH0_TIMEOUT
  while [[ $timeout -gt 0 ]]; do
    ip=$(nmcli -t -f ip4.address dev show eth0 | grep -oE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' || true)
    if [[ -n "$ip" ]]; then
      log "DHCP lease acquired: $ip"
      break
    fi
    sleep 1
    ((timeout--))
  done

  if [[ $timeout -le 0 ]]; then
    log "No DHCP lease, assigning fallback IP $ETH0_FALLBACK_IP"
    nmcli con mod eth0 ipv4.addresses "$ETH0_FALLBACK_IP"
    nmcli con mod eth0 ipv4.method manual
    nmcli con up eth0

    if [[ "$ETH0_DHCP_SERVER_ENABLED" == "true" ]]; then
      log "Enabling DHCP server on eth0 (not implemented here, suggest dnsmasq or NM shared mode)"
    fi
  fi
fi

if [[ "$WLAN0_MODE" == "client" ]]; then
  log "Scanning for known Wi-Fi networks..."
  nmcli dev wifi rescan
  sleep 3
  available=$(nmcli -t -f ssid dev wifi list | sort | uniq)

  connected=false
  for profile in "${WLAN0_CLIENT_PROFILES[@]}"; do
    ssid="${profile%%:*}"
    pass="${profile##*:}"
    if echo "$available" | grep -q "^$ssid$"; then
      log "Connecting to $ssid..."
      nmcli con delete "$ssid" || true
      nmcli dev wifi connect "$ssid" password "$pass" ifname wlan0
      connected=true
      break
    fi
  done

  if [[ "$connected" == "false" ]]; then
    log "No known SSID found. Switching to AP mode..."
    WLAN0_MODE=ap
  fi
fi

if [[ "$WLAN0_MODE" == "ap" ]]; then
  log "Configuring wlan0 as Access Point: $WLAN0_AP_SSID"
  nmcli con delete Hotspot || true
  nmcli dev wifi hotspot ifname wlan0 ssid "$WLAN0_AP_SSID" password "$WLAN0_AP_PASSWORD"
  nmcli con mod Hotspot ipv4.addresses "$WLAN0_AP_IP"
  nmcli con mod Hotspot ipv4.method shared
  nmcli con up Hotspot
fi

log "Network configuration complete."
