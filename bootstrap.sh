#!/bin/bash
set -e

echo "📥 Downloading CompanionPi-wifi setup..."

TMPDIR=$(mktemp -d)
cd "$TMPDIR"

curl -sL https://github.com/jellec/companionpi-wifi/archive/refs/heads/main.zip -o companionpi.zip
unzip -q companionpi.zip
cd companionpi-wifi-main

chmod +x install.sh
./install.sh