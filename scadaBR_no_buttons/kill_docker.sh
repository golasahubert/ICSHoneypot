#!/bin/bash

echo "[+] Stopping all running Docker containers..."
running_containers=$(sudo docker ps -q)
if [ -n "$running_containers" ]; then
  sudo docker stop $running_containers
else
  echo "[-] No running containers found."
fi

echo "[+] Removing all custom-defined Docker networks..."
custom_networks=$(sudo docker network ls --filter type=custom -q)
if [ -n "$custom_networks" ]; then
  sudo docker network rm $custom_networks
else
  echo "[-] No custom-defined networks found."
fi

echo "[✓] Cleanup complete."
