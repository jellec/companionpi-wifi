from flask import Flask, render_template, request, redirect, url_for
import subprocess
import re
import os

app = Flask(__name__)

WIFI_IFACE = 'wlan0'
WIFI_AP_CONN = f"{WIFI_IFACE}-ap"
WIFI_DNSMASQ_CONF = f"/etc/dnsmasq.d/{WIFI_IFACE}_ap.conf"

def get_eth0_settings():
    try:
        cmd = "nmcli -f GENERAL.CONNECTION,IP4.ADDRESS,IP4.GATEWAY device show eth0"
        output = subprocess.check_output(cmd, shell=True, text=True).strip()
        return output
    except subprocess.CalledProcessError as e:
        return {'error': f'Error: {e.returncode}. Unable to fetch eth0 details.'}

def get_eth0_fix_settings():
    try:
        cmd = "nmcli -f IPV4.ADDRESSES connection show eth0-fix"
        output = subprocess.check_output(cmd, shell=True, text=True).strip()
        return {'ipv4_address': output.split()[1]}
    except subprocess.CalledProcessError:
        return {'ipv4_address': 'Unavailable'}

def get_wifi_ap_settings():
    try:
        cmd = f"nmcli -f IP4.ADDRESS,802-11-wireless.ssid connection show '{WIFI_AP_CONN}'"
        output = subprocess.check_output(cmd, shell=True, text=True).strip()
        return output
    except subprocess.CalledProcessError:
        return {'error': f"Connection '{WIFI_AP_CONN}' not found or not active."}

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

def change_eth0_ip(new_ip):
    try:
        cmd = f"sudo nmcli connection modify 'eth0-fix' ipv4.addresses {new_ip}"
        subprocess.run(cmd, shell=True, check=True)
        return True
    except subprocess.CalledProcessError:
        return False

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
    eth0_settings = get_eth0_settings()
    eth0_fix_settings = get_eth0_fix_settings()
    wifi_ap_settings = get_wifi_ap_settings()
    wifi_dhcp_range = get_dhcp_range()

    path = '/opt/companion-module-dev'
    items = []
    path_warning = None

    if os.path.exists(path):
        try:
            for item in os.listdir(path):
                item_path = os.path.join(path, item)
                item_type = 'Directory' if os.path.isdir(item_path) else 'File'
                items.append({'name': item, 'type': item_type})
        except Exception as e:
            path_warning = f"⚠️ Error reading {path}: {e}"
    else:
        path_warning = f"ℹ️ Directory '{path}' not found. This is expected in Companion v4 and newer."

    return render_template(
        'index.html',
        eth0_settings=eth0_settings,
        eth0_fix_settings=eth0_fix_settings,
        eth0_fix_ip=eth0_fix_settings.get('ipv4_address'),
        wifi_ap_settings=wifi_ap_settings,
        wifi_ap_settings_ssid=wifi_ap_settings.split()[1] if isinstance(wifi_ap_settings, str) else None,
        wifi_ap_settings_ip=wifi_ap_settings.split()[0] if isinstance(wifi_ap_settings, str) else None,
        wifi_ap_dhcp_range=wifi_dhcp_range,
        wifi_ap_dhcp_start=wifi_dhcp_range.get('start'),
        wifi_ap_dhcp_end=wifi_dhcp_range.get('end'),
        items=items,
        path=path,
        path_warning=path_warning
    )

@app.route('/change_eth0_ip', methods=['POST'])
def change_eth0_ip_route():
    new_ip = request.form['new_ip']
    success = change_eth0_ip(new_ip)
    message = f"Success! Eth0-fix IP address changed to {new_ip}." if success else "Failed to change Eth0-fix IP address."
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
    message = "✅ Parameters successfully updated." if wifi_ok and dhcp_ok else f"❌ Update failed. WiFi OK: {wifi_ok}, DHCP OK: {dhcp_ok}"
    return render_template('confirmation.html', message=message, redirect_url=url_for('index'))

@app.route('/restart_companion', methods=['POST'])
def restart_companion():
    try:
        subprocess.run(['sudo', 'systemctl', 'restart', 'companion'], check=True)
        return redirect(url_for('index'))
    except subprocess.CalledProcessError as e:
        return f"Failed to restart companion service: {e}"

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8001)