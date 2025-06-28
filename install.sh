#!/bin/bash
set -e
cd "$(dirname "$0")"

echo "🔧 Starting CompanionPi NetworkManager-based setup..."

SETTINGS_DEFAULT="settings-default.env"
SETTINGS_LOCAL="settings.env"
SETTINGS_TARGET="/etc/companionpi/settings.env"

# Stap 1: settings.env maken of vergelijken
if [ ! -f "$SETTINGS_LOCAL" ]; then
    echo "⚙️  No local settings found, copying default..."
    cp "$SETTINGS_DEFAULT" "$SETTINGS_LOCAL"
    nano "$SETTINGS_LOCAL"
else
    echo "📝 Local settings.env exists."
    if [ -f "$SETTINGS_TARGET" ]; then
        echo "🔍 Comparing with system settings..."
        diff_output=$(diff -u "$SETTINGS_TARGET" "$SETTINGS_LOCAL" || true)
        if [ -n "$diff_output" ]; then
            echo "$diff_output"
            echo ""
            read -p "⚠️  Differences found. Overwrite system settings with local version? [y/N] " overwrite
            if [[ "$overwrite" =~ ^[Yy]$ ]]; then
                sudo cp "$SETTINGS_LOCAL" "$SETTINGS_TARGET"
                echo "✅ Updated system settings."
            else
                echo "❌ Keeping existing system settings."
            fi
        else
            echo "✅ No differences found in settings."
        fi
    else
        echo "📂 Copying settings.env to system location..."
        sudo mkdir -p /etc/companionpi
        sudo cp "$SETTINGS_LOCAL" "$SETTINGS_TARGET"
    fi
fi

# Stap 2: dependencies
echo "📦 Installing dependencies..."
sudo apt update
sudo apt install -y network-manager python3-flask dnsmasq git

# Stap 3: scripts
echo "📄 Copying scripts to /usr/local/bin..."
sudo cp netconfig.sh /usr/local/bin/netconfig.sh
sudo cp generate-dnsmasq.sh /usr/local/bin/generate-dnsmasq.sh
sudo cp eth_monitor.sh /usr/local/bin/eth_monitor.sh
sudo cp check.sh /usr/local/bin/check.sh
sudo cp generate-eth-monitor-services.sh /usr/local/bin/generate-eth-monitor-services.sh
sudo chmod +x /usr/local/bin/*.sh
sudo systemctl restart dnsmasq

# Stap 4: netconfig service
echo "🛠 Creating netconfig systemd service..."
sudo tee /etc/systemd/system/netconfig.service > /dev/null <<EOT
[Unit]
Description=CompanionPi network configuration
After=network.target

[Service]
ExecStart=/usr/local/bin/netconfig.sh
Type=oneshot
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOT

# Stap 5: webinterface
echo "🌐 Installing Flask WebApp..."
sudo mkdir -p /opt/WebApp
sudo cp -r WebApp/* /opt/WebApp/
sudo chmod +x /opt/WebApp/config-web.py

echo "🛠 Creating config-web systemd service..."
sudo tee /etc/systemd/system/config-web.service > /dev/null <<EOT
[Unit]
Description=CompanionPi Web Interface
After=network.target

[Service]
ExecStart=/usr/bin/python3 /opt/WebApp/config-web.py
WorkingDirectory=/opt/WebApp
Restart=always

[Install]
WantedBy=multi-user.target
EOT

# Stap 6: activatie
sudo systemctl daemon-reload
sudo systemctl enable netconfig
sudo systemctl enable config-web

echo "⚙️ Generating eth-monitor services based on settings.env..."
sudo /usr/local/bin/generate-eth-monitor-services.sh
sudo systemctl daemon-reload

echo ""
echo "✅ Installation complete."
echo "🔁 Please reboot your Raspberry Pi to apply the network configuration:"
echo "    sudo reboot"