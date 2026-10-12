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

echo "[+] Ensuring that all docker networks are dead"
sudo docker-compose down
sudo docker network prune -f
sudo docker container prune -f
echo "[+] Restarting Docker"
sudo systemctl restart docker

echo "[+] Building Docker images..."
sudo docker-compose up -d --build

echo "[+] Waiting for containers to initialize..."
sleep 5

echo "[+] Setting up Python virtual environment..."
cd automation

if [ ! -d "venv" ]; then
  echo "[+] Creating virtual environment..."
  python3 -m venv venv || { echo "[✘] Failed to create virtual environment."; exit 1; }
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

echo "[✔] Build and setup complete."

echo "[+] Restarting the environment..."
sudo bash stop_system.sh
sudo bash start_system.sh

echo "[✔] Restarting Complete."

echo "[+] Installing PLC data collector service (plc-collector)..."
sudo bash ../all-systems-collector/install_service.sh
