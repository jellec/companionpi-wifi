#!/bin/bash

# Log file path
LOG_FILE="/var/log/network_switch_eth0.log"

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> $LOG_FILE
}

# Initial log message
log_message "Script started"

# Define connection names
INTERFACE="eth0"
AUTO_CONN="eth0-auto"
FIX_CONN="eth0-fix"
DHCP_TIMEOUT=30
DISCONNECT_TIMEOUT=10

# Wait for a few seconds after boot
sleep 30

# Function to check if eth0 has an IP address
check_eth0_ip() {
    IP_ADDRESS=$(ip addr show eth0 | grep 'inet ' | awk '{print $2}')
    if [ -z "$IP_ADDRESS" ]; then
        return 1 # No IP address obtained
    else
        return 0 # IP address obtained
    fi
}

# Check DHCP on eth0-auto
log_message "Checking DHCP on $AUTO_CONN"
sudo nmcli connection up $AUTO_CONN

# Wait for DHCP to succeed
sleep DHCP_TIMEOUT

# Check if eth0-auto got an IP address
if check_eth0_ip; then
    log_message "DHCP address obtained: $IP_ADDRESS"
else
    log_message "No IP address obtained, switching to $FIX_CONN"
    # No IP address obtained, switch to eth0-fix
    sudo nmcli connection up $FIX_CONN
fi

# Monitor the network connection and switch back to AUTO_CONN if disconnected
while true; do
    # Check if eth0 is disconnected
    LINK_STATE=$(cat /sys/class/net/eth0/operstate)
    
    if [ "$LINK_STATE" == "down" ]; then
        log_message "eth0 is down, trying $AUTO_CONN"
        # If eth0 is disconnected, try AUTO_CONN again
        sudo nmcli connection down $FIX_CONN
        sudo nmcli connection up $AUTO_CONN

        # Wait for DHCP to succeed
        sleep 30

        # Check if eth0-auto got an IP address
        if check_eth0_ip; then
            log_message "DHCP address obtained: $IP_ADDRESS"
        else
            log_message "No DHCP address obtained, switching back to $FIX_CONN"
            # No IP address obtained, switch back to eth0-fix
            sudo nmcli connection up $FIX_CONN
        fi
    fi

    # Wait before checking again
    sleep DISCONNECT_TIMEOUT
done