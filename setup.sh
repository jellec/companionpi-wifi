#!/bin/bash
set -e

VERSION="v0.0.5"
REPO_URL="https://github.com/jellec/companionpi-wifi"
REPO_DIR="/tmp/companionpi-wifi"
INSTALL_SCRIPT="install.sh"
LOGFILE="/var/log/companionpi-setup.log"

echo "📦 CompanionPi Setup – version $VERSION"
echo "🌐 Repo: $REPO_URL"
echo "📁 Temporary directory: $REPO_DIR"
echo "📝 Logfile: $LOGFILE"
echo ""

# 📓 Start logging
exec > >(tee -a "$LOGFILE") 2>&1

# 🛡 Prevent reinstallation if already installed
if [[ -f "/etc/companionpi/installed.flag" ]]; then
  echo "✅ CompanionPi already appears to be installed. Exiting setup."
  echo "📝 To force reinstall, delete /etc/companionpi/installed.flag and rerun."
  exit 0
fi

# 🔄 Update package list
echo "🔄 Updating package list..."
sudo apt update

# ⬆️ Install required dependencies
echo "⬆️ Installing required packages..."
sudo apt install -y git curl nano dnsmasq python3 python3-flask network-manager rfkill

# 🧹 Remove old repo clone if present
echo "🧹 Cleaning up previous clone..."
rm -rf "$REPO_DIR"

# ⬇️ Clone latest repo
echo "⬇️ Cloning latest CompanionPi Wifi repo..."
if ! git clone "$REPO_URL" "$REPO_DIR"; then
  echo "❌ ERROR: Git clone failed – check internet connection or repo URL."
  exit 1
fi

# ▶️ Run install script
cd "$REPO_DIR"

if [ ! -f "$INSTALL_SCRIPT" ]; then
  echo "❌ ERROR: install.sh not found in $REPO_DIR"
  exit 1
fi

chmod +x "$INSTALL_SCRIPT"

# 🚀 Run install script with same arguments
echo "🚀 Running install.sh..."
./"$INSTALL_SCRIPT" "$@"

# ✅ Create installed flag
sudo mkdir -p /etc/companionpi
sudo touch /etc/companionpi/installed.flag

echo ""
echo "✅ CompanionPi setup complete!"
echo "🔁 Please reboot your Raspberry Pi to apply all changes:"
echo "    sudo reboot"