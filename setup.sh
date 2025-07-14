#!/bin/bash

set -e

# Variables
VERSION="v0.0.6"
REPO_URL="https://github.com/jellec/companionpi-wifi"
REPO_DIR="/tmp/companionpi-wifi"
INSTALL_SCRIPT="install.sh"
LOGFILE="/var/log/companionpi-setup.log"

# Function for logging messages with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Start logging
log "📦 CompanionPi Setup – version $VERSION"
log "🌐 Repo: $REPO_URL"
log "📁 Temporary directory: $REPO_DIR"
log "📝 Logfile: $LOGFILE"

exec > >(tee -a "$LOGFILE") 2>&1

# Check if CompanionPi is already installed
if [[ -f "/etc/companionpi/installed.flag" ]]; then
    log "✅ CompanionPi already appears to be installed. Exiting setup."
    log "📝 To force reinstall, delete /etc/companionpi/installed.flag and rerun."
    exit 0
fi

# Check internet connection
if ! ping -c 1 github.com &> /dev/null; then
    log "❌ ERROR: No internet connection."
    exit 1
fi

# Update package list
log "🔄 Updating package list..."
if ! sudo apt update; then
    log "❌ ERROR: Failed to update package list."
    exit 1
fi

# Install required packages
log "⬆️ Installing required packages..."
if ! sudo apt install -y git curl nano dnsmasq python3 python3-flask network-manager rfkill; then
    log "❌ ERROR: Failed to install required packages."
    exit 1
fi

# Remove old repository clone if present
log "🧹 Cleaning up previous clone..."
rm -rf "$REPO_DIR"

# Clone the latest repository
log "⬇️ Cloning latest CompanionPi Wifi repo..."
if ! git clone "$REPO_URL" "$REPO_DIR"; then
    log "❌ ERROR: Git clone failed – check internet connection or repo URL."
    exit 1
fi

# Run installation script
cd "$REPO_DIR"
if [ ! -f "$INSTALL_SCRIPT" ]; then
    log "❌ ERROR: $INSTALL_SCRIPT not found in $REPO_DIR"
    exit 1
fi

# Make installation script executable if it isn't already
if [ ! -x "$INSTALL_SCRIPT" ]; then
    chmod +x "$INSTALL_SCRIPT"
fi

# Run installation script with the same arguments
log "🚀 Running $INSTALL_SCRIPT..."
if ! ./"$INSTALL_SCRIPT" "$@"; then
    log "❌ ERROR: Failed to run $INSTALL_SCRIPT."
    exit 1
fi

# Create installation flag
sudo mkdir -p /etc/companionpi
sudo touch /etc/companionpi/installed.flag

log ""
log "✅ CompanionPi setup complete!"
log "🔁 Please reboot your Raspberry Pi to apply all changes:"
log "    sudo reboot"
