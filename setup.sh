#!/bin/bash
set -e

REPO_URL="https://github.com/jellec/companionpi-wifi"
REPO_DIR="/tmp/companionpi-wifi"
INSTALL_SCRIPT="install.sh"

echo "JELLE V0.0.3"

echo "📦 CompanionPi Setup started..."
echo "🌐 Repo: $REPO_URL"
echo "📁 Temporary directory: $REPO_DIR"

# 🧼 Update & dependency check
echo "🔄 Updating package list..."
sudo apt update

echo "⬆️ Installing required packages..."
sudo apt install -y git curl nano dnsmasq python3 python3-flask network-manager rfkill

# 🧹 Clean up any old repo
echo "🧹 Removing old clone if present..."
rm -rf "$REPO_DIR"

# ⬇️ Clone latest version
echo "⬇️ Cloning latest CompanionPi Wifi repo..."
git clone "$REPO_URL" "$REPO_DIR"

# ▶️ Run install script
cd "$REPO_DIR"
if [ ! -f "$INSTALL_SCRIPT" ]; then
  echo "❌ ERROR: install.sh not found in $REPO_DIR"
  exit 1
fi

chmod +x "$INSTALL_SCRIPT"

# 📦 Run install script with same arguments
echo "🚀 Running install.sh..."
./"$INSTALL_SCRIPT" "$@"