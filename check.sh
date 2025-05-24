#!/bin/bash
set -e

echo "🔍 Running system checks for CompanionPi..."

echo -n "📡 Checking hostapd... "
systemctl is-active --quiet hostapd && echo "✅ running" || echo "❌ not running"

echo -n "📦 Checking dnsmasq... "
systemctl is-active --quiet dnsmasq && echo "✅ running" || echo "❌ not running"

echo -n "🧷 Checking eth0 fallback... "
systemctl is-enabled --quiet eth0-fallback && echo "✅ enabled" || echo "❌ not enabled"

echo -n "🌐 Checking Flask service (config-web)... "
systemctl is-active --quiet config-web && echo "✅ running" || echo "❌ not running"

echo -n "📶 wlan0 IP: "
ip -4 addr show wlan0 | grep -oP '(?<=inet\\s)\\d+(\\.\\d+){3}' || echo "❌ not assigned"

echo -n "🔌 eth0 IP: "
ip -4 addr show eth0 | grep -oP '(?<=inet\\s)\\d+(\\.\\d+){3}' || echo "❌ not assigned"

echo "✅ Done."