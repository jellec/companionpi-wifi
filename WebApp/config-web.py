from flask import Flask, render_template, request, redirect, url_for
import subprocess
import re
import os

app = Flask(__name__)

SETTINGS_FILE = "/etc/companionpi-wifi/settings.env"
WIFI_IFACE = 'wlan0'
WIFI_AP_CONN = f"{WIFI_IFACE}-ap"
WIFI_DNSMASQ_CONF = f"/etc/dnsmasq.d/{WIFI_IFACE}_ap.conf"

def run_cmd(cmd):
    try:
        return subprocess.check_output(cmd, shell=True, text=True).strip()
    except subprocess.CalledProcessError:
        return None

def get_enabled_eth_ifaces():
    if not os.path.exists(SETTINGS_FILE):
        return []
    enabled = set()
    with open(SETTINGS_FILE) as f:
        for line in f:
            line = line.strip()
            if re.match(r'^ETH\d+_ENABLED=true$', line):
                prefix = line.split("_")[0]  # e.g. ETH0
                iface = prefix.lower()       # eth0
                if os.path.exists(f"/sys/class/net/{iface}"):
                    enabled.add(iface)
    return sorted(enabled)

def get_eth_connection_details(iface):
    results = {}
    for mode in ['auto', 'fix']:
        conn_name = f"{iface}-{mode}"
        result = {
            'name': conn_name,
            'address': 'Unavailable',
            'method': 'Unavailable',
            'gateway': 'Unavailable',
            'active': False
        }
        active = run_cmd("nmcli -t -f NAME connection show --active")
        if active and conn_name in active:
            result['active'] = True
        info = run_cmd(f"nmcli -g IPV4.ADDRESSES,IPV4.METHOD,IPV4.GATEWAY connection show '{conn_name}'")
        if info:
            fields = info.splitlines()
            if len(fields) >= 1:
                result['address'] = fields[0]
            if len(fields) >= 2:
                result['method'] = fields[1]
            if len(fields) >= 3:
                result['gateway'] = fields[2]
        results[mode] = result
    return results

def get_eth_mode_from_settings(iface):
    key = f"{iface.upper()}_MODE"
    if not os.path.exists(SETTINGS_FILE):
        return 'auto'
    with open(SETTINGS_FILE) as f:
        for line in f:
            if line.strip().startswith(key + "="):
                return line.strip().split("=")[1]
    return 'auto'

def change_eth_fix_ip(iface, new_ip):
    conn_name = f"{iface}-fix"
    try:
        subprocess.run(f"sudo nmcli connection modify '{conn_name}' ipv4.addresses {new_ip}", shell=True, check=True)
        return True
    except subprocess.CalledProcessError:
        return False

def get_wifi_ap_settings():
    output = run_cmd(f"nmcli -f IP4.ADDRESS,802-11-wireless.ssid connection show '{WIFI_AP_CONN}'")
    if not output:
        return {'ssid': 'Unavailable', 'ip': 'Unavailable'}
    lines = output.splitlines()
    return {
        'ip': lines[0].strip() if len(lines) > 0 else 'Unavailable',
        'ssid': lines[1].strip() if len(lines) > 1 else 'Unavailable'
    }

def get_dhcp_range():
    dhcp_range = {"start": None, "end": None}
    try:
        with open(WIFI_DNSMASQ_CONF, 'r') as file:
            data = file.read()
            match = re.search(r'range=(\d+\.\d+\.\d+\.\d+),(\d+\.\d+\.\d+\.\d+),', data)
            if match:
                dhcp_range['start'] = match.group(1)
                dhcp_range['end'] = match.group(2)
    except FileNotFoundError:
        pass
    return dhcp_range

def change_wifi_ap_settings(new_ssid, new_wpa_passphrase, new_ip):
    try:
        cmd = (
            f"sudo nmcli connection modify '{WIFI_AP_CONN}' "
            f"wifi.ssid {new_ssid} "
            f"wifi-sec.key-mgmt wpa-psk "
            f"wifi-sec.psk {new_wpa_passphrase} "
            f"ipv4.addresses {new_ip}"
        )
        subprocess.run(cmd, shell=True, check=True)
        return True
    except subprocess.CalledProcessError:
        return False

def write_dhcp_settings(start, end):
    try:
        with open(WIFI_DNSMASQ_CONF, 'w') as file:
            file.write(f"dhcp-range={start},{end},12h\n")
        return True
    except Exception:
        return False

@app.route('/')
def index():
    interfaces = []
    for iface in get_enabled_eth_ifaces():
        interfaces.append({
            'iface': iface,
            'mode': get_eth_mode_from_settings(iface),
            'connections': get_eth_connection_details(iface)
        })

    wifi_ap = get_wifi_ap_settings()
    dhcp_range = get_dhcp_range()

    return render_template(
        'index.html',
        interfaces=interfaces,
        wifi_ap=wifi_ap,
        dhcp_range=dhcp_range
    )

@app.route('/change_eth_ip', methods=['POST'])
def change_eth_ip_route():
    iface = request.form['iface']
    new_ip = request.form['new_ip']
    success = change_eth_fix_ip(iface, new_ip)
    message = f"✅ {iface}-fix IP updated to {new_ip}" if success else f"❌ Failed to update {iface}-fix IP"
    return render_template('confirmation.html', message=message, redirect_url=url_for('index'))

@app.route('/change_wifi_ap_settings', methods=['POST'])
def change_wifi_ap_settings_route():
    new_ssid = request.form['new_ssid']
    new_wpa_passphrase = request.form['new_wpa_passphrase']
    new_wifi_ip = request.form['new_wifi_ip']
    new_dhcp_start = request.form['new_dhcp_start']
    new_dhcp_end = request.form['new_dhcp_end']

    wifi_ok = change_wifi_ap_settings(new_ssid, new_wpa_passphrase, new_wifi_ip)
    dhcp_ok = write_dhcp_settings(new_dhcp_start, new_dhcp_end)
    message = "✅ Parameters updated." if wifi_ok and dhcp_ok else f"❌ Failed. WiFi OK: {wifi_ok}, DHCP OK: {dhcp_ok}"
    return render_template('confirmation.html', message=message, redirect_url=url_for('index'))

@app.route('/restart_companion', methods=['POST'])
def restart_companion():
    try:
        subprocess.run(['sudo', 'systemctl', 'restart', 'companion'], check=True)
        return redirect(url_for('index'))
    except subprocess.CalledProcessError as e:
        return f"Failed to restart companion: {e}"

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8001)