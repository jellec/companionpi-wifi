#!/bin/bash

set -e

# Variables
VERSION="v0.0.7"
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
    log "❌ ERROR: Failed to update package list (sudo or apt issue)."
    exit 1
fi

# Install required packages
log "⬆️ Installing required packages..."
if ! sudo apt install -y git curl nano dnsmasq python3 python3-flask network-manager rfkill; then
    log "❌ ERROR: Failed to install required packages."
    exit 1
fi

# Remove old repository clone if present
log "🧹 Cleaning up previous clone (if any)..."
rm -rf "$REPO_DIR"

# Clone the latest repository
log "⬇️ Cloning latest CompanionPi Wifi repo..."
if ! git clone "$REPO_URL" "$REPO_DIR"; then
    log "❌ ERROR: Git clone failed – check internet connection or repo URL."
    exit 1
fi

# Change to repo directory
cd "$REPO_DIR"

# Check if install.sh exists
if [ ! -f "$INSTALL_SCRIPT" ]; then
    log "❌ ERROR: $INSTALL_SCRIPT not found in $REPO_DIR"
    exit 1
fi

# Make install.sh executable
if [ ! -x "$INSTALL_SCRIPT" ]; then
    chmod +x "$INSTALL_SCRIPT"
fi

# Run installation script with arguments
log "🚀 Running $INSTALL_SCRIPT..."
if ! ./"$INSTALL_SCRIPT" "$@"; then
    log "❌ ERROR: Failed to run $INSTALL_SCRIPT."
    exit 1
fi

# Mark as installed only if everything succeeded
log "✅ Installation script completed successfully."

log "📌 Marking system as installed..."
if ! sudo mkdir -p /etc/companionpi; then
    log "❌ ERROR: Could not create /etc/companionpi"
    exit 1
fi

if ! sudo touch /etc/companionpi/installed.flag; then
    log "❌ ERROR: Could not create installed.flag"
    exit 1
fi

log ""
log "✅ CompanionPi setup complete!"
log "🔁 Please reboot your Raspberry Pi to apply all changes:"
log "    sudo reboot"