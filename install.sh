#!/bin/bash
set -e
cd "$(dirname "$0")"

echo "🔧 Starting CompanionPi setup..."

if [ ! -f settings.env ]; then
    echo "⚙️  Creating default settings.env..."
    cat <<EOT > settings.env
# WiFi Access Point
WIFI_SSID=CompanionPi
WIFI_PASSWORD=companion123
WIFI_IP=192.168.50.1
WIFI_SUBNET=255.255.255.0
WIFI_DHCP_START=192.168.50.10
WIFI_DHCP_END=192.168.50.100

# Fallback IP for eth0
ETH0_FALLBACK_IP=192.168.10.1
ETH0_SUBNET=255.255.255.0

# DHCP timeout for eth0
ETH0_TIMEOUT=30
EOT

    echo "✅ Created settings.env with default values."
    if command -v nano >/dev/null 2>&1; then
        echo "📝 Opening settings.env in nano..."
        sleep 1
        nano settings.env
    else
        echo "✏️ Please edit settings.env manually before rerunning this script."
        cat settings.env
    fi
    echo "✅ Continuing installation with your updated settings..."
fi

source settings.env

sudo apt update
sudo apt install -y hostapd dnsmasq python3-flask

envsubst < hostapd.conf.template > hostapd.conf
sudo cp hostapd.conf /etc/hostapd/hostapd.conf
echo 'DAEMON_CONF="/etc/hostapd/hostapd.conf"' | sudo tee /etc/default/hostapd

envsubst < dnsmasq.conf.template > dnsmasq.conf
sudo cp dnsmasq.conf /etc/dnsmasq.conf

sudo cp check_eth0_dhcp.py /usr/local/bin/check_eth0_dhcp.py
sudo cp app.py /opt/config-web.py
sudo chmod +x /usr/local/bin/check_eth0_dhcp.py

sudo tee -a /etc/dhcpcd.conf > /dev/null <<EOT

interface wlan0
    static ip_address=${WIFI_IP}/24
    nohook wpa_supplicant
EOT

sudo cp eth0-fallback.service /etc/systemd/system/
sudo cp config-web.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable hostapd
sudo systemctl enable dnsmasq
sudo systemctl enable eth0-fallback
sudo systemctl enable config-web

echo ""
echo "✅ Installation complete."
echo "🛠 All services have been installed and enabled."
echo "🔁 Please reboot your Raspberry Pi now to activate all components:"
echo "    sudo reboot"