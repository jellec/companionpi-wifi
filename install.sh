#!/bin/bash
# install.sh – Install CompanionPi scripts, settings, and WebApp

set -e

cd "$(dirname "$0")"

# Function for logging messages with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Flags
ONLY_SCRIPTS=false
ONLY_WEBAPP=false
FORCE_SETTINGS=false
DEV_MODE=false
FORCE_INSTALL=false

# Parse command line arguments
for arg in "$@"; do
  case $arg in
    --only-scripts) ONLY_SCRIPTS=true ;;
    --only-webapp) ONLY_WEBAPP=true ;;
    --force-settings) FORCE_SETTINGS=true ;;
    --force-install) FORCE_INSTALL=true ;;
    --dev) DEV_MODE=true ;;
  esac
done

# Variables
SETTINGS_DEFAULT="settings-default.env"
SETTINGS_LOCAL="settings.env"
SETTINGS_TARGET="/etc/companionpi/settings.env"
INSTALL_FLAG="/etc/companionpi/installed.flag"
BACKUP_DIR="/etc/companionpi/backups"
DEFAULT_USER=${SUDO_USER:-$(whoami)}

# Create backup directory if it doesn't exist
sudo mkdir -p "$BACKUP_DIR"

# Backup existing settings if they exist
backup_settings() {
    if [[ -f "$SETTINGS_TARGET" ]]; then
        local timestamp=$(date +"%Y%m%d%H%M%S")
        local backup_file="$BACKUP_DIR/settings.env.$timestamp"
        sudo cp "$SETTINGS_TARGET" "$backup_file"
        log "Backed up existing settings to $backup_file"
    fi
}

# Restore settings from backup if needed
restore_settings() {
    local latest_backup=$(ls -t "$BACKUP_DIR"/settings.env.* | head -n 1)
    if [[ -n "$latest_backup" ]]; then
        sudo cp "$latest_backup" "$SETTINGS_TARGET"
        log "Restored settings from $latest_backup"
    fi
}

# Step 1: Handle settings.env
if [[ "$ONLY_WEBAPP" = false ]]; then
    sudo mkdir -p /etc/companionpi
    sudo chown "$DEFAULT_USER:$DEFAULT_USER" /etc/companionpi

    if [[ -f "$SETTINGS_TARGET" && "$FORCE_SETTINGS" = false ]]; then
        log "📂 System settings file already exists: $SETTINGS_TARGET"
        backup_settings

        log "📄 Copying current system settings to local project (settings.env)"
        sudo cp "$SETTINGS_TARGET" "$SETTINGS_LOCAL"
        sudo chown "$DEFAULT_USER:$DEFAULT_USER" "$SETTINGS_LOCAL"

        log "📝 Please review and update it if needed."
        log "Press ENTER to open the editor..."
        read
        nano "$SETTINGS_LOCAL"
        log "📥 Saving back to system path..."
        sudo cp "$SETTINGS_LOCAL" "$SETTINGS_TARGET"
    else
        if [[ ! -f "$SETTINGS_LOCAL" ]]; then
            log "⚙️ No local settings.env found – copying default..."
            cp "$SETTINGS_DEFAULT" "$SETTINGS_LOCAL"
        fi
        log "📋 No system settings found (or forced). Please review before continuing."
        log "Press ENTER to open the editor..."
        read
        nano "$SETTINGS_LOCAL"
        log "📥 Saving to system path..."
        sudo cp "$SETTINGS_LOCAL" "$SETTINGS_TARGET"
    fi
    sudo chown "$DEFAULT_USER:$DEFAULT_USER" "$SETTINGS_TARGET"
    sudo chmod 664 "$SETTINGS_TARGET"
fi

# Step 2: Install scripts
if [[ "$ONLY_WEBAPP" = false ]]; then
    log ""
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
            log "❌ ERROR: Script $script not found. Installation aborted."
            exit 1
        fi
        sudo cp "$script" "/usr/local/bin/"
        sudo chmod +x "/usr/local/bin/$script"
        sudo chown "$DEFAULT_USER:$DEFAULT_USER" "/usr/local/bin/$script"
    done
    log "🛠 Creating netconfig systemd service..."
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
    log ""
    log "🌐 Installing Flask WebApp..."
    sudo mkdir -p /opt/WebApp
    sudo cp -r WebApp/* /opt/WebApp/
    sudo chmod +x /opt/WebApp/config-web.py
    sudo chown -R "$DEFAULT_USER:$DEFAULT_USER" /opt/WebApp
    log "🛠 Creating config-web systemd service..."
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
log ""
log "🧩 Reloading and enabling services..."
sudo systemctl daemon-reload
[[ "$ONLY_WEBAPP" = false ]] && sudo systemctl enable netconfig
[[ "$ONLY_SCRIPTS" = false ]] && sudo systemctl enable config-web

# Step 5: Generate eth-monitor services
if [[ "$ONLY_WEBAPP" = false ]]; then
    log ""
    log "⚙️ Generating eth-monitor services based on settings.env..."
    sudo /usr/local/bin/generate-eth-monitor-services.sh
    sudo systemctl daemon-reload
fi

# Step 6: Set permissions
log ""
log "🔐 Fixing file permissions and ownerships..."
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

log ""
log "✅ Installation complete."
log "🔁 Please reboot your Raspberry Pi to apply the configuration:"
log "    sudo reboot"
