#!/bin/bash
set -e
set -x  # DEBUG

REPO_URL="https://github.com/jellec/companionpi-wifi"
REPO_DIR="/tmp/companionpi-wifi"

# Install git if not available
if ! command -v git &>/dev/null; then
  echo "📦 git niet gevonden – installeren..."
  sudo apt update
  sudo apt install -y git
fi

echo "📦 CompanionPi Setup gestart..."
echo "🌐 Repo: $REPO_URL"
echo "📁 Doelmap: $REPO_DIR"

echo "🧹 Verwijderen van oude tijdelijke installatiemap (indien aanwezig)..."
rm -rf "$REPO_DIR"

echo "⬇️ Clonen van de laatste versie van CompanionPi..."
git clone "$REPO_URL" "$REPO_DIR"

echo "📂 Map openen en installatiescript starten..."
cd "$REPO_DIR"
chmod +x install.sh

echo "🚀 Installatie starten..."
./install.sh