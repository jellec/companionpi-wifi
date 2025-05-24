#!/bin/bash
set -e

echo "📥 Downloading CompanionPi-wifi installer..."

# Download ZIP van repo
wget -q https://github.com/jellec/companionpi-wifi/archive/refs/heads/main.zip -O companionpi-wifi.zip

# Uitpakken
unzip -q companionpi-wifi.zip
cd companionpi-wifi-main
rm companionpi-wifi.zip


# Installatie starten
chmod +x install.sh
./install.sh