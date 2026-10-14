#!/bin/bash
# Captures all traffic to/from this host's public addresses with tcpdump.
# Run by capture.service (installed as /root/capture.sh by install_capture.sh).
# Usage: capture.sh [interface]   (default: the interface of the default route,
#        ens3 on servers 1-5, eth0 on server 6)

LOG_DIR="/var/log/tcpdump"
INTERFACE_NAME="${1:-$(ip route show default | awk '{print $5; exit}')}"

# Global addresses only (no link-local fe80::). Server 6 has no global IPv6,
# so the filter is built only from the addresses that exist.
IPv4=$(ip -4 addr show dev "$INTERFACE_NAME" scope global | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
IPv6=$(ip -6 addr show dev "$INTERFACE_NAME" scope global | grep -oP '(?<=inet6\s)[\da-f:]+')
FILTER=""
for ADDR in $IPv4 $IPv6; do
    FILTER="${FILTER:+$FILTER or }host $ADDR"
done
if [ -z "$FILTER" ]; then
    echo "capture.sh: no global address on interface '$INTERFACE_NAME'" >&2
    exit 1
fi

# get current month and year
YEAR=$(date +%Y)
MONTH=$(date +%m)

# Create the directory
mkdir -p "$LOG_DIR/${YEAR}/${MONTH}"

echo "capture.sh: tcpdump on $INTERFACE_NAME, filter: ($FILTER)"
# New file every 12 h (-G 43200). -U writes every packet to the file at once,
# so check-logs.sh sees fresh files and nothing is lost on a crash.
exec tcpdump -i "$INTERFACE_NAME" -s 0 -nn -U -G 43200 \
    -w "$LOG_DIR/${YEAR}/${MONTH}/${INTERFACE_NAME}-%Y%m%d%H%M%S.pcap" -Z nobody "($FILTER)"
