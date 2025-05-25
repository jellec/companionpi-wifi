    #!/bin/bash
    set -e

    SETTINGS_FILE="/etc/companionpi/settings.env"
    MONITOR_BIN="/usr/local/bin/eth_monitor.sh"
    SERVICE_DIR="/etc/systemd/system"

    echo "🔍 Scanning for enabled ETH interfaces in settings..."

    grep -E '^ETH[0-9]+_ENABLED=true' "$SETTINGS_FILE" | cut -d_ -f1 | sort -u | while read -r PREFIX; do
        IFACE=$(echo "$PREFIX" | tr '[:upper:]' '[:lower:]')
        SERVICE_NAME="${IFACE}-monitor.service"
        SERVICE_PATH="${SERVICE_DIR}/${SERVICE_NAME}"

        echo "🛠 Creating service for $IFACE → $SERVICE_NAME"

        sudo tee "$SERVICE_PATH" > /dev/null <<EOT
[Unit]
Description=Monitor DHCP/fallback for $IFACE
After=network.target

[Service]
ExecStart=$MONITOR_BIN $IFACE
Restart=always

[Install]
WantedBy=multi-user.target
EOT

        sudo systemctl enable "$SERVICE_NAME"
    done

    echo "✅ All eth-monitor services generated and enabled."
    echo "ℹ️ Run 'sudo systemctl daemon-reload' and reboot to apply."
