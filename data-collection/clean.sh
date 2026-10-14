#!/bin/bash
# Deletes pcaps older than 7 days. NOT in cron on any server (checked 2026-10-14):
# only use it once log-collector.sh has pulled the files.
LOG_DIR="/var/log/tcpdump"

# any interface prefix (ens3-*.pcap on servers 1-5, eth0-*.pcap on server 6)
find "$LOG_DIR" -name "*-*.pcap" -type f -mtime +7 -exec rm -f {} \;
