#!/bin/bash
# Pulls the logs of every VPS to this machine (incremental rsync), then prints a summary.
#
# Usage:
#   ./log-collector.sh                              # all servers
#   ./log-collector.sh singapore-002 singapore-005  # only the listed hosts
#
# Hosts are aliases from ~/.ssh/config (same as rebuild-all.sh). Collected per server:
#   pcap: /var/log/tcpdump/       -> $BASE_DIR/<name>/pcap/
#   csv:  /var/log/plc_collector/ -> $BASE_DIR/<name>/plc_collector/
# Both directories are world-readable on the servers, so no sudo is needed.
# Files are never deleted locally, even if they were deleted on the server.
# Run it daily from cron, e.g.:
#   0 3 * * * /path/to/log-collector.sh >> ~/data-collection/log-collector.log 2>&1

BASE_DIR="${BASE_DIR:-$HOME/data-collection/hmi-deploy-logs}"

# VPS array: "local_name ssh_host"
# Recall: no "," at the end of each line
VPS_LIST=(
    "1.custom-hmi                singapore-001"
    "2.scadabr                   singapore-002"
    "3.scadabr-without-buttons   singapore-003"
    "4.scadalts                  singapore-004"
    "5.newscada                  singapore-005"
    "6.scadalts-no-buttons       singapore-006"
)

# remote_dir:local_subdir
SOURCES=(
    "/var/log/tcpdump:pcap"
    "/var/log/plc_collector:plc_collector"
)

SSH_OPTS="ssh -o BatchMode=yes -o ConnectTimeout=20 -o ServerAliveInterval=30"

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo "[log-collector] $(date '+%F %T') -> $BASE_DIR"
declare -a SUMMARY=()
FAILED=0
for VPS in "${VPS_LIST[@]}"; do
    read -r NAME HOST <<< "$VPS"
    # optional filter by host from command line
    if [ $# -gt 0 ] && [[ ! " $* " =~ " $HOST " ]]; then
        continue
    fi
    for SRC in "${SOURCES[@]}"; do
        REMOTE_DIR="${SRC%%:*}"
        LOCAL_DIR="$BASE_DIR/$NAME/${SRC##*:}"
        mkdir -p "$LOCAL_DIR"
        # --append-verify: pcaps and CSVs only grow, so only the new tail is sent
        STATS=$(rsync -a --partial --append-verify --stats -e "$SSH_OPTS" \
            "$HOST:$REMOTE_DIR/" "$LOCAL_DIR/" 2>&1)
        RC=$?
        NEW=$(sed -n 's/^Number of regular files transferred: //p' <<< "$STATS")
        TOTAL=$(find "$LOCAL_DIR" -type f | wc -l)
        if [ $RC -eq 0 ]; then
            SUMMARY+=("$(printf "${GREEN}%-16s %-14s OK    %4s updated, %5s files locally${NC}" "$HOST" "${SRC##*:}" "${NEW:-0}" "$TOTAL")")
        else
            FAILED=$((FAILED + 1))
            SUMMARY+=("$(printf "${RED}%-16s %-14s FAIL  rsync exit %s: %s${NC}" "$HOST" "${SRC##*:}" "$RC" "$(tail -n 1 <<< "$STATS")")")
        fi
    done
done

echo "================ SUMMARY ================"
printf "%b\n" "${SUMMARY[@]}"
echo "========================================="
exit $FAILED
