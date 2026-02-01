#!/bin/bash

set -e

# Step 1: Create virtual environment if it doesn't exist
if [ ! -d "venv" ]; then
    echo "[+] Creating virtual environment..."
    python3 -m venv venv
fi



# Step 2: Install dependencies for playwright
sudo apt install -y python3-venv libnss3 libatk1.0-0 libatk-bridge2.0-0 libcups2 \
libxkbcommon0 libpango-1.0-0 libgbm1 libasound2 libxshmfence1 libdrm2 \
libxcomposite1 libxrandr2 libxi6 fonts-liberation

# Step 2: Activate virtual environment
echo "[+] Activating virtual environment..."
source venv/bin/activate

# Step 3: Upgrade pip and install dependencies
echo "[+] Installing Playwright..."
pip install --upgrade pip
pip install playwright

# Step 4: Install Playwright browsers
playwright install
playwright install-deps

# Step 5: Run the Python automation script
echo "[+] Running SCADA-LTS login script..."
python login_scada.py

# Step 6: Run the Python automation script
echo "[+] Running OPENPLC login script..."
python login_openplc.py

echo "[✔] Done."
