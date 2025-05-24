# CompanionPi Setup

This script configures a Raspberry Pi as a CompanionPi access point with network configurator:

- WiFi as Access Point with SSID and password
- DHCP server on wlan0
- eth0 tries DHCP and falls back to static IP if no lease in 30 seconds
- Web interface on port 8001 to review/change configuration

## 🛠️ Install in one command

Paste this into your Raspberry Pi terminal:

```bash
curl -sL https://github.com/jellec/companionpi-wifi/archive/refs/heads/main.zip -o - | bsdtar -xvf- && cd companionpi-wifi-main && chmod +x install.sh && ./install.sh
```

Make sure you have internet access via Ethernet when running this.
