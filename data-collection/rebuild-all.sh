#!/bin/bash
# Runs build_system.sh on every VPS over SSH (in parallel) and prints a summary.
#
# Usage:
#   ./rebuild-all.sh                              # all servers
#   ./rebuild-all.sh singapore-002 singapore-005  # only the listed hosts
#   ./rebuild-all.sh --capture-only [hosts...]    # only git pull + pcap capture, no rebuild
#
# On each server: git pull of origin/main, install/verify the pcap capture
# (data-collection/install_capture.sh), build_system.sh, container check.
# At the end check-logs.sh verifies that pcaps and CSVs are being written.
#
# Hosts are aliases from ~/.ssh/config. The sudo password is read from the
# indented comment line inside each Host block ("  # <password>") and sent
# to the server over SSH stdin (never on the command line).

# VPS array: "ssh_host remote_variant_dir"
# Recall: no "," at the end of each line
VPS_LIST=(
    "singapore-001  ~/ICSHoneypot/1.Custom-HMI"
    "singapore-002  ~/ICSHoneypot/2.scadaBR"
    "singapore-003  ~/ICSHoneypot/3.scadaBR-without-buttons"
    "singapore-004  ~/ICSHoneypot/4.ScadaLTSv2.7.4"
    "singapore-005  ~/ICSHoneypot/5.NewScada"
    "singapore-006  ~/ICSHoneypot/6.ScadaLTS-no-buttons"
)

MODE="build"
if [ "${1:-}" = "--capture-only" ]; then
    MODE="capture-only"
    shift
fi

if [ "$(id -u)" -eq 0 ]; then
    echo "Run without sudo: ./rebuild-all.sh (it needs your ~/.ssh/config, sudo is used on the servers)"
    exit 1
fi

SSH_CONFIG="$HOME/.ssh/config"
LOG_DIR="$HOME/data-collection/rebuild-logs/$(date +%Y%m%d-%H%M%S)"
SSH_OPTS=(-o BatchMode=yes -o ConnectTimeout=20 -o ServerAliveInterval=30 -o ServerAliveCountMax=10)

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

mkdir -p "$LOG_DIR"

# Print the first indented "# ..." line of the given Host block, without "#" and spaces
sudo_password() {
    awk -v host="$1" '
        /^Host[[:space:]]/ { in_block = ($2 == host); next }
        in_block && /^[[:space:]]+#/ {
            sub(/^[[:space:]]+#[[:space:]]*/, ""); sub(/[[:space:]]+$/, "")
            print; exit
        }' "$SSH_CONFIG"
}

# Remote part. stdin: first line = sudo password. $1 = variant directory, $2 = build|capture-only.
# Exit codes: 10 = wrong sudo password, 11 = directory missing,
#             12 = build_system.sh failed, 13 = containers not all running,
#             14 = git pull failed (nothing was rebuilt),
#             15 = build OK but the pcap capture is not running (install_capture.sh failed)
REMOTE_SCRIPT='
IFS= read -r PW
DIR="$1"
MODE="$2"
printf "%s\n" "$PW" | sudo -S -p "" -v 2>/dev/null || { echo "[rebuild-all] wrong sudo password"; exit 10; }
cd "$DIR" 2>/dev/null || { echo "[rebuild-all] directory $DIR not found"; exit 11; }
# update the repo to origin/main before building (as the normal user, who owns the clone)
REPO=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "[rebuild-all] $DIR is not in a git repository"; exit 14; }
echo "[rebuild-all] git: before pull $(git -C "$REPO" log -1 --format="%h %s")"
if [ -n "$(git -C "$REPO" status --porcelain --untracked-files=no)" ]; then
    # keep local edits recoverable (git stash list) instead of discarding them
    echo "[rebuild-all] git: stashing local changes:"
    git -C "$REPO" status --short --untracked-files=no
    git -C "$REPO" stash push -m "rebuild-all $(date +%F_%T)" || { echo "[rebuild-all] git stash failed"; exit 14; }
fi
git -C "$REPO" checkout -q main && GIT_TERMINAL_PROMPT=0 git -C "$REPO" pull -q --ff-only origin main \
    || { echo "[rebuild-all] git pull failed"; exit 14; }
