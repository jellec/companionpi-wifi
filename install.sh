#!/bin/bash
set -e
cd "$(dirname "$0")"

echo "🔧 Starting CompanionPi NetworkManager-based setup..."

SETTINGS_DEFAULT="settings-default.env"
SETTINGS_LOCAL="settings.env"
SETTINGS_TARGET="/etc/companionpi/settings.env"

# Step 1: Create or compare settings.env
if [ ! -f "$SETTINGS_LOCAL" ]; then
    echo "⚙️  No local settings found, copying default..."
    cp "$SETTINGS_DEFAULT" "$SETTINGS_LOCAL"
    echo ""
    echo "📝 Please review and edit your network settings now."
    echo "🔧 Use CTRL+S to save, CTRL+X to exit."
    nano "$SETTINGS_LOCAL"
else
    echo "📝 Local settings.env exists."
    if [ -f "$SETTINGS_TARGET" ]; then
        echo "🔍 Comparing with system settings..."
        diff_output=$(diff -u "$SETTINGS_TARGET" "$SETTINGS_LOCAL" || true)
        if [ -n "$diff_output" ]; then
            echo "$diff_output"
            echo ""
            read -p "⚠️  Differences found. Overwrite system settings with local version? [y/N] " overwrite
            if [[ "$overwrite" =~ ^[Yy]$ ]]; then
                sudo cp "$SETTINGS_LOCAL" "$SETTINGS_TARGET"
                echo "✅ Updated system settings."
            else
                echo "❌ Keeping existing system settings."
            fi
        else
            echo "✅ No differences found in settings."
        fi
    else
        echo "📂 Copying settings.env to system location..."
        sudo mkdir -p /etc/companionpi
        sudo cp "$SETTINGS_LOCAL" "$SETTINGS_TARGET"
    fi
fi

# Step 2: Install dependencies
echo "📦 Installing required packages..."
sudo apt update
sudo apt install -y network-manager python3-flask dnsmasq git rfkill raspi-config curl unzip

# Step 2.5: Wi-Fi country check
echo "📡 Checking Wi-Fi regulatory domain settings..."
source "$SETTINGS_LOCAL"
WIFI_COUNTRY="${WIFI_COUNTRY:-BE}"

CURRENT_COUNTRY=$(sudo raspi-config nonint get_wifi_country 2>/dev/null || echo "NOT_SET")

if [ "$CURRENT_COUNTRY" = "NOT_SET" ] || [ "$CURRENT_COUNTRY" = "00" ]; then
    echo "⚠️  Wi-Fi country not set. Setting to: $WIFI_COUNTRY"
    sudo raspi-config nonint do_wifi_country "$WIFI_COUNTRY"
    echo "✅ Wi-Fi country set to $WIFI_COUNTRY"
else
    echo "✅ Wi-Fi country already set to: $CURRENT_COUNTRY"
fi

# Step 3: Install scripts
echo "📄 Installing scripts to /usr/local/bin..."
sudo cp netconfig.sh /usr/local/bin/netconfig.sh
sudo cp generate-dnsmasq.sh /usr/local/bin/generate-dnsmasq.sh
sudo cp eth_monitor.sh /usr/local/bin/eth_monitor.sh
sudo cp check.sh /usr/local/bin/check.sh
sudo cp generate-eth-monitor-services.sh /usr/local/bin/generate-eth-monitor-services.sh
sudo chmod +x /usr/local/bin/*.sh
sudo systemctl restart dnsmasq

# Step 4: netconfig service
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

# Step 5: Flask webinterface
echo "🌐 Installing Flask WebApp..."
sudo mkdir -p /opt/WebApp
sudo cp -r WebApp/* /opt/WebApp/
sudo chmod +x /opt/WebApp/config-web.py

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

# Step 6: Bitfocus Companion installation (prebuilt)
echo "🎛 Downloading and installing Bitfocus Companion prebuilt release..."
COMPANION_DIR="/opt/companion"
COMPANION_BIN="$COMPANION_DIR/companion"

# Clean previous installation if broken
sudo rm -rf "$COMPANION_DIR"
sudo mkdir -p "$COMPANION_DIR"
sudo chown "$USER":"$USER" "$COMPANION_DIR"
cd "$COMPANION_DIR"

# Download latest release
COMPANION_URL="https://github.com/bitfocus/companion/releases/latest/download/companion-rpi.zip"

if curl -fLo companion.zip "$COMPANION_URL"; then
    unzip companion.zip
    chmod +x companion
    echo "✅ Companion downloaded and unpacked"
else
    echo "❌ ERROR: Failed to download Companion binary from GitHub"
    exit 1
fi

# Step 7: systemd service
echo "🛠 Creating systemd service for Companion..."
sudo tee /etc/systemd/system/companion.service > /dev/null <<EOT
[Unit]
Description=Bitfocus Companion
After=network.target

[Service]
ExecStart=/opt/companion/companion
WorkingDirectory=/opt/companion
Restart=always
User=$USER

[Install]
WantedBy=multi-user.target
EOT

# Step 8: Enable everything
sudo systemctl daemon-reload
sudo systemctl enable netconfig
sudo systemctl enable config-web
sudo systemctl enable companion

echo "⚙️ Generating eth-monitor services based on settings.env..."
sudo /usr/local/bin/generate-eth-monitor-services.sh
sudo systemctl daemon-reload

echo ""
echo "✅ Installation complete."
echo "🔁 Please reboot your Raspberry Pi to apply all settings:"
echo "    sudo reboot"