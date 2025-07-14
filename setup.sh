#!/bin/bash
# setup.sh – CompanionPi-WiFi installer (minimal, only uses sudo where needed)

set -e

VERSION="v0.0.8"
REPO_URL="https://github.com/jellec/companionpi-wifi"
REPO_DIR="/tmp/companionpi-wifi"
INSTALL_SCRIPT="install.sh"
LOGFILE="$HOME/companionpi-setup.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "📦 CompanionPi-WiFi Setup – version $VERSION" | tee -a "$LOGFILE"
log "🌐 Repo: $REPO_URL" | tee -a "$LOGFILE"
log "📁 Temp dir: $REPO_DIR" | tee -a "$LOGFILE"
log "📝 Logfile: $LOGFILE" | tee -a "$LOGFILE"

exec > >(tee -a "$LOGFILE") 2>&1

# Already installed?
if [[ -f "/etc/companionpi-wifi/installed.flag" ]]; then
    log "✅ Already installed. To reinstall: delete /etc/companionpi-wifi/installed.flag"
    exit 0
fi

# Check internet
if ! ping -c 1 github.com &>/dev/null; then
    log "❌ ERROR: No internet connection."
    exit 1
fi

# Update APT + install required packages
log "🔄 Updating package list..."
if ! sudo apt-get update; then
    log "❌ ERROR: Failed to update apt"
    exit 1
fi

REQUIRED_PKGS=(git curl nano dnsmasq python3 python3-flask network-manager rfkill)
log "⬇️ Installing required packages: ${REQUIRED_PKGS[*]}"
if ! sudo apt-get install -y "${REQUIRED_PKGS[@]}"; then
    log "❌ ERROR: Failed to install required packages."
    exit 1
fi

# Clean old clone
log "🧹 Cleaning old repo clone..."
rm -rf "$REPO_DIR"

# Clone repo
log "⬇️ Cloning CompanionPi-WiFi..."
if ! git clone "$REPO_URL" "$REPO_DIR"; then
    log "❌ ERROR: Git clone failed"
    exit 1
fi

cd "$REPO_DIR"

# Check install.sh
if [[ ! -f "$INSTALL_SCRIPT" ]]; then
    log "❌ ERROR: install.sh not found"
    exit 1
fi

chmod +x "$INSTALL_SCRIPT"

# Run installer with sudo
log "🚀 Running sudo ./install.sh $*"
if ! sudo ./"$INSTALL_SCRIPT" "$@"; then
    log "❌ ERROR: install.sh failed"
    exit 1
fi

log ""
log "✅ Setup finished successfully!"
log "🔁 Reboot your Raspberry Pi to apply changes:"
log "    sudo reboot"