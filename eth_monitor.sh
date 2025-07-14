#!/bin/bash
# eth_monitor.sh – Monitor Ethernet link status and retry DHCP fallback

set -e

INTERFACE="$1"
AUTO_CONN="${INTERFACE}-auto"
FIX_CONN="${INTERFACE}-fix"
DHCP_TIMEOUT=30
DISCONNECT_TIMEOUT=10
LOG_DIR="/var/log/companionpi-wifi"
LOG_FILE="${LOG_DIR}/eth_monitor_${INTERFACE}.log"

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Check if nmcli is available
if ! command -v nmcli &>/dev/null; then
    echo "❌ nmcli not found – aborting"
    exit 1
fi

log_message() {
    local msg="$1"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "$timestamp $msg" >> "$LOG_FILE"
    logger -t "eth_monitor[$INTERFACE]" "$msg"
}

check_ip() {
    ip addr show "$INTERFACE" | grep -q 'inet '
}

log_message "🛠️ Monitor started for $INTERFACE"
sleep 30  # Let system settle (e.g. initial DHCP attempts)

while true; do
    LINK_STATE=$(cat /sys/class/net/"$INTERFACE"/operstate)

    if [[ "$LINK_STATE" == "down" ]]; then
        log_message "$INTERFACE is DOWN – falling back to static IP"
        nmcli connection down "$AUTO_CONN" &>/dev/null || true
        nmcli connection up "$FIX_CONN"
    else
        # Check if IP exists and is from FIX_CONN, then retry DHCP
        if check_ip; then
            current_conn=$(nmcli -t -f NAME,DEVICE,STATE connection show --active | grep "$INTERFACE" | cut -d: -f1)
            if [[ "$current_conn" == "$FIX_CONN" ]]; then
                log_message "$INTERFACE using fallback IP – retrying DHCP on $AUTO_CONN"
                nmcli connection down "$FIX_CONN"
                nmcli connection up "$AUTO_CONN"
                sleep "$DHCP_TIMEOUT"
                if check_ip; then
                    log_message "✅ DHCP succeeded – now using $AUTO_CONN"
                else
                    log_message "❌ DHCP failed again – reverting to $FIX_CONN"
                    nmcli connection up "$FIX_CONN"
                fi
            fi
        fi
    fi

    sleep "$DISCONNECT_TIMEOUT"
done