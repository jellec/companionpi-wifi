#!/bin/bash
set -e
cd "$(dirname "$0")"

echo "🔧 Starting CompanionPi NetworkManager-based setup..."

# Step 1: settings.env aanmaken of editen
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

# Step 2: settings.env kopiëren naar systeemlocatie
echo "📂 Copying settings.env to system location..."
sudo mkdir -p /etc/companionpi
sudo cp settings.env /etc/companionpi/settings.env

# Step 3: dependencies installeren
echo "📦 Installing dependencies..."
sudo apt update
sudo apt install -y network-manager python3-flask dnsmasq

# Step 4: scripts installeren
echo "📄 Copying scripts to /usr/local/bin..."

sudo cp netconfig.sh /usr/local/bin/netconfig.sh
sudo cp generate-dnsmasq.sh /usr/local/bin/generate-dnsmasq.sh
sudo cp eth_monitor.sh /usr/local/bin/eth_monitor.sh
sudo cp check.sh /usr/local/bin/check.sh
sudo cp generate-eth-monitor-services.sh /usr/local/bin/generate-eth-monitor-services.sh
sudo chmod +x /usr/local/bin/*.sh
sudo systemctl restart dnsmasq

# Step 5: systemd service voor netconfig
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

# Step 6: Flask webinterface installeren
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

# Step 7: systemd reload en services activeren
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