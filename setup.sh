#!/bin/bash
set -e

# Define repo
REPO_URL="https://github.com/jellec/companionpi-wifi"
REPO_DIR="/tmp/companionpi-wifi"

echo "📥 Downloading latest CompanionPi installer from $REPO_URL..."
rm -rf "$REPO_DIR"
git clone "$REPO_URL" "$REPO_DIR"

cd "$REPO_DIR"
chmod +x install.sh
./install.sh