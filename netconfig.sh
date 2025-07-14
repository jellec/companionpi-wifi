#!/bin/bash
# netconfig.sh – Configure Ethernet and Wi-Fi interfaces at boot

set -e

SETTINGS_FILE="/etc/companionpi-wifi/settings.env"

# Check if settings file exists
if [ ! -f "$SETTINGS_FILE" ]; then
    echo "Error: Settings file $SETTINGS_FILE not found."
    exit 1
fi

source "$SETTINGS_FILE"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [netconfig] $1"
}

# Function to retrieve settings from the settings file
get_setting() {
    local setting_name=$1
    if [ -z "${!setting_name}" ]; then
        log "Error: $setting_name is not set in $SETTINGS_FILE"
        exit 1
    fi
    echo "${!setting_name}"
}

# Function to check if an interface exists
interface_exists() {
    local iface=$1
    if ip link show "$iface" &>/dev/null; then
        return 0
    else
        log "Error: Interface $iface does not exist."
        return 1
    fi
}

# ================================
# Ethernet (currently disabled)
# ================================
# configure_eth_interface() {
#    local IFACE=$1
#    if ! interface_exists "$IFACE"; then
#        return 1
#    fi
#
#    local PREFIX=${IFACE^^}
#    local MODE_VAR="${PREFIX}_MODE"
#    local TIMEOUT_VAR="${PREFIX}_TIMEOUT"
#    local FALLBACK_VAR="${PREFIX}_FALLBACK_IP"
#    local AUTO_CONN="${IFACE}-auto"
#    local FIX_CONN="${IFACE}-fix"
#
#    local MODE=${!MODE_VAR:-auto}
#    local TIMEOUT=${!TIMEOUT_VAR:-30}
#    local FALLBACK_IP=${!FALLBACK_VAR}
#
#    log "Configuring $IFACE in mode: $MODE"
#
#    # Clean up previous connections
#    nmcli connection delete "$AUTO_CONN" &>/dev/null || true
#    nmcli connection delete "$FIX_CONN" &>/dev/null || true
#
#    # Create both profiles
#    nmcli connection add type ethernet ifname "$IFACE" con-name "$AUTO_CONN" ipv4.method auto
#    nmcli connection add type ethernet ifname "$IFACE" con-name "$FIX_CONN" ipv4.method manual ipv4.addresses "$FALLBACK_IP"
#
#    if [[ "$MODE" == "fix" ]]; then
#        log "$IFACE: Static mode – activating static IP"
#        nmcli connection up "$FIX_CONN"
#    elif [[ "$MODE" == "auto" ]]; then
#        log "$IFACE: Attempting DHCP first..."
#        nmcli connection up "$AUTO_CONN"
#        sleep "$TIMEOUT"
#
#        if ip addr show "$IFACE" | grep -q 'inet '; then
#            log "$IFACE obtained DHCP IP"
#        else
#            log "$IFACE: No DHCP after $TIMEOUT sec – switching to fallback"
#            nmcli connection up "$FIX_CONN"
#        fi
#    else
#        log "$IFACE: Unknown mode '$MODE' – skipping"
#    fi
#}

configure_wlan_interface() {
    local IFACE=$1
    if ! interface_exists "$IFACE"; then
        return 1
    fi

    local PREFIX=${IFACE^^}

    local MODE=$(get_setting "${PREFIX}_MODE")
    local TIMEOUT=$(get_setting "${PREFIX}_TIMEOUT")
    local SSID=$(get_setting "${PREFIX}_AP_SSID")
    local PASS=$(get_setting "${PREFIX}_AP_PASSWORD")
    local IP=$(get_setting "${PREFIX}_AP_IP")
    local DHCP_ENABLED=$(get_setting "${PREFIX}_DHCP_SERVER_ENABLED")
    local DHCP_START=$(get_setting "${PREFIX}_DHCP_RANGE_START")
    local DHCP_END=$(get_setting "${PREFIX}_DHCP_RANGE_END")
    local DHCP_LEASE=$(get_setting "${PREFIX}_DHCP_LEASE_TIME")
    local DHCP_ROUTER=$(get_setting "${PREFIX}_DHCP_ROUTER")
    local DHCP_DNS=$(get_setting "${PREFIX}_DHCP_DNS")

    log "Configuring $IFACE in mode: $MODE"

    if [[ "$MODE" == "client" ]]; then
        nmcli dev wifi rescan ifname "$IFACE"
        sleep 2
        local available=$(nmcli -t -f ssid dev wifi list ifname "$IFACE" | sort | uniq)
        local connected=false
        for entry in "${!CLIENT_PROFILES_VAR}"; do
            local ssid="${entry%%:*}"
            local pass="${entry##*:}"
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
        local AP_CONN="${IFACE}-ap"
        nmcli connection delete "$AP_CONN" &>/dev/null || true
        nmcli connection add type wifi ifname "$IFACE" con-name "$AP_CONN" autoconnect yes ssid "$SSID"
        nmcli connection modify "$AP_CONN" \
            wifi.mode ap \
            ipv4.addresses "$IP" \
            ipv4.method shared \
            wifi-sec.key-mgmt wpa-psk \
            802-11-wireless-security.proto rsn \
            802-11-wireless-security.pairwise ccmp \
            wifi-sec.psk "$PASS"
        nmcli connection up "$AP_CONN"
        log "Access Point started on $IFACE with SSID '$SSID' and IP $IP"
        if [[ "$DHCP_ENABLED" == "true" ]]; then
            log "Configuring dnsmasq for DHCP on $IFACE"
            sudo tee "/etc/dnsmasq.d/${IFACE}_ap.conf" > /dev/null <<EOT
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
