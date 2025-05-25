#!/bin/bash
set -e

TMP_DIR="/tmp/companionpi-wifi"

echo "📥 Downloading CompanionPi-wifi setup..."
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"
cd "$TMP_DIR"

curl -sL https://github.com/jellec/companionpi-wifi/archive/refs/heads/main.zip -o companionpi-wifi.zip
unzip -oq companionpi-wifi.zip
cd companionpi-wifi-main

chmod +x install.sh
./install.sh