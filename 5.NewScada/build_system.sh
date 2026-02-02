#!/bin/bash

set -e  # Exit on any error
cd "$(dirname "$0")"  # Change to the directory of the script

echo "[+] Ensuring that previous environment is stopped..."
sudo bash kill_docker.sh
sudo rm -rf db_data
echo "[+] Updating APT and installing required system packages..."
sudo apt update
sudo apt install -y python3-venv docker.io docker-compose

echo "[+] Ensuring that previous environment is stopped..."
sudo bash kill_docker.sh

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
