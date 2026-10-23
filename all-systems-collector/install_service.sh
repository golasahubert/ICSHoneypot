#!/usr/bin/env bash
set -euo pipefail

# install_service.sh - install the collector as a systemd service (plc-collector)
# that runs continuously and is restarted automatically (also after reboot).
# Usage: sudo bash install_service.sh [config file]   (default: config.yaml,
#        on server 6 use: sudo bash install_service.sh 6.config.yaml)

if [ "$(id -u)" -ne 0 ]; then
  echo "Error: run as root (sudo bash install_service.sh)" >&2
  exit 1
fi

cd "$(dirname "${BASH_SOURCE[0]}")"
DIR="$(pwd)"
VENV_DIR="$DIR/.venv"
UNIT_FILE="/etc/systemd/system/plc-collector.service"
CONFIG="$DIR/${1:-config.yaml}"

if [ ! -f "$CONFIG" ]; then
  echo "Error: config file not found: $CONFIG" >&2
  exit 1
fi

# Create venv and install requirements once, so restarts don't hit the network
if [ ! -d "$VENV_DIR" ]; then
  echo "Creating virtual environment in $VENV_DIR..."
  python3 -m venv "$VENV_DIR"
fi
"$VENV_DIR/bin/pip" install --upgrade pip >/dev/null
"$VENV_DIR/bin/pip" install -r requirements.txt

echo "Writing $UNIT_FILE..."
cat > "$UNIT_FILE" <<EOF
[Unit]
Description=PLC Modbus data collector
After=network-online.target docker.service
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=$DIR
ExecStart=$VENV_DIR/bin/python $DIR/final_collector.py --config $CONFIG
Restart=always
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable plc-collector.service
# restart (not just start) so re-running the installer picks up new code/config
systemctl restart plc-collector.service

echo "Done. Check status with: systemctl status plc-collector"
echo "Remember to remove the old cron entry for final_collector.py (crontab -e)."
