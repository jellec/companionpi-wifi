#!/bin/bash
# generate-eth-monitor-services.sh – Generate and enable eth_monitor services per ETH interface

set -e

SETTINGS_FILE="/etc/companionpi-wifi/settings.env"
MONITOR_BIN="/usr/local/bin/eth_monitor.sh"
SERVICE_DIR="/etc/systemd/system"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [eth-monitor-generator] $1"
}

# Check required files
if [[ ! -f "$SETTINGS_FILE" ]]; then
    log "❌ Settings file not found: $SETTINGS_FILE"
    exit 1
fi

if [[ ! -x "$MONITOR_BIN" ]]; then
    log "❌ eth_monitor.sh not found or not executable: $MONITOR_BIN"
    exit 1
fi

log "🔍 Scanning for enabled Ethernet interfaces in settings..."

# Extract ETH interfaces that are enabled
grep -E '^ETH[0-9]+_ENABLED=true' "$SETTINGS_FILE" | cut -d_ -f1 | sort -u | while read -r PREFIX; do
    IFACE=$(echo "$PREFIX" | tr '[:upper:]' '[:lower:]')
    SERVICE_NAME="eth-monitor@${IFACE}.service"
    SERVICE_PATH="${SERVICE_DIR}/eth-monitor@.service"

    log "🛠 Ensuring systemd template exists: $SERVICE_PATH"

    # Write or overwrite the template unit
    sudo tee "$SERVICE_PATH" > /dev/null <<EOT
[Unit]
Description=CompanionPi-Wifi: Monitor DHCP fallback for %i
After=network.target

[Service]
ExecStart=$MONITOR_BIN %i
Restart=always

[Install]
WantedBy=multi-user.target
EOT

    log "🔗 Enabling eth-monitor for $IFACE → $SERVICE_NAME"
    sudo systemctl enable "eth-monitor@${IFACE}.service"
done

log "🔁 Reloading systemd daemon..."
sudo systemctl daemon-reload

log "✅ All eth-monitor services generated and enabled."