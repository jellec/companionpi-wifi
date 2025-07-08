#!/bin/bash
set -e

REPO_URL="https://github.com/jellec/companionpi-wifi"
REPO_DIR="/tmp/companionpi-wifi"
INSTALL_SCRIPT="install.sh"

echo "📦 CompanionPi Setup started..."
echo "🌐 Repo: $REPO_URL"
echo "📁 Temporary directory: $REPO_DIR"

# 🛠️ Check for git
if ! command -v git &> /dev/null; then
    echo "❌ ERROR: git is required but not installed. Please start from the CompanionPi image."
    exit 1
fi

# 🔄 Clone repository
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

# 🚀 Start install script
./install.sh "$@"