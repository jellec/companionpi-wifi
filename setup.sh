#!/bin/bash
set -e
set -x  # DEBUG

REPO_URL="https://github.com/jellec/companionpi-wifi"
REPO_DIR="/tmp/companionpi-wifi"
INSTALL_SCRIPT="install.sh"
SYSTEM_SETTINGS="/etc/companionpi/settings.env"

echo "📦 CompanionPi Setup started..."
echo "🌐 Repo: $REPO_URL"
echo "📁 Temporary directory: $REPO_DIR"

# 🧼 System updates
echo "🔄 Updating package lists..."
sudo apt update

echo "⬆️ Upgrading installed packages..."
sudo apt upgrade -y

# 🛠️ Install git if missing
if ! command -v git &> /dev/null; then
    echo "🔧 git is not installed, installing it now..."
    sudo apt install -y git
fi

# 🔄 Clone repository
echo "🧹 Removing old temporary install folder (if present)..."
rm -rf "$REPO_DIR"

echo "⬇️ Cloning latest version of CompanionPi WiFi Addon..."
git clone "$REPO_URL" "$REPO_DIR"

# 📂 Reuse settings if available
if [ -f "$SYSTEM_SETTINGS" ]; then
    echo "🛠 Reusing existing settings from $SYSTEM_SETTINGS"
    cp "$SYSTEM_SETTINGS" "$REPO_DIR/settings.env"
fi

# 📂 Navigate into repo and check for install script
cd "$REPO_DIR"
if [ ! -f "$INSTALL_SCRIPT" ]; then
    echo "❌ ERROR: install.sh not found in cloned repo."
    exit 1
fi

chmod +x "$INSTALL_SCRIPT"

# 🚀 Start install script
echo "🚀 Running install.sh from cloned repo..."
./install.sh