#!/bin/bash
set -e

echo "📥 Downloading CompanionPi-wifi installer..."

# Download ZIP van repo
wget -q https://github.com/jellec/companionpi-wifi/archive/refs/heads/main.zip -O companionpi.zip

# Uitpakken
unzip -q companionpi.zip
cd companionpi-wifi-main

# Installatie starten
chmod +x install.sh
./install.sh