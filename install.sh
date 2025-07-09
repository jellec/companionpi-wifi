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

for arg in "$@"; do
  case $arg in
    --only-scripts) ONLY_SCRIPTS=true ;;
    --only-webapp) ONLY_WEBAPP=true ;;
    --force-settings) FORCE_SETTINGS=true ;;
    --dev) DEV_MODE=true ;;
  esac
done

SETTINGS_DEFAULT="settings-default.env"
SETTINGS_LOCAL="settings.env"
SETTINGS_TARGET="/etc/companionpi/settings.env"
USER_HOME=$(eval echo ~"$SUDO_USER")

# Step 1: Handle settings.env
if [[ "$ONLY_WEBAPP" = false ]]; then
  sudo mkdir -p /etc/companionpi
  sudo chown "$USER:$USER" /etc/companionpi

  if [[ -f "$SETTINGS_TARGET" && "$FORCE_SETTINGS" = false ]]; then
    echo "📂 A system settings file already exists: $SETTINGS_TARGET"
    echo "📝 Please review and update it as needed."
    echo "Press ENTER to open the editor..."
    read
    sudo cp "$SETTINGS_TARGET" "$USER_HOME/settings.tmp"
    sudo chown "$USER:$USER" "$USER_HOME/settings.tmp"
    nano "$USER_HOME/settings.tmp"
    sudo cp "$USER_HOME/settings.tmp" "$SETTINGS_TARGET"
    rm "$USER_HOME/settings.tmp"

  else
    # Copy default to local if it doesn't exist yet
    if [ ! -f "$SETTINGS_LOCAL" ]; then
      echo "⚙️  No local settings.env found – copying default..."
      cp "$SETTINGS_DEFAULT" "$SETTINGS_LOCAL"
    fi

    echo "📋 No system settings file found (or --force-settings used)."
    echo "📝 Please review and edit the settings before continuing."
    echo "Press ENTER to open the editor..."
    read
    nano "$SETTINGS_LOCAL"

    echo "📥 Saving settings to system path..."
    sudo cp "$SETTINGS_LOCAL" "$SETTINGS_TARGET"
  fi

  sudo chown "$USER:$USER" "$SETTINGS_TARGET"
  sudo chmod 664 "$SETTINGS_TARGET"
fi

# Step 2: Install scripts
if [[ "$ONLY_WEBAPP" = false ]]; then
  echo ""
  echo "📄 Installing scripts to /usr/local/bin..."
  for script in netconfig.sh generate-dnsmasq.sh eth_monitor.sh check.sh generate-eth-monitor-services.sh; do
    sudo cp "$script" /usr/local/bin/
    sudo chmod +x /usr/local/bin/"$script"
    sudo chown "$USER:$USER" /usr/local/bin/"$script"
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
  sudo chown -R "$USER:$USER" /opt/WebApp

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

# Step 5: Eth-monitor services
if [[ "$ONLY_WEBAPP" = false ]]; then
  echo ""
  echo "⚙️ Generating eth-monitor services based on settings.env..."
  sudo /usr/local/bin/generate-eth-monitor-services.sh
  sudo systemctl daemon-reload
fi

echo ""
echo "✅ Installation complete."
echo "🔁 Please reboot your Raspberry Pi to apply the configuration:"
echo "    sudo reboot"