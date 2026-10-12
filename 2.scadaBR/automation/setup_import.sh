#!/bin/bash

set -e

# True if all given apt packages are installed (Ubuntu 24.04+ renamed
# some of them with a t64 suffix, e.g. libasound2 -> libasound2t64)
pkgs_installed() {
  for p in "$@"; do
    dpkg-query -W -f='${Status}' "$p" "${p}t64" 2>/dev/null | grep -q "install ok installed" || return 1
  done
}

# Step 1: Create virtual environment if it doesn't exist
if [ ! -d "venv" ]; then
    echo "[+] Creating virtual environment..."
    python3 -m venv venv
fi
# Step 2: Install dependencies for playwright
# Ubuntu 24.04+ renamed libasound2 to libasound2t64 (20.04/22.04 only have libasound2)
if apt-cache show libasound2t64 >/dev/null 2>&1; then LIBASOUND=libasound2t64; else LIBASOUND=libasound2; fi
PLAYWRIGHT_PKGS=(python3-venv libnss3 libatk1.0-0 libatk-bridge2.0-0 libcups2
  libxkbcommon0 libpango-1.0-0 libgbm1 "$LIBASOUND" libxshmfence1 libdrm2
  libxcomposite1 libxrandr2 libxi6 fonts-liberation)
if pkgs_installed "${PLAYWRIGHT_PKGS[@]}"; then
    echo "[=] Playwright apt packages already installed, skipping"
else
    sudo apt install -y "${PLAYWRIGHT_PKGS[@]}"
fi

# Step 3: Activate virtual environment
echo "[+] Activating virtual environment..."
source venv/bin/activate

# Step 4: Upgrade pip and install dependencies
echo "[+] Installing Playwright..."
pip install --upgrade pip
pip install playwright

# Step 5: Install Playwright browsers
playwright install chromium
# install-deps runs apt-get update every time; skip it if it already
# succeeded for this Playwright version
PW_VERSION=$(playwright --version)
if [ "$(cat .playwright_deps 2>/dev/null)" = "$PW_VERSION" ]; then
    echo "[=] Playwright system dependencies already installed for $PW_VERSION, skipping"
else
    playwright install-deps chromium
    echo "$PW_VERSION" > .playwright_deps
fi
# Step 6: Run the Python automation script
echo "[+] Running SCADA-BR login script..."
python login_scada.py

# Step 7: Run the Python automation script
echo "[+] Running OPENPLC login script..."
python login_openplc.py

echo "[✔] Done."
