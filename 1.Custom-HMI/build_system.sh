#!/bin/bash

set -e  # Stop the script on any error
cd "$(dirname "$0")"

# --- COLOR CONFIGURATION ---
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[+] $1${NC}"
}

err() {
    echo -e "${RED}[✘] $1${NC}"
}

# True if all given apt packages are installed (Ubuntu 24.04+ renamed
# some of them with a t64 suffix, e.g. libasound2 -> libasound2t64)
pkgs_installed() {
    for p in "$@"; do
        dpkg-query -W -f='${Status}' "$p" "${p}t64" 2>/dev/null | grep -q "install ok installed" || return 1
    done
}

# --- STEP 1: CLEANUP AND DEPENDENCY INSTALLATION ---

log "Ensuring that previous environment is stopped..."
if [ -f "kill_docker.sh" ]; then
    sudo bash kill_docker.sh
else
    sudo docker-compose down -v --remove-orphans > /dev/null 2>&1 || true
fi

log "Updating APT and installing required system packages..."
if pkgs_installed python3-venv docker.io docker-compose; then
    log "System packages already installed, skipping apt"
else
    sudo apt update
    sudo apt install -y python3-venv docker.io docker-compose
fi

log "Ensuring (again) that previous environment is stopped..."
if [ -f "kill_docker.sh" ]; then
    sudo bash kill_docker.sh
fi

# --- STEP 2: BUILDING AND STARTING CONTAINERS ---

log "Building and Starting containers..."
sudo docker-compose up -d --build

log "Waiting for containers to initialize..."
sleep 10

# --- STEP 3: PYTHON AND PLAYWRIGHT SETUP ---

log "Setting up Python virtual environment..."
cd automation

if [ ! -d "venv" ]; then
    log "Creating virtual environment..."
    python3 -m venv venv || { err "Failed to create virtual environment."; exit 1; }
fi

# Fix any broken ownership (e.g. from a previous accidental sudo pip install)
log "Fixing venv ownership (if needed)..."
sudo chown -R "$(whoami)":"$(whoami)" venv

# Define paths to the venv binaries
VENV_PYTHON="$(pwd)/venv/bin/python"
VENV_PIP="$(pwd)/venv/bin/pip"
VENV_PLAYWRIGHT="$(pwd)/venv/bin/playwright"

log "Upgrading pip..."
$VENV_PIP install --upgrade pip

# --- FIX: greenlet / Playwright / Python 3.14 compatibility ---
# Older Playwright versions pull in an outdated greenlet version that
# fails to compile on Python 3.14 (removed PyThreadState->trash field).
# We install a compatible greenlet and playwright first, before requirements.txt.
log "Pre-installing compatible greenlet and playwright versions..."
$VENV_PIP install --upgrade "greenlet>=3.5.1"
$VENV_PIP install --upgrade playwright

if [ -f "requirements.txt" ]; then
    log "Installing Python dependencies..."
    $VENV_PIP install --ignore-installed greenlet -r requirements.txt
fi

# --- PLAYWRIGHT SECTION ---
if [ -f "$VENV_PLAYWRIGHT" ]; then
    log "Installing Playwright browsers and dependencies..."

    # 1. Install browser binaries
    $VENV_PLAYWRIGHT install chromium

    # 2. Install system-level dependencies (requires sudo)
    # install-deps runs apt-get update every time; skip it if it already
    # succeeded for this Playwright version
    PW_VERSION=$($VENV_PLAYWRIGHT --version)
    if [ "$(cat .playwright_deps 2>/dev/null)" = "$PW_VERSION" ]; then
        log "Playwright system dependencies already installed for $PW_VERSION, skipping"
    else
        sudo $VENV_PLAYWRIGHT install-deps chromium
        echo "$PW_VERSION" > .playwright_deps
    fi
else
    log "Playwright executable not found in venv. Skipping browser setup."
fi

log "Running setup_import.sh..."
sudo bash setup_import.sh

cd ..

log "Build and setup complete."

# --- STEP 4: FINAL RESTART ---

log "Restarting the environment..."

if [ -f "stop_system.sh" ] && [ -f "start_system.sh" ]; then
    sudo bash stop_system.sh
    sudo bash start_system.sh
else
    log "External scripts not found, using docker-compose restart..."
    sudo docker-compose restart
fi

log "System Ready. Restart Complete."

# --- STEP 5: PLC DATA COLLECTOR ---

log "Installing PLC data collector service (plc-collector)..."
sudo bash ../all-systems-collector/install_service.sh
