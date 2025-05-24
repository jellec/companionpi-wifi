from flask import Flask, render_template, request, redirect, url_for
import subprocess
import re
import os

app = Flask(__name__)

# Function to retrieve current eth0 settings using nmcli
def get_eth0_settings():
    try:
        # Use nmcli to get detailed information about eth0-fix connection
        cmd = "nmcli -f GENERAL.CONNECTION,IP4.ADDRESS,IP4.GATEWAY device show eth0"
        output = subprocess.check_output(cmd, shell=True, text=True).strip()

        return output
    except subprocess.CalledProcessError as e:
        return {'error': f'Error: {e.returncode}. Unable to fetch eth0 details.'}


# Function to retrieve current eth0-fix settings using nmcli
def get_eth0_fix_settings():
    try:
        # Use nmcli to get detailed information about eth0-fix connection
        cmd = "nmcli -f IPV4.ADDRESSES connection show eth0-fix"
        output = subprocess.check_output(cmd, shell=True, text=True).strip()

        # Extract ipv4.addresses from the output
        eth0_ip = {'ipv4_address': output.split()[1]}  # Get ipv4.addresses

        return eth0_ip
    except subprocess.CalledProcessError as e:
        return {'error': f'Error: {e.returncode}. Unable to fetch eth0-fix details.'}


# Function to retrieve current WiFi AP settings using nmcli
def get_wifi_ap_settings():
    try:
        cmd = "nmcli -f IP4.ADDRESS,802-11-wireless.ssid connection show Wifi-AP"
        output = subprocess.check_output(cmd, shell=True, text=True).strip()
        return output
    except subprocess.CalledProcessError as e:
        return {'error': f"Connection 'Wifi-AP' not found or not active."}


def get_dhcp_range():
    dhcp_range = {
        "start": None,
        "end": None
    }
    try:
        with open('/etc/dnsmasq.d/wifi_ap.conf', 'r') as file:
            data = file.read()
            print("DHCP Configuration File Content:")
            print(data)
            # Adjust the regex based on the actual content
            match = re.search(r'range=(\d+\.\d+\.\d+\.\d+),(\d+\.\d+\.\d+\.\d+),', data)
            if match:
                dhcp_range['start'] = match.group(1)
                dhcp_range['end'] = match.group(2)
            else:
                print("No match found.")
    except FileNotFoundError:
        print("DHCP configuration file not found.")
    except Exception as e:
        print(f"An error occurred: {e}")
    
    return dhcp_range


# Function to change eth0 static IP using nmcli
def change_eth0_ip(new_ip):
    try:
        # Change eth0 IP address using nmcli
        cmd = f"sudo nmcli connection modify 'eth0-fix' ipv4.addresses {new_ip}"
        subprocess.run(cmd, shell=True, check=True)

        return True  # Return True if IP change was successful
    except subprocess.CalledProcessError as e:
        print(f"Error: {e}")
        return False  # Return False if there was an error

# Function to change WiFi AP settings using nmcli
def change_wifi_ap_settings(new_ssid, new_wpa_passphrase, new_dhcp_range):
    # Example: Change WiFi AP settings using nmcli
    # Replace 'Wifi-AP' with your actual connection name
    cmd = f"sudo nmcli connection modify 'Wifi-AP' wifi.ssid {new_ssid} wifi-security.key-mgmt wpa-psk wifi-security.psk {new_wpa_passphrase}"
    subprocess.run(cmd, shell=True)

    # Example: Update DHCP range in dnsmasq (if applicable)
    # This example assumes /etc/dnsmasq.conf contains the DHCP range
    cmd_dhcp = f"sudo sed -i 's/^dhcp-range=.*/dhcp-range={new_dhcp_range}/' /etc/dnsmasq.conf"
    subprocess.run(cmd_dhcp, shell=True)


def write_dhcp_settings(start, end):
    try:
        with open('/etc/dnsmasq.d/wifi_ap.conf', 'w') as file:
            file.write(f"dhcp-range={start},{end},12h\n")
        return True
    except Exception as e:
        print(f"An error occurred while writing to the file: {e}")
        return False



@app.route('/')
def index():
    eth0_settings = get_eth0_settings()
    eth0_fix_settings = get_eth0_fix_settings()
    wifi_ap_settings = get_wifi_ap_settings()
    wifi_dhcp_range = get_dhcp_range()

    path = '/opt/companion-module-dev'
    try:
        # Get the list of files and directories
        contents = os.listdir(path)
        items = []
        for item in contents:
            item_path = os.path.join(path, item)
            if os.path.isfile(item_path):
                item_type = 'File'
            elif os.path.isdir(item_path):
                item_type = 'Directory'
            else:
                item_type = 'Other'
            items.append({'name': item, 'type': item_type})
        return render_template( 'index.html', 
                                eth0_settings=eth0_settings, 
                                eth0_fix_settings=eth0_fix_settings, 
                                eth0_fix_ip=eth0_fix_settings.get('ipv4_address'),
                                wifi_ap_settings=wifi_ap_settings, 
                                wifi_ap_settings_ssid=wifi_ap_settings.split()[1],
                                wifi_ap_settings_ip=wifi_ap_settings.split()[3],
                                wifi_ap_dhcp_range=wifi_dhcp_range,
                                wifi_ap_dhcp_start=wifi_dhcp_range.get('start'),
                                wifi_ap_dhcp_end=wifi_dhcp_range.get('end'),
                                items=items,
                                path=path
                                )

    except Exception as e:
        print(f"An error occurred: {e}")
        return str(e), 500





@app.route('/change_eth0_ip', methods=['POST'])
def change_eth0_ip_route():
    new_ip = request.form['new_ip']
    
    # Attempt to change the eth0 IP address
    if change_eth0_ip(new_ip):
        confirmation_message = f"Success! Eth0-fix IP address changed to {new_ip}."
    else:
        confirmation_message = "Failed to change Eth0-fix IP address."
    
    # Render the confirmation message and redirect back to index after delay
    return render_template('confirmation.html', message=confirmation_message, redirect_url=url_for('index'))


@app.route('/change_wifi_ap_settings', methods=['POST'])
def change_wifi_ap_settings_route():
    new_ssid = request.form['new_ssid']
    new_wpa_passphrase = request.form['new_wpa_passphrase']
    new_wifi_ip = request.form['new_wifi_ip']
    new_dhcp_start = request.form['new_dhcp_start']
    new_dhcp_end = request.form['new_dhcp_end']
    

    wifi_ok = change_wifi_ap_settings(new_ssid, new_wpa_passphrase, new_wifi_ip)
    dhcp_ok = write_dhcp_settings(new_dhcp_start, new_dhcp_end)
    if wifi_ok and dhcp_ok:
        confirmation_message = f"Success! Parameters changed."
    else:
        confirmation_message = f"Failed to change. /n  Wifi OK = {wifi_ok} /n  DHCP OK = {dhcp_ok}"
    
    # Render the confirmation message and redirect back to index after delay
    return render_template('confirmation.html', message=confirmation_message, redirect_url=url_for('index'))

@app.route('/restart_companion', methods=['POST'])
def restart_companion():
    try:
        # Restart the companion service
        subprocess.run(['sudo', 'systemctl', 'restart', 'companion'], check=True)
        return redirect(url_for('index'))
    except subprocess.CalledProcessError as e:
        return f"Failed to restart companion service: {e}"

        

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8001)
