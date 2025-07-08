#!/bin/bash
set -e
set -x  # DEBUG

REPO_URL="https://github.com/jellec/companionpi-wifi"
REPO_DIR="/tmp/companionpi-wifi"

echo "📦 CompanionPi Setup started..."
echo "🌐 Repo: $REPO_URL"
echo "📁 Doelmap: $REPO_DIR"

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

echo "🧹 Removing old temporary installation folder (if necessary)..."
rm -rf "$REPO_DIR"

echo "⬇️ Cloning latest version of CompanionPi..."
git clone "$REPO_URL" "$REPO_DIR"

echo "📂 Opening Installation folder..."
cd "$REPO_DIR"
chmod +x install.sh

echo "🚀 Start install ..."
./install.sh
