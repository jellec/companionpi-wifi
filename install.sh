#!/bin/bash
set -e

echo "🔧 Starting CompanionPi WiFi setup..."

# 1. Install required packages
sudo apt update
sudo apt install -y hostapd dnsmasq python3-flask

# 2. Copy config files
echo "📁 Copying configuration files..."
sudo cp hostapd.conf /etc/hostapd/hostapd.conf
sudo cp dnsmasq.conf /etc/dnsmasq.conf
sudo cp check_eth0_dhcp.py /usr/local/bin/check_eth0_dhcp.py
sudo cp app.py /opt/config-web.py
sudo chmod +x /usr/local/bin/check_eth0_dhcp.py

# 3. Set static IP for wlan0
echo "📡 Setting static IP for wlan0..."
sudo tee -a /etc/dhcpcd.conf > /dev/null <<EOT

interface wlan0
    static ip_address=192.168.45.1/24
    nohook wpa_supplicant
EOT

# 4. Configure hostapd
echo 'DAEMON_CONF="/etc/hostapd/hostapd.conf"' | sudo tee /etc/default/hostapd

# 5. Systemd services
echo "🛠️ Installing systemd services..."
sudo cp eth0-fallback.service /etc/systemd/system/
sudo cp config-web.service /etc/systemd/system/
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable hostapd
sudo systemctl enable dnsmasq
sudo systemctl enable eth0-fallback
sudo systemctl enable config-web

echo "✅ Setup complete. A reboot is recommended."
