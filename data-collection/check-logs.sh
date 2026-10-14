#!/bin/bash
# Checks over SSH that every VPS is still writing its logs and prints a summary.
#
# Usage:
#   ./check-logs.sh                              # all servers
#   ./check-logs.sh singapore-002 singapore-005  # only the listed hosts
#
# Per server it checks:
#   - pcap: capture.service is active and the newest pcap in /var/log/tcpdump
#     was written in the last PCAP_MAX_AGE_MIN minutes
#   - csv:  plc-collector is active and the newest CSV in /var/log/plc_collector
#     was written in the last CSV_MAX_AGE_MIN minutes (the collector appends every second)
#   - disk: usage of / is below DISK_WARN_PCT
# No sudo needed (the log directories are world-readable).
# Exit code = number of servers with at least one FAIL.

HOSTS_ALL=(singapore-001 singapore-002 singapore-003 singapore-004 singapore-005 singapore-006)

PCAP_MAX_AGE_MIN=${PCAP_MAX_AGE_MIN:-15}   # tcpdump flushes its buffer less often on quiet servers
CSV_MAX_AGE_MIN=${CSV_MAX_AGE_MIN:-2}
DISK_WARN_PCT=${DISK_WARN_PCT:-85}

SSH_OPTS=(-o BatchMode=yes -o ConnectTimeout=20)

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

if [ $# -gt 0 ]; then HOSTS=("$@"); else HOSTS=("${HOSTS_ALL[@]}"); fi

# Remote part: prints "key=value" lines, parsed below
REMOTE_SCRIPT='
now=$(date +%s)
newest_age() {  # $1 = directory, $2 = name pattern; prints age in minutes of the newest file, or -1
    local t
    t=$(find "$1" -type f -name "$2" -printf "%T@\n" 2>/dev/null | sort -n | tail -1)
    [ -z "$t" ] && { echo -1; return; }
    echo $(( (now - ${t%.*}) / 60 ))
}
echo "capture_service=$(systemctl is-active capture.service 2>/dev/null)"
echo "pcap_age_min=$(newest_age /var/log/tcpdump "*.pcap")"
echo "collector_service=$(systemctl is-active plc-collector 2>/dev/null)"
echo "csv_age_min=$(newest_age /var/log/plc_collector "*.csv")"
echo "disk_pct=$(df --output=pcent / | tail -1 | tr -dc 0-9)"
echo "disk_avail=$(df -h --output=avail / | tail -1 | tr -d " ")"
echo "commit=$(git -C ~/ICSHoneypot rev-parse --short HEAD 2>/dev/null)"
'

echo "================ LOG CHECK ================"
FAILED=0
for HOST in "${HOSTS[@]}"; do
    OUT=$(timeout 60 ssh "${SSH_OPTS[@]}" "$HOST" "$REMOTE_SCRIPT" 2>/dev/null)
    if [ -z "$OUT" ]; then
        printf "${RED}%-16s FAIL  SSH connection failed${NC}\n" "$HOST"
        FAILED=$((FAILED + 1))
        continue
    fi
    get() { sed -n "s/^$1=//p" <<< "$OUT"; }

    PROBLEMS=()   # FAIL messages
    WARNINGS=()   # WARN messages

    # pcap
    if [ "$(get capture_service)" != "active" ]; then
        PROBLEMS+=("capture.service $(get capture_service)")
    fi
    AGE=$(get pcap_age_min)
    if [ "$AGE" = "-1" ]; then
        PROBLEMS+=("no pcap files in /var/log/tcpdump")
    elif [ "$AGE" -gt "$PCAP_MAX_AGE_MIN" ]; then
        PROBLEMS+=("newest pcap is ${AGE} min old")
    fi

    # csv
    if [ "$(get collector_service)" != "active" ]; then
        PROBLEMS+=("plc-collector $(get collector_service)")
    fi
    AGE=$(get csv_age_min)
    if [ "$AGE" = "-1" ]; then
        PROBLEMS+=("no CSV files in /var/log/plc_collector")
    elif [ "$AGE" -gt "$CSV_MAX_AGE_MIN" ]; then
        PROBLEMS+=("newest CSV is ${AGE} min old")
    fi

    # disk
    if [ "$(get disk_pct)" -ge "$DISK_WARN_PCT" ]; then
        WARNINGS+=("disk $(get disk_pct)% used, $(get disk_avail) free")
    fi

    INFO="commit $(get commit), disk $(get disk_pct)%"
    if [ ${#PROBLEMS[@]} -gt 0 ]; then
        FAILED=$((FAILED + 1))
        printf "${RED}%-16s FAIL  %s${NC}\n" "$HOST" "$INFO"
        for P in "${PROBLEMS[@]}" "${WARNINGS[@]}"; do echo "    - $P"; done
    elif [ ${#WARNINGS[@]} -gt 0 ]; then
        printf "${YELLOW}%-16s WARN  %s${NC}\n" "$HOST" "$INFO"
        for W in "${WARNINGS[@]}"; do echo "    - $W"; done
    else
        printf "${GREEN}%-16s OK    pcap and CSV are being written (%s)${NC}\n" "$HOST" "$INFO"
    fi
done
echo "==========================================="
exit $FAILED
