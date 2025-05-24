#!/bin/bash
set -e
cd "$(dirname "$0")"

echo "🔧 Starting CompanionPi NetworkManager-based setup..."

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

echo "🛠 Installing netconfig.sh to /usr/local/bin"
sudo cp netconfig.sh /usr/local/bin/netconfig.sh
sudo chmod +x /usr/local/bin/netconfig.sh

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
sudo cp -r WebApp/* /opt/WebApp/
sudo chmod +x /opt/WebApp/app.py

echo "🛠 Installing config-web systemd service..."
sudo tee /etc/systemd/system/config-web.service > /dev/null <<EOT
[Unit]
Description=CompanionPi Web Interface
After=network.target

[Service]
ExecStart=/usr/bin/python3 /opt/WebApp/app.py
WorkingDirectory=/opt/WebApp
Restart=always

[Install]
WantedBy=multi-user.target
EOT

sudo systemctl daemon-reload
sudo systemctl enable config-web

sudo systemctl restart config-web


echo ""
echo "✅ Installation complete."
echo "🔁 Please reboot your Raspberry Pi to apply the network configuration:"
echo "    sudo reboot"
