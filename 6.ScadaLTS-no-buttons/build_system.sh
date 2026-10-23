#!/bin/bash
# Usage: bash build_system.sh [--rebuild]
#   --rebuild  rebuild the PLC/simulator images even if their build context is unchanged

set -e  # Exit on any error
cd "$(dirname "$0")"  # Change to the directory of the script

REBUILD=0
if [ "${1:-}" = "--rebuild" ]; then
  REBUILD=1
fi

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

# Server 6 has 1 GB RAM: without swap the machine freezes while the venvs and
# Chromium are installed next to the starting stack. Only added if no swap is active.
echo "[+] Ensuring swap is enabled..."
if [ -z "$(swapon --show --noheadings)" ]; then
  if [ ! -f /swapfile ]; then
    echo "[+] Creating 2 GB /swapfile..."
    sudo fallocate -l 2G /swapfile || sudo dd if=/dev/zero of=/swapfile bs=1M count=2048
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
  fi
  sudo swapon /swapfile
  grep -q '^/swapfile ' /etc/fstab || echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab >/dev/null
else
  echo "[=] Swap already active, skipping"
fi

# Server 6 has a 15 GB disk: a build of the PLC/simulator images does not fit next
# to the old images and their build cache. The images are therefore rebuilt only
# when their build context changed since the last successful build (or with
# --rebuild), and then from scratch after removing the old ones. Otherwise the
# existing images are reused and this script is just a clean restart.
BUILD_DIRS="plc_1_docker plc_2_docker plc_3_docker physical_sim_docker"
BUILD_IMAGES="6scadalts-no-buttons_plc1 6scadalts-no-buttons_plc2 6scadalts-no-buttons_plc3 6scadalts-no-buttons_simulator"
STAMP=.images_built  # build-context hash of the images in use
CONTEXT_HASH=$(find $BUILD_DIRS -type f -not -path '*/__pycache__/*' -print0 \
  | LC_ALL=C sort -z | xargs -0 sha256sum | sha256sum | cut -d' ' -f1)
if [ "$REBUILD" = 1 ]; then
  NEED_BUILD=1
elif ! sudo docker image inspect $BUILD_IMAGES >/dev/null 2>&1; then
  echo "[!] PLC/simulator images missing, they will be built"
  NEED_BUILD=1
elif [ -f "$STAMP" ] && [ "$(cat "$STAMP")" != "$CONTEXT_HASH" ]; then
  echo "[!] Build context changed since the last build, images will be rebuilt"
  NEED_BUILD=1
else
  # No stamp yet: the images predate this check and are adopted as current
  NEED_BUILD=0
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

# Nothing below is used by the new stack: kill_docker.sh removed the stopped
# containers, and dangling images are leftovers of earlier or failed builds
# (images are never rebuilt from cache, see above).
echo "[+] Removing unused Docker images and volumes, APT cache..."
if [ "$NEED_BUILD" = 1 ]; then
  sudo docker rmi $BUILD_IMAGES 2>/dev/null || true
fi
sudo docker image prune -f
sudo docker volume prune -f
sudo apt-get clean
df -h /

echo "[+] Restarting Docker"
sudo systemctl restart docker

if [ "$NEED_BUILD" = 1 ]; then
  FREE_GB=$(df --output=avail -BG / | tail -n 1 | tr -dc '0-9')
  if [ "$FREE_GB" -lt 5 ]; then
    echo "[!] Only ${FREE_GB} GB free, the image build may run out of disk space"
  fi
  echo "[+] Building Docker images..."
  sudo docker-compose build
else
  echo "[=] Build context unchanged, reusing existing images (--rebuild forces a build)"
fi
sudo docker-compose up -d --no-build
# Not fatal: without a stamp the next run adopts the images just started
echo "$CONTEXT_HASH" > "$STAMP" || echo "[!] Could not write $STAMP (disk full?)"

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
