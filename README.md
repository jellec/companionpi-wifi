# CompanionPi Setup

This script configures a Raspberry Pi as a CompanionPi access point with network configurator:

- WiFi as Access Point with SSID and password
- DHCP server on wlan0
- eth0 tries DHCP and falls back to static IP if no lease in 30 seconds
- Web interface on port 8001 to review/change configuration

## 🛠️ Install in one command

Paste this into your Raspberry Pi terminal:

```bash
bash <(curl -s https://raw.githubusercontent.com/jellec/companionpi-wifi/main/setup.sh)
```

Make sure you have internet access via Ethernet when running this.
