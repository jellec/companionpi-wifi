# CompanionPi Setup

This script configures a Raspberry Pi as a CompanionPi access point with network configurator:

- WiFi as Access Point with SSID and password
- DHCP server on wlan0
- eth0 tries DHCP and falls back to static IP if no lease in 30 seconds
- Web interface on port 8001 to review/change configuration

## 🛠️ Install in one command

### For end users (recommended, always works)
Paste this into your Raspberry Pi terminal:

```bash
bash <(curl -s https://raw.githubusercontent.com/jellec/companionpi-wifi/main/setup.sh)
```

Make sure you have internet access via Ethernet when running this.

---

### For developers (always latest code, fast)
Use this to always fetch the latest code from GitHub and install:

```bash
git clone --depth 1 https://github.com/jellec/companionpi-wifi /tmp/companionpi-wifi && \
cd /tmp/companionpi-wifi && \
sudo bash setup.sh --force-install --force-settings
```

This will let you review and edit settings
