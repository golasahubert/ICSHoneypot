#!/usr/bin/env bash
set -euo pipefail

# run.sh - helper to create/activate venv, install requirements and run the collector
# Usage: ./run.sh [--config config.yaml] [--verbose]

# Move to script directory so relative paths (requirements, final_collector.py) work
cd "$(dirname "${BASH_SOURCE[0]}")"

VENV_DIR=".venv"
PYTHON="python3"
REQUIREMENTS_FILE="requirements.txt"
COLLECTOR_SCRIPT="final_collector.py"

# Ensure Python is available
if ! command -v "$PYTHON" >/dev/null 2>&1; then
  echo "Error: $PYTHON not found in PATH. Please install Python 3.6+." >&2
  exit 2
fi

# Create virtual environment if it doesn't exist
if [ ! -d "$VENV_DIR" ]; then
  echo "Creating virtual environment in $VENV_DIR..."
  $PYTHON -m venv "$VENV_DIR"
fi

# Activate virtualenv
# shellcheck disable=SC1091
source "$VENV_DIR/bin/activate"

# Upgrade pip/tools and install requirements if present
echo "Upgrading pip, setuptools, wheel..."
python -m pip install --upgrade pip setuptools wheel >/dev/null

if [ -f "$REQUIREMENTS_FILE" ]; then
  echo "Installing requirements from $REQUIREMENTS_FILE..."
  pip install -r "$REQUIREMENTS_FILE"
else
  echo "No $REQUIREMENTS_FILE found, skipping pip install." 
fi

# Run the collector script with any provided arguments
if [ ! -f "$COLLECTOR_SCRIPT" ]; then
  echo "Error: $COLLECTOR_SCRIPT not found in $(pwd)" >&2
  exit 3
fi

exec python "$COLLECTOR_SCRIPT" "$@"
