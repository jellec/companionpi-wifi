#!/bin/bash

INTERFACE="$1"
AUTO_CONN="${INTERFACE}-auto"
FIX_CONN="${INTERFACE}-fix"
DHCP_TIMEOUT=30
DISCONNECT_TIMEOUT=10
LOG_FILE="/var/log/network_monitor_${INTERFACE}.log"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG_FILE"
}

check_ip() {
    ip addr show "$INTERFACE" | grep -q 'inet '
}

log_message "Monitor started for $INTERFACE"

sleep 30  # Lset system settle (e.g. boot DHCP attempts)

while true; do
    LINK_STATE=$(cat /sys/class/net/"$INTERFACE"/operstate)

    if [[ "$LINK_STATE" == "down" ]]; then
        log_message "$INTERFACE is down, falling back to static IP"
        nmcli connection down "$AUTO_CONN" &>/dev/null || true
        nmcli connection up "$FIX_CONN"
    else
        # Check if IP exists and is from FIX_CONN, then retry AUTO_CONN
        if check_ip; then
            current_conn=$(nmcli -t -f NAME,DEVICE,STATE connection show --active | grep "$INTERFACE" | cut -d: -f1)
            if [[ "$current_conn" == "$FIX_CONN" ]]; then
                log_message "$INTERFACE using fallback IP, retrying DHCP on $AUTO_CONN"
                nmcli connection down "$FIX_CONN"
                nmcli connection up "$AUTO_CONN"
                sleep "$DHCP_TIMEOUT"
                if check_ip; then
                    log_message "DHCP successful, back on $AUTO_CONN"
                else
                    log_message "DHCP failed again, keeping fallback"
                    nmcli connection up "$FIX_CONN"
                fi
            fi
        fi
    fi

    sleep "$DISCONNECT_TIMEOUT"
done
