#!/bin/bash
set -e

REPO_URL="https://github.com/jellec/companionpi-wifi"
REPO_DIR="/tmp/companionpi-wifi"
INSTALL_SCRIPT="install.sh"

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

# 📂 Navigate into repo and check for install script
cd "$REPO_DIR"
if [ ! -f "$INSTALL_SCRIPT" ]; then
    echo "❌ ERROR: install.sh not found in cloned repo."
    exit 1
fi

chmod +x "$INSTALL_SCRIPT"

# 🚀 Run install.sh with optional flags
echo "🚀 Running install.sh from cloned repo..."
./"$INSTALL_SCRIPT" "$@"