#!/bin/bash
set -e

echo "📥 Downloading CompanionPi-wifi installer..."

# Download ZIP van repo
wget -q https://github.com/jellec/companionpi-wifi/archive/refs/heads/main.zip -O companionpiwifi.zip

# Uitpakken
unzip -q companionpiwifi.zip
cd companionpi-wifi-main
rm companionpiwifi.zip

# Installatie starten
chmod +x install.sh
./install.sh