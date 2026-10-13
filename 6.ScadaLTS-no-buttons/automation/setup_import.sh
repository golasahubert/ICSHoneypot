#!/bin/bash
# Imports the HMI project into Scada-LTS and saves the OpenPLC settings.
# Playwright and Chromium are installed by build_system.sh; run as the same
# (non-root) user so the browser in ~/.cache/ms-playwright is found.

set -e
cd "$(dirname "$0")"

if [ ! -x "venv/bin/python" ]; then
    echo "[X] venv not found, run build_system.sh first."
    exit 1
fi

echo "[+] Running SCADA-LTS login script..."
venv/bin/python login_scada.py

echo "[+] Running OPENPLC login script..."
venv/bin/python login_openplc.py

echo "[✔] Done."
