#!/bin/bash
# setup.sh – CompanionPi-WiFi installer (minimal, only uses sudo where needed)

set -e

VERSION="v0.0.30"
REPO_URL="https://github.com/jellec/companionpi-wifi"
REPO_DIR="/tmp/companionpi-wifi"
INSTALL_SCRIPT="install.sh"
LOGFILE="$HOME/companionpi-setup.log"

log() {
    echo "     [$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

show_help() {
    echo "CompanionPi-WiFi Setup $VERSION"
    echo ""
    echo "Usage: ./setup.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --only-scripts      Install only CLI scripts (no web interface)"
    echo "  --only-webapp       Install only web interface (no scripts)"
    echo "  --force-settings    Overwrite existing settings.env"
    echo "  --force-install     Skip all checks and force install"
    echo "  --dev               Enable development mode"
    echo "  --help              Show this help message"
    exit 0
}

# Show help
[[ "$1" == "--help" ]] && show_help

log ""
log "=============================================="
log "📦 CompanionPi-WiFi Setup – version $VERSION" | tee -a "$LOGFILE"
log "🌐 Repo: $REPO_URL" | tee -a "$LOGFILE"
log "📁 Temp dir: $REPO_DIR" | tee -a "$LOGFILE"
log "📝 Logfile: $LOGFILE" | tee -a "$LOGFILE"
log "=============================================="
log ""
exec > >(tee -a "$LOGFILE") 2>&1

# Already installed?
if [[ -f "/etc/companionpi-wifi/installed.flag" && "$*" != *"--force-install"* ]]; then
    log "✅ Already installed. Use --force-install to reinstall."
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

# Fetch latest repo
log "⬇️ Fetching latest CompanionPi-WiFi..."

if [[ -d "$REPO_DIR/.git" ]]; then
    log "🔄 Repo exists – updating..."
    cd "$REPO_DIR"
    git fetch origin
    git reset --hard origin/main
else
    sudo rm -rf "$REPO_DIR"
    git clone --depth 1 "$REPO_URL" "$REPO_DIR"
fi

cd "$REPO_DIR"

# Check install.sh
if [[ ! -f "$INSTALL_SCRIPT" ]]; then
    log "❌ ERROR: install.sh not found"
    exit 1
fi

chmod +x "$INSTALL_SCRIPT"

# Run installer with sudo
# log "🚀 Running sudo ./install.sh $*"
# if ! sudo ./"$INSTALL_SCRIPT" "$@"; then
#     log "❌ ERROR: install.sh failed"
#     exit 1
# fi

sudo chown -R $USER:$USER /tmp/companionpi-wifi

# Return to home directory to avoid accidental operations in the temporary repo directory
cd

log ""
log "✅ Setup finished successfully!"
log "🔁 Reboot your Raspberry Pi to apply changes:"
log "    sudo reboot"