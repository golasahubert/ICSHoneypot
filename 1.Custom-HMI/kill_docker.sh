#!/bin/bash

echo "[+] Force removing ALL Docker containers (running & stopped)..."

# Get the IDs of all containers (-a = all, -q = only IDs)
all_containers=$(sudo docker ps -aq)

if [ -n "$all_containers" ]; then
  # rm -f (force) kills running containers and removes stopped ones in one step.
  sudo docker rm -f $all_containers
  echo "[✓] All containers have been nuked."
else
  echo "[-] No containers found to remove."
fi

echo "[+] Removing all unused Docker networks..."
# network prune -f is safer and more reliable than filtering custom networks by hand
sudo docker network prune -f > /dev/null 2>&1

echo "[✓] Cleanup complete."
