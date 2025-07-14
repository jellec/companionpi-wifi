#!/bin/bash
# netconfig.sh – Configure Ethernet and Wi-Fi interfaces at boot

set -e

SETTINGS_FILE="/etc/companionpi-wifi/settings.env"

# Check if settings file exists
if [ ! -f "$SETTINGS_FILE" ]; then
    echo "[ERROR] Settings file $SETTINGS_FILE not found."
    exit 1
fi

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [netconfig] $1"
}

get_setting() {
    local key="$1"
    grep -E "^${key}=" "$SETTINGS_FILE" | cut -d= -f2- | tr -d '"'
}

interface_exists() {
    local iface=$1
    ip link show "$iface" &>/dev/null
}

IFS=',' read -ra SKIP_IFS <<< "${NETCONFIG_SKIP_INTERFACES,,}"

should_skip_iface() {
    local iface=$1
    for skip in "${SKIP_IFS[@]}"; do
        [[ "$skip" == "$iface" ]] && return 0
    done
    return 1
}

configure_eth_interface() {
    local IFACE=$1
    local PREFIX=${IFACE^^}

    [[ "$(get_setting "${PREFIX}_ENABLED")" != "true" ]] && return
    if should_skip_iface "$IFACE"; then log "⏭ Skipping $IFACE (in skip list)"; return; fi
    if ! interface_exists "$IFACE"; then log "⛔ $IFACE not found"; return; fi

    local MODE=$(get_setting "${PREFIX}_MODE")
    local TIMEOUT=$(get_setting "${PREFIX}_TIMEOUT")
    local FALLBACK_IP=$(get_setting "${PREFIX}_FALLBACK_IP")
    local DHCP_RECHECK=$(get_setting "${PREFIX}_DHCP_RECHECK")

    local AUTO_CONN="${IFACE}-auto"
    local FIX_CONN="${IFACE}-fix"

    log "🔌 Configuring $IFACE (mode: $MODE)"

    nmcli connection delete "$AUTO_CONN" &>/dev/null || true
    nmcli connection delete "$FIX_CONN" &>/dev/null || true

    nmcli connection add type ethernet ifname "$IFACE" con-name "$AUTO_CONN" ipv4.method auto
    nmcli connection add type ethernet ifname "$IFACE" con-name "$FIX_CONN" ipv4.method manual ipv4.addresses "$FALLBACK_IP"

    if [[ "$MODE" == "fix" ]]; then
        nmcli connection up "$FIX_CONN"
    elif [[ "$MODE" == "auto" ]]; then
        nmcli connection up "$AUTO_CONN"
        for ((i=0; i<"$TIMEOUT"; i++)); do
            ip addr show "$IFACE" | grep -q 'inet ' && break
            sleep 1
        done
        if ! ip addr show "$IFACE" | grep -q 'inet '; then
            log "$IFACE: No DHCP after $TIMEOUT s – switching to static IP"
            nmcli connection up "$FIX_CONN"
            [[ "$DHCP_RECHECK" == "true" ]] && (
                sleep 15
                log "$IFACE: Retrying DHCP after fallback..."
                nmcli connection up "$AUTO_CONN"
            )
        else
            log "$IFACE: DHCP success"
        fi
    fi
}

configure_wlan_interface() {
    local IFACE=$1
    local PREFIX=${IFACE^^}

    [[ "$(get_setting "${PREFIX}_ENABLED")" != "true" ]] && return
    if should_skip_iface "$IFACE"; then log "⏭ Skipping $IFACE (in skip list)"; return; fi
    if ! interface_exists "$IFACE"; then log "⛔ $IFACE not found"; return; fi

    local MODE=$(get_setting "${PREFIX}_MODE")
    local SSID=$(get_setting "${PREFIX}_AP_SSID")
    local PASS=$(get_setting "${PREFIX}_AP_PASSWORD")
    local IP=$(get_setting "${PREFIX}_AP_IP")
    local CLIENTS_RAW=$(get_setting "${PREFIX}_CLIENT_PROFILES")

    log "📶 Configuring $IFACE (mode: $MODE)"

    if [[ "$MODE" == "client" ]]; then
        nmcli dev wifi rescan ifname "$IFACE"
        sleep 2
        local available_ssids=$(nmcli -t -f ssid dev wifi list ifname "$IFACE" | sort -u)
        IFS='|' read -ra profiles <<< "$CLIENTS_RAW"
        local connected=false

        for entry in "${profiles[@]}"; do
            local ssid="${entry%%:*}"
            local pw="${entry##*:}"
            if echo "$available_ssids" | grep -qx "$ssid"; then
                log "$IFACE: Connecting to $ssid"
                nmcli dev wifi connect "$ssid" password "$pw" ifname "$IFACE" && connected=true && break
            fi
        done

        if [[ "$connected" != "true" ]]; then
            log "$IFACE: No known SSID – switching to AP"
            MODE="ap"
        fi
    fi

    if [[ "$MODE" == "ap" ]]; then
        local CONN="${IFACE}-ap"
        nmcli connection delete "$CONN" &>/dev/null || true
        nmcli connection add type wifi ifname "$IFACE" con-name "$CONN" ssid "$SSID"
        nmcli connection modify "$CONN" \
            wifi.mode ap \
            ipv4.method shared \
            ipv4.addresses "$IP" \
            wifi-sec.key-mgmt wpa-psk \
            wifi-sec.psk "$PASS"
        nmcli connection up "$CONN"
        log "$IFACE: AP started (SSID=$SSID, IP=$IP)"
    fi
}

log "⚙️ Starting CompanionPi-WiFi network configuration..."

eth_ifaces=$(grep -oP '^ETH\d+_MODE' "$SETTINGS_FILE" | cut -d_ -f1 | tr '[:upper:]' '[:lower:]' | sort -u)
for iface in $eth_ifaces; do
    configure_eth_interface "$iface"
done

wlan_ifaces=$(grep -oP '^WLAN\d+_MODE' "$SETTINGS_FILE" | cut -d_ -f1 | tr '[:upper:]' '[:lower:]' | sort -u)
for iface in $wlan_ifaces; do
    configure_wlan_interface "$iface"
done

log "✅ Network configuration complete."