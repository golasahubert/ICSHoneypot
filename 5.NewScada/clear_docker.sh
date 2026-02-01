#!/bin/bash

# Name: docker-cleanup.sh
# Description: Stops and removes all Docker containers (active and inactive).

echo "🛑 Stopping all active containers..."
docker stop $(docker ps -aq)

echo "🗑️ Removing all containers (stopped and active)..."
docker rm $(docker ps -aq)

echo "✅ Cleanup complete. All containers have been removed."