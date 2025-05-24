#!/bin/bash
set -e

echo "📥 Downloading CompanionPi-wifi installer..."

# Download zip met correcte bestandsnaam
wget -q https://github.com/jellec/companionpi-wifi/archive/refs/heads/main.zip -O companionpi-wifi.zip

# Unzip en opruimen
unzip -q companionpi-wifi.zip
rm companionpi-wifi.zip

# Ga naar map en voer installatie uit
cd companionpi-wifi-main
chmod +x install.sh
./install.sh