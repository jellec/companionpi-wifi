#!/bin/bash
# install.sh – Install CompanionPi-wifi scripts, settings, and WebApp

set -e
cd "$(dirname "$0")"

# Block root execution
if [[ "$EUID" -eq 0 ]]; then
    echo "❌ ERROR: Do not run install.sh as root or with sudo. Only use sudo where prompted."
    exit 1
fi

# Logging
log() {
    echo "    install [$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

print_help() {
    cat <<EOF
Usage: install.sh [OPTIONS]

Options:
  --help             Show this help message and exit
  --only-scripts     Only install CLI scripts (no WebApp)
  --only-webapp      Only install WebApp (no CLI tools or services)
  --force-settings   Overwrite existing settings.env (will prompt with editor)
  --force-install    Force installation even if already installed
  --dev              Developer mode (used for symlinks or dev-specific behavior)
EOF
    exit 0
}

# Flags
ONLY_SCRIPTS=false
ONLY_WEBAPP=false
FORCE_SETTINGS=false
DEV_MODE=false
FORCE_INSTALL=false

for arg in "$@"; do
  case $arg in
    --help) print_help ;;
    --only-scripts) ONLY_SCRIPTS=true ;;
    --only-webapp) ONLY_WEBAPP=true ;;
    --force-settings) FORCE_SETTINGS=true ;;
    --force-install) FORCE_INSTALL=true ;;
    --dev) DEV_MODE=true ;;
    *)
      echo "❌ Unknown argument: $arg"
      print_help
      ;;
  esac
done

# Vars
SETTINGS_DEFAULT="settings-default.env"
SETTINGS_LOCAL="settings.env"
SETTINGS_TARGET="/etc/companionpi-wifi/settings.env"
INSTALL_FLAG="/etc/companionpi-wifi/installed.flag"
BACKUP_DIR="/etc/companionpi-wifi/backups"

# Only use sudo for system directories!
if ! sudo test -d /etc/companionpi-wifi; then
    sudo mkdir -p /etc/companionpi-wifi
fi
if ! sudo test -d "$BACKUP_DIR"; then
    sudo mkdir -p "$BACKUP_DIR"
fi

backup_settings() {
    if [[ -f "$SETTINGS_TARGET" ]]; then
        local ts
        ts=$(date +"%Y%m%d%H%M%S")
        local file="$BACKUP_DIR/settings.env.$ts"
        sudo cp "$SETTINGS_TARGET" "$file"
        log "🔁 Backed up existing settings to $file"
    fi
}

# Step 1: settings.env
if [[ "$ONLY_WEBAPP" = false ]]; then
    # Determine which settings to use
    if [[ -f "$SETTINGS_TARGET" && "$FORCE_SETTINGS" = false ]]; then
        log "📂 Found existing settings: $SETTINGS_TARGET"
        backup_settings
        log "📄 Copying to local: $SETTINGS_LOCAL"
        cp "$SETTINGS_TARGET" "$SETTINGS_LOCAL"
    else
        log "⚙️ Using default settings."
        cp "$SETTINGS_DEFAULT" "$SETTINGS_LOCAL"
    fi

    log "📝 Please review and edit your network settings."
    echo ""
    echo "📄 Settings file: $SETTINGS_LOCAL"
    echo "Press ENTER to open the editor..."
    read

    # Open settings.env in nano as the current user (no sudo)
    if command -v nano >/dev/null 2>&1; then
        # nano "$SETTINGS_LOCAL"
    else
        log "❌ nano editor not found. Please install nano."
        exit 1
    fi

    ./edit_settings.sh


    log "📥 Copying to system path..."
    sudo cp "$SETTINGS_LOCAL" "$SETTINGS_TARGET"
    sudo chmod 664 "$SETTINGS_TARGET"
    sudo chown root:root "$SETTINGS_TARGET"
fi

# Step 2: Install scripts
if [[ "$ONLY_WEBAPP" = false ]]; then
    log "📄 Installing scripts to /usr/local/bin..."
    SCRIPT_LIST=(
        netconfig.sh
        generate-dnsmasq.sh
        eth_monitor.sh
        check.sh
        generate-eth-monitor-services.sh
    )
    for script in "${SCRIPT_LIST[@]}"; do
        if [[ ! -f "$script" ]]; then
            log "❌ ERROR: Missing script $script"
            exit 1
        fi
        sudo cp "$script" "/usr/local/bin/"
        sudo chmod +x "/usr/local/bin/$script"
        sudo chown root:root "/usr/local/bin/$script"
    done

    log "🛠 Creating netconfig systemd service..."
    echo "[Unit]
Description=companionpi-wifi network configuration
After=network.target

[Service]
ExecStart=/usr/local/bin/netconfig.sh
Type=oneshot
RemainAfterExit=true

[Install]
WantedBy=multi-user.target" | sudo tee /etc/systemd/system/netconfig.service > /dev/null
fi

# Step 3: WebApp
if [[ "$ONLY_SCRIPTS" = false ]]; then
    log "🌐 Installing Flask WebApp..."
    if [[ ! -d WebApp ]]; then
        log "❌ ERROR: WebApp directory not found."
        exit 1
    fi
    sudo mkdir -p /opt/WebApp
    sudo cp -r WebApp/* /opt/WebApp/
    [[ -f /opt/WebApp/config-web.py ]] && sudo chmod +x /opt/WebApp/config-web.py
    sudo chown -R root:root /opt/WebApp

    log "🛠 Creating config-web systemd service..."
    echo "[Unit]
Description=companionpi-wifi Web Interface
After=network.target

[Service]
ExecStart=/usr/bin/python3 /opt/WebApp/config-web.py
WorkingDirectory=/opt/WebApp
Restart=always

[Install]
WantedBy=multi-user.target" | sudo tee /etc/systemd/system/config-web.service > /dev/null
fi

# Step 4: Enable services
log "🔁 Enabling services..."
[[ "$ONLY_WEBAPP" = false ]] && sudo systemctl enable netconfig
[[ "$ONLY_SCRIPTS" = false ]] && sudo systemctl enable config-web
sudo systemctl daemon-reload

# Step 5: eth-monitor services
if [[ "$ONLY_WEBAPP" = false ]]; then
    log "⚙️ Generating eth-monitor services..."
    sudo /usr/local/bin/generate-eth-monitor-services.sh
    sudo systemctl daemon-reload
fi

# Step 6: Permissions (only for system dirs, not repo)
log "🔐 Fixing permissions..."
sudo chown -R root:root /etc/companionpi-wifi
sudo chmod -R u+rw /etc/companionpi-wifi
for f in "${SCRIPT_LIST[@]}"; do
    sudo chown root:root "/usr/local/bin/$f"
    sudo chmod u+rw "/usr/local/bin/$f"
done
sudo chown -R root:root /opt/WebApp
sudo chmod -R u+rw /opt/WebApp

# Step 7: Mark installed
log "📌 Marking system as installed."
sudo touch "$INSTALL_FLAG"
sudo chown root:root "$INSTALL_FLAG"

log ""
log "✅ Installation complete."
log "🔁 Please reboot your Raspberry Pi to apply configuration:"
log "    sudo reboot"