#!/bin/bash
set -e
cd "$(dirname "$0")"

# Create settings.env if not exists
if [ ! -f settings.env ]; then
    echo "⚙️  Copying default settings.env..."
    cp settings-default.env settings.env
    echo "✅ Created settings.env with default values."
    nano settings.env
else
    echo "📝 settings.env already exists."
    read -p "🔄 Do you want to edit it now? [y/N] " answer
    if [[ "$answer" =~ ^[Yy]$ ]]; then
        nano settings.env
    fi
fi

# Install network manager
echo "📦 Installing dependencies..."
sudo apt update
sudo apt install -y network-manager
sudo apt install -y python3-flask
sudo apt install dnsmasq

echo "🛠 Installing netconfig.sh to /usr/local/bin"

echo "🛠 Creating systemd service for netconfig"
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

sudo systemctl daemon-reload
sudo systemctl enable netconfig

# Install Flask web interface
echo "📦 Installing Flask web interface..."

sudo mkdir -p /opt/WebApp
sudo cp -r WebApp /opt/
sudo chmod +x /opt/WebApp/config-web.py

echo "🛠 Installing config-web systemd service..."
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

echo "🔧 Starting CompanionPi NetworkManager-based setup..."
sudo cp netconfig.sh /usr/local/bin/netconfig.sh
sudo cp generate-dnsmasq.sh /usr/local/bin/generate-dnsmasq.sh
sudo cp check.sh /usr/local/bin/check.sh
sudo chmod +x /usr/local/bin/*.sh

sudo systemctl daemon-reload
sudo systemctl enable config-web

echo "📂 Copying settings.env to system location..."
sudo mkdir -p /etc/companionpi
sudo cp settings.env /etc/companionpi/settings.env

echo ""
echo "✅ Installation complete."
echo "🔁 Please reboot your Raspberry Pi to apply the network configuration, use the following command:"
echo "    sudo reboot"
