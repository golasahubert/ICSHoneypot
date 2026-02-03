#!/bin/bash
# Script to collect the daily log on each VPS

# start ssh agent and add the private key
eval "$(ssh-agent -s)"
ssh-add /home/denispi/.ssh/deploys

# name of the directory to save the files
BASE_DIR="/home/denispi/data-collection/hmi-deploy-logs"    

# VPS array: "VPS_name user@IP_VPS log_Directory"
VPS_LIST=(
    "custom-hmi singapore-001-DC2 /var/log/tcpdump"
    #other VPS
)

for VPS in "${VPS_LIST[@]}"; do
    NAME=$(echo $VPS | awk '{print $1}')
    USER_HOST=$(echo $VPS | awk '{print $2}')
    REMOTE_DIR=$(echo $VPS | awk '{print $3}')

    LOCAL_DIR="$BASE_DIR/$NAME/"
    mkdir -p "$LOCAL_DIR"
    rsync -avz --partial "$USER_HOST:$REMOTE_DIR/" "$LOCAL_DIR/"

done