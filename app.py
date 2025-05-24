from flask import Flask, request, render_template_string
import subprocess

app = Flask(__name__)

@app.route("/")
def index():
    eth0_ip = subprocess.getoutput("ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}'")
    wlan0_ip = subprocess.getoutput("ip -4 addr show wlan0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}'")
    return render_template_string("""
        <h1>Network Configuration</h1>
        <p>eth0 IP: {{ eth0 }}</p>
        <p>wlan0 IP: {{ wlan }}</p>
        <form method="POST" action="/config">
            <!-- Configuration form here -->
        </form>
    """, eth0=eth0_ip, wlan=wlan0_ip)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8001)