echo "[rebuild-all] git: now at $(git -C "$REPO" log -1 --format="%h %s")"
# pcap capture first, so it runs even if the build fails (does not restart a running, unchanged capture)
printf "%s\n" "$PW" | sudo -S -p "" bash "$REPO/data-collection/install_capture.sh"
CAPTURE_RC=$?
if [ "$MODE" = "capture-only" ]; then
    [ "$CAPTURE_RC" -eq 0 ] && exit 0 || exit 15
fi
# build and check in one root session (sudo does not cache the password between calls here)
printf "%s\n" "$PW" | sudo -S -p "" env DEBIAN_FRONTEND=noninteractive bash -c "
    bash build_system.sh < /dev/null || exit 12
    sleep 20
    echo \"[rebuild-all] container status:\"
    docker-compose ps
    EXPECTED=\$(docker-compose config --services | wc -l)
    RUNNING=\$(docker-compose ps --services --filter status=running | wc -l)
    echo \"[rebuild-all] running \$RUNNING/\$EXPECTED services\"
    [ \"\$EXPECTED\" -gt 0 ] && [ \"\$RUNNING\" -eq \"\$EXPECTED\" ] || exit 13
"
BUILD_RC=$?
[ "$BUILD_RC" -ne 0 ] && exit "$BUILD_RC"
[ "$CAPTURE_RC" -ne 0 ] && exit 15
exit 0
'

run_one() {
    local host="$1" dir="$2" pw="$3"
    local log="$LOG_DIR/$host.log"
    local start=$SECONDS
    ssh "${SSH_OPTS[@]}" "$host" "bash -c $(printf %q "$REMOTE_SCRIPT") rebuild-all $dir $MODE" \
        <<< "$pw" > "$log" 2>&1
    local rc=$?
    echo "$rc $((SECONDS - start))" > "$LOG_DIR/$host.rc"
}

declare -a HOSTS=()
for VPS in "${VPS_LIST[@]}"; do
    read -r HOST DIR <<< "$VPS"
    # optional filter by host from command line
    if [ $# -gt 0 ] && [[ ! " $* " =~ " $HOST " ]]; then
        continue
    fi
    PW="$(sudo_password "$HOST")"
    if [ -z "$PW" ]; then
        echo -e "${YELLOW}[!] $HOST: no sudo password comment in $SSH_CONFIG, skipping${NC}"
        continue
    fi
    echo "[+] $HOST: starting $MODE in $DIR, log -> $LOG_DIR/$HOST.log"
    run_one "$HOST" "$DIR" "$PW" &
    HOSTS+=("$HOST")
done
unset PW

[ ${#HOSTS[@]} -eq 0 ] && { echo "Nothing to do."; exit 1; }

echo "[+] Waiting for ${#HOSTS[@]} build(s) to finish (follow with: tail -f $LOG_DIR/*.log)"
wait

# --- SUMMARY ---
echo
echo "================ SUMMARY ================"
FAILED=0
for HOST in "${HOSTS[@]}"; do
    read -r RC TIME < "$LOG_DIR/$HOST.rc"
    case "$RC" in
        0)   MSG="OK ($MODE)" ;;
        10)  MSG="wrong sudo password" ;;
        11)  MSG="remote directory not found" ;;
        12)  MSG="build_system.sh failed" ;;
        13)  MSG="build finished but not all containers are running" ;;
        14)  MSG="git pull failed, nothing rebuilt" ;;
        15)  MSG="pcap capture is not running (install_capture.sh failed)" ;;
        255) MSG="SSH connection failed / dropped" ;;
        *)   MSG="unknown error (exit $RC)" ;;
    esac
    if [ "$RC" -eq 0 ]; then
        printf "${GREEN}%-16s %-50s %5ss${NC}\n" "$HOST" "$MSG" "$TIME"
    else
        FAILED=$((FAILED + 1))
        printf "${RED}%-16s %-50s %5ss${NC}\n" "$HOST" "$MSG" "$TIME"
        echo "    last lines of $LOG_DIR/$HOST.log:"
        tail -n 5 "$LOG_DIR/$HOST.log" | sed 's/^/      /'
    fi
done
echo "========================================="
echo "Logs: $LOG_DIR"

# --- ARE THE SERVERS WRITING LOGS? ---
echo
"$(dirname "$0")/check-logs.sh" "${HOSTS[@]}" | tee "$LOG_DIR/log-check.txt"
LOG_FAILED=${PIPESTATUS[0]}
exit $((FAILED + LOG_FAILED))
