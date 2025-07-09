#!/bin/bash
# install.sh – Install CompanionPi scripts, settings, and WebApp

set -e
cd "$(dirname "$0")"

echo "🔧 Starting CompanionPi installation..."

# Flags
ONLY_SCRIPTS=false
ONLY_WEBAPP=false
FORCE_SETTINGS=false
DEV_MODE=false
FORCE_INSTALL=false

for arg in "$@"; do
  case $arg in
    --only-scripts) ONLY_SCRIPTS=true ;;
    --only-webapp) ONLY_WEBAPP=true ;;
    --force-settings) FORCE_SETTINGS=true ;;
    --force-install) FORCE_INSTALL=true ;;
    --dev) DEV_MODE=true ;;
  esac
done

SETTINGS_DEFAULT="settings-default.env"
SETTINGS_LOCAL="settings.env"
SETTINGS_TARGET="/etc/companionpi/settings.env"
INSTALL_FLAG="/etc/companionpi/installed.flag"
DEFAULT_USER=${SUDO_USER:-$(whoami)}
USER_HOME=$(eval echo ~"$DEFAULT_USER")

# Optional logging (uncomment to enable logging to file)
# LOGFILE="/var/log/companionpi-install.log"
# exec > >(tee -a "$LOGFILE") 2>&1

# Optional forced reinstall
if [[ "$FORCE_INSTALL" = true ]]; then
  echo "⚠️  Forcing full re-install: removing install flag"
  sudo rm -f "$INSTALL_FLAG"
fi

# Step 1: Handle settings.env
if [[ "$ONLY_WEBAPP" = false ]]; then
  sudo mkdir -p /etc/companionpi
  sudo chown "$DEFAULT_USER:$DEFAULT_USER" /etc/companionpi

  if [[ -f "$SETTINGS_TARGET" && "$FORCE_SETTINGS" = false ]]; then
    echo "📂 System settings file already exists: $SETTINGS_TARGET"
    
    echo "📄 Copying current system settings to local project (settings.env)"
    sudo cp "$SETTINGS_TARGET" "$SETTINGS_LOCAL"
    sudo chown "$DEFAULT_USER:$DEFAULT_USER" "$SETTINGS_LOCAL"
    
    echo "📝 Please review and update it if needed."
    echo "Press ENTER to open the editor..."
    read
    nano "$SETTINGS_LOCAL"

    echo "📥 Saving back to system path..."
    sudo cp "$SETTINGS_LOCAL" "$SETTINGS_TARGET"

  else
    if [[ ! -f "$SETTINGS_LOCAL" ]]; then
      echo "⚙️  No local settings.env found – copying default..."
      cp "$SETTINGS_DEFAULT" "$SETTINGS_LOCAL"
    fi

    echo "📋 No system settings found (or forced). Please review before continuing."
    echo "Press ENTER to open the editor..."
    read
    nano "$SETTINGS_LOCAL"

    echo "📥 Saving to system path..."
    sudo cp "$SETTINGS_LOCAL" "$SETTINGS_TARGET"
  fi

  sudo chown "$DEFAULT_USER:$DEFAULT_USER" "$SETTINGS_TARGET"
  sudo chmod 664 "$SETTINGS_TARGET"
fi

# Step 2: Install scripts
if [[ "$ONLY_WEBAPP" = false ]]; then
  echo ""
  echo "📄 Installing scripts to /usr/local/bin..."

  SCRIPT_LIST=(
    netconfig.sh
    generate-dnsmasq.sh
    eth_monitor.sh
    check.sh
    generate-eth-monitor-services.sh
  )

  for script in "${SCRIPT_LIST[@]}"; do
    if [[ ! -f "$script" ]]; then
      echo "❌ ERROR: Script $script not found. Installation aborted."
      exit 1
    fi
    sudo cp "$script" /usr/local/bin/
    sudo chmod +x /usr/local/bin/"$script"
    sudo chown "$DEFAULT_USER:$DEFAULT_USER" /usr/local/bin/"$script"
  done

  echo "🛠 Creating netconfig systemd service..."
  sudo tee /etc/systemd/system/netconfig.service > /dev/null <<EOT
[Unit]
Description=CompanionPi network configuration
After=network.target

[Service]
ExecStart=/usr/local/bin/netconfig.sh
Type=oneshot
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOT
fi

# Step 3: WebApp
if [[ "$ONLY_SCRIPTS" = false ]]; then
  echo ""
  echo "🌐 Installing Flask WebApp..."
  sudo mkdir -p /opt/WebApp
  sudo cp -r WebApp/* /opt/WebApp/
  sudo chmod +x /opt/WebApp/config-web.py
  sudo chown -R "$DEFAULT_USER:$DEFAULT_USER" /opt/WebApp

  echo "🛠 Creating config-web systemd service..."
  sudo tee /etc/systemd/system/config-web.service > /dev/null <<EOT
[Unit]
Description=CompanionPi Web Interface
After=network.target

[Service]
ExecStart=/usr/bin/python3 /opt/WebApp/config-web.py
WorkingDirectory=/opt/WebApp
Restart=always

[Install]
WantedBy=multi-user.target
EOT
fi

# Step 4: Enable services
echo ""
echo "🧩 Reloading and enabling services..."
sudo systemctl daemon-reload
[[ "$ONLY_WEBAPP" = false ]] && sudo systemctl enable netconfig
[[ "$ONLY_SCRIPTS" = false ]] && sudo systemctl enable config-web

# Step 5: Generate eth-monitor services
if [[ "$ONLY_WEBAPP" = false ]]; then
  echo ""
  echo "⚙️ Generating eth-monitor services based on settings.env..."
  sudo /usr/local/bin/generate-eth-monitor-services.sh
  sudo systemctl daemon-reload
fi

# Step 6: Set permissions
echo ""
echo "🔐 Fixing file permissions and ownerships..."

sudo chown -R "$DEFAULT_USER:$DEFAULT_USER" /etc/companionpi
sudo chmod -R u+rw /etc/companionpi

for f in "${SCRIPT_LIST[@]}"; do
  sudo chown "$DEFAULT_USER:$DEFAULT_USER" "/usr/local/bin/$f"
  sudo chmod u+rw "/usr/local/bin/$f"
done

sudo chown -R "$DEFAULT_USER:$DEFAULT_USER" /opt/WebApp
sudo chmod -R u+rw /opt/WebApp

# Step 7: Create install flag
sudo touch "$INSTALL_FLAG"
sudo chown "$DEFAULT_USER:$DEFAULT_USER" "$INSTALL_FLAG"

echo ""
echo "✅ Installation complete."
echo "🔁 Please reboot your Raspberry Pi to apply the configuration:"
echo "    sudo reboot"