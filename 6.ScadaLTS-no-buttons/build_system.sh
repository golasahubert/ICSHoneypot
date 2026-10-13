#!/bin/bash

set -e  # Exit on any error
cd "$(dirname "$0")"  # Change to the directory of the script

# True if all given apt packages are installed (Ubuntu 24.04+ renamed
# some of them with a t64 suffix, e.g. libasound2 -> libasound2t64)
pkgs_installed() {
  for p in "$@"; do
    dpkg-query -W -f='${Status}' "$p" "${p}t64" 2>/dev/null | grep -q "install ok installed" || return 1
  done
}

echo "[+] Updating APT and installing required system packages..."
if pkgs_installed python3-venv docker.io docker-compose; then
  echo "[=] System packages already installed, skipping apt"
else
  sudo apt update
  sudo apt install -y python3-venv docker.io docker-compose
fi

echo "[+] Ensuring that previous environment is stopped..."
sudo bash kill_docker.sh

echo "[+] Removing DB Storage volume (if it exists)..."
DB_VOLUMES=$(sudo docker volume ls -q | grep db_storage || true)
if [ -n "$DB_VOLUMES" ]; then
  sudo docker volume rm $DB_VOLUMES
else
  echo "[!] No db_storage volume found, skipping removal."
fi

echo "[+] Ensuring that all docker networks are dead"
sudo docker-compose down
sudo docker network prune -f

echo "[+] Restarting Docker"
sudo systemctl restart docker

echo "[+] Building Docker images..."
sudo docker-compose up -d --build

echo "[+] Waiting for containers to initialize..."
sleep 5

# The collector is installed before Playwright/Chromium, so data collection
# starts as soon as the PLCs are up (it reconnects by itself during the
# restart below). Server 6 does not publish PLC2 Modbus on the host, hence
# 6.config.yaml (PLC2 read from its container IP).
echo "[+] Installing PLC data collector service (plc-collector)..."
sudo bash ../all-systems-collector/install_service.sh 6.config.yaml

echo "[+] Setting up Python virtual environment..."
cd automation

if [ ! -d "venv" ]; then
  echo "[+] Creating virtual environment..."
  python3 -m venv venv || { echo "[X] Failed to create virtual environment."; exit 1; }
fi

echo "[+] Activating virtual environment..."
source venv/bin/activate

if [ -f "requirements.txt" ]; then
  echo "[+] Installing Python dependencies..."
  pip install --upgrade pip
  pip install -r requirements.txt
fi

echo "[+] Running setup_import.sh..."
sudo bash setup_import.sh

deactivate
cd ..

echo "[OK] Build and setup complete."

echo "[+] Restarting the environment..."
sudo bash stop_system.sh
sudo bash start_system.sh

echo "[OK] Restarting Complete."
