#!/bin/bash

LOG_DIR="/var/log/tcpdump"
INTERFACE_NAME="ens3"
IP=$(ip addr show "$INTERFACE_NAME" | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
IPv6=$(ip addr show "$INTERFACE_NAME" | grep -oP '(?<=inet6\s)[\da-f:]+')
IPv6=$(echo "$IPv6" | grep -v '^fe80')

# get current month and year
YEAR=$(date +%Y)
MONTH=$(date +%m)

# Create the directory
mkdir -p "$LOG_DIR/${YEAR}/${MONTH}"

# Tcpdump su ens3
tcpdump -i "$INTERFACE_NAME" -s 0 -nn -tttt -G 43200  -w "$LOG_DIR/${YEAR}/${MONTH}/${INTERFACE_NAME}-%Y%m%d%H%M%S.pcap" -Z nobody "(host $IP or host $IPv6)" &

wait