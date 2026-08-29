#!/bin/bash
# ============================================================================
# PLC COLLECTOR - SECURE LOG UPLOADER
# ============================================================================
# Purpose: Upload completed hourly JSONL files to remote ingest server via rsync
# Called by: systemd timer (collector-upload.timer)
# 
# Behavior:
#  1. Rotate current log file (move to hourly file with timestamp)
#  2. Gzip compress the completed hourly file
#  3. rsync to remote ingest server via SSH
#  4. Remove local file after successful upload (--remove-source-files)
#  5. Keep only last 7 days of gzipped logs locally (archive/retention)
#
# Configuration:
#  - REMOTE_HOST: ingest server hostname
#  - REMOTE_USER: user account on ingest server (should be read-only)
#  - REMOTE_PATH: where to upload files
#  - SSH_KEY: path to SSH private key for authentication
#  - LOG_DIR: local log directory
#  - RETENTION_DAYS: how long to keep local gzipped copies
# ============================================================================

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================
REMOTE_HOST="${REMOTE_HOST:-ingest-server}"          # Change this to your ingest server
REMOTE_USER="${REMOTE_USER:-collector}"              # Change this to your remote user
REMOTE_PATH="${REMOTE_PATH:-/data/plc-logs}"         # Change this to your remote path
SSH_KEY="${SSH_KEY:-/home/plc-collector/.ssh/collector_key}"
LOG_DIR="${LOG_DIR:-/var/log/plc-collector}"
RETENTION_DAYS=7

ARCHIVE_DIR="${LOG_DIR}/archive"
SCRIPT_NAME="$(basename "$0")"
HOSTNAME_SHORT="$(hostname -s)"

# ============================================================================
# LOGGING
# ============================================================================

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [${SCRIPT_NAME}] $*" >&2
}

log_error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [${SCRIPT_NAME}] ERROR: $*" >&2
}

# ============================================================================
# PRECONDITIONS
# ============================================================================

log "Starting hourly log upload..."

# Check if log directory exists
if [[ ! -d "${LOG_DIR}" ]]; then
    log_error "Log directory does not exist: ${LOG_DIR}"
    exit 1
fi

# Check if SSH key exists
if [[ ! -f "${SSH_KEY}" ]]; then
    log_error "SSH key not found: ${SSH_KEY}"
    exit 1
fi

# Verify SSH key permissions (must be 600)
SSH_PERMS=$(stat -c '%a' "${SSH_KEY}" 2>/dev/null || echo "???")
if [[ "${SSH_PERMS}" != "600" ]]; then
    log_error "SSH key has wrong permissions: ${SSH_PERMS} (must be 600)"
    exit 1
fi

# ============================================================================
# ROTATE AND COMPRESS
# ============================================================================

# Find all uncompressed JSONL files (current collector logs)
# These should be writing to collector_data.jsonl
# We'll rotate them with a timestamp

if [[ -f "${LOG_DIR}/collector_data.jsonl" ]]; then
    TIMESTAMP=$(date +'%Y%m%d_%H%M%S')
    ROTATED_FILE="${LOG_DIR}/collector_data_${TIMESTAMP}.jsonl"
    
    log "Rotating current log file..."
    mv "${LOG_DIR}/collector_data.jsonl" "${ROTATED_FILE}"
    
    # Restart collector service to create new log file
    # (skip if not running as root/sudo)
    if [[ $EUID -eq 0 ]]; then
        systemctl reload-or-restart collector 2>/dev/null || true
    fi
    
    # Gzip the rotated file
    log "Compressing ${ROTATED_FILE}..."
    gzip -9 "${ROTATED_FILE}"
    COMPRESSED_FILE="${ROTATED_FILE}.gz"
    
    log "Compressed to: ${COMPRESSED_FILE}"
else
    log "No current log file found; skipping rotation"
    COMPRESSED_FILE=""
fi

# ============================================================================
# FIND FILES TO UPLOAD
# ============================================================================

# Look for all .gz files (compressed, ready to upload)
FILES_TO_UPLOAD=()
while IFS= read -r -d '' file; do
    FILES_TO_UPLOAD+=("$file")
done < <(find "${LOG_DIR}" -maxdepth 1 -name "*.jsonl.gz" -type f -print0)

if [[ ${#FILES_TO_UPLOAD[@]} -eq 0 ]]; then
    log "No files to upload"
    exit 0
fi

log "Found ${#FILES_TO_UPLOAD[@]} file(s) to upload"

# ============================================================================
# UPLOAD VIA RSYNC OVER SSH
# ============================================================================

log "Uploading to ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}..."

# rsync options:
#   -a, --archive        = recursive, preserve permissions/times/etc
#   -v, --verbose        = verbose output
#   -z, --compress       = compress during transfer (already gzipped, but doesn't hurt)
#   --partial            = keep partially transferred files (for resume)
#   --remove-source-files = delete local files after successful upload
#   -e ssh               = use SSH with custom key

UPLOAD_SUCCESS=0

rsync -avz \
    --partial \
    --remove-source-files \
    -e "ssh -i ${SSH_KEY} -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/home/plc-collector/.ssh/known_hosts" \
    "${LOG_DIR}"/*.jsonl.gz \
    "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}/" \
    2>&1 | while IFS= read -r line; do
        log "rsync: $line"
    done || UPLOAD_SUCCESS=$?

if [[ ${UPLOAD_SUCCESS} -ne 0 ]]; then
    log_error "rsync failed with exit code ${UPLOAD_SUCCESS}"
    # Don't exit here; we want to continue with cleanup/retention
fi

# ============================================================================
# LOCAL RETENTION (ARCHIVE)
# ============================================================================

log "Applying retention policy (keep ${RETENTION_DAYS} days)..."

# Create archive directory if it doesn't exist
mkdir -p "${ARCHIVE_DIR}"

# Move successfully uploaded files to archive (optional, for local backup)
# This is redundant if rsync --remove-source-files works, but good for debugging
find "${LOG_DIR}" -maxdepth 1 -name "*.jsonl.gz" -type f -print0 | \
    while IFS= read -r -d '' file; do
        # If file still exists locally after upload attempt, move to archive
        if [[ -f "$file" ]]; then
            log "Moving $file to archive..."
            mv "$file" "${ARCHIVE_DIR}/"
        fi
    done

# Delete archived files older than RETENTION_DAYS
log "Deleting archived files older than ${RETENTION_DAYS} days..."
find "${ARCHIVE_DIR}" -maxdepth 1 -name "*.jsonl.gz" -type f \
    -mtime "+${RETENTION_DAYS}" \
    -exec rm -v {} \; \
    2>&1 | while IFS= read -r line; do
        log "Delete: $line"
    done || true

# ============================================================================
# SUMMARY
# ============================================================================

REMAINING=$(find "${LOG_DIR}" -maxdepth 1 -name "*.jsonl.gz" -type f | wc -l)
ARCHIVED=$(find "${ARCHIVE_DIR}" -maxdepth 1 -name "*.jsonl.gz" -type f | wc -l)

log "Upload complete."
log "  Remaining local files: ${REMAINING}"
log "  Archived files: ${ARCHIVED}"

exit 0
