#!/usr/bin/env bash
set -uo pipefail

# install_capture.sh - install the pcap capture (capture.sh + capture.service),
# make sure it runs (also after reboot) and verify that pcaps are being written.
# Usage: sudo bash install_capture.sh
# Safe to re-run: the service is restarted only if capture.sh/capture.service
# changed or the service is not running, so a running capture is not interrupted.
# Exit code: 0 = capture running and writing, 1 = problem (details printed).

if [ "$(id -u)" -ne 0 ]; then
  echo "Error: run as root (sudo bash install_capture.sh)" >&2
  exit 1
fi

cd "$(dirname "${BASH_SOURCE[0]}")"
SCRIPT_DST="/root/capture.sh"
UNIT_DST="/etc/systemd/system/capture.service"
LOG_DIR="/var/log/tcpdump"
MAX_AGE_MIN=15        # an already running capture must have written within this time
DISK_WARN_PCT=85

if ! command -v tcpdump >/dev/null; then
  echo "[capture] installing tcpdump..."
  DEBIAN_FRONTEND=noninteractive apt-get install -y tcpdump >/dev/null || { echo "[capture] FAIL: apt-get install tcpdump failed"; exit 1; }
fi

CHANGED=0
if ! cmp -s capture.sh "$SCRIPT_DST"; then
  install -m 0755 capture.sh "$SCRIPT_DST"
  echo "[capture] installed $SCRIPT_DST"
  CHANGED=1
fi
if ! cmp -s capture.service "$UNIT_DST"; then
  install -m 0644 capture.service "$UNIT_DST"
  echo "[capture] installed $UNIT_DST"
  CHANGED=1
fi
systemctl daemon-reload
systemctl enable -q capture.service

START=$(date +%s)
RESTARTED=0
if [ "$CHANGED" -eq 1 ] || ! systemctl is-active -q capture.service; then
  echo "[capture] (re)starting capture.service"
  systemctl restart capture.service
  RESTARTED=1
fi

# Verify: service active and the newest pcap written by the current tcpdump
# (after a restart: modified after START; otherwise: at most MAX_AGE_MIN old).
OK=0
for _ in $(seq 1 30); do
  sleep 2
  systemctl is-active -q capture.service || continue
  NEWEST=$(find "$LOG_DIR" -type f -name "*.pcap" -printf "%T@ %s %p\n" 2>/dev/null | sort -n | tail -1)
  [ -z "$NEWEST" ] && continue
  read -r MTIME SIZE FILE <<< "$NEWEST"
  MTIME=${MTIME%.*}
  if [ "$RESTARTED" -eq 1 ]; then
    [ "$MTIME" -ge "$START" ] && { OK=1; break; }
  else
    [ $(( $(date +%s) - MTIME )) -le $((MAX_AGE_MIN * 60)) ] && { OK=1; break; }
  fi
done

if [ "$OK" -eq 1 ]; then
  echo "[capture] OK: capture.service active, writing $FILE ($SIZE bytes)"
else
  echo "[capture] FAIL: capture.service is not writing pcaps"
  systemctl status capture.service --no-pager -n 0 2>&1 | sed 's/^/    /'
  journalctl -u capture.service -n 15 --no-pager 2>&1 | sed 's/^/    /'
  exit 1
fi

DISK_PCT=$(df --output=pcent / | tail -1 | tr -dc 0-9)
if [ "$DISK_PCT" -ge "$DISK_WARN_PCT" ]; then
  echo "[capture] WARN: disk / is ${DISK_PCT}% full, pcaps will fill it (free space or pull and delete old pcaps)"
fi
exit 0
