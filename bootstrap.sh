#!/bin/bash
set -e

echo "📥 Downloading CompanionPi-wifi setup..."

# Download and unzip repository
TMPDIR=$(mktemp -d)
cd "$TMPDIR"
curl -sL https://github.com/jellec/companionpi-wifi/archive/refs/heads/main.zip -o companionpi.zip
unzip -q companionpi.zip
cd companionpi-wifi-main

# Make install script executable and run
chmod +x install.sh
./install.sh

# Optionally run check
if [ -f check.sh ]; then
    echo "🔍 Running post-install check..."
    chmod +x check.sh
    ./check.sh
fi

# Done
echo "✅ CompanionPi installed successfully."