#!/bin/bash
LOG_DIR="/var/log/tcpdump"
INTERFACE_NAME="ens3"

find "$LOG_DIR" -name "${INTERFACE_NAME}-*.pcap" -type f -mtime +7 -exec rm -f {} \;