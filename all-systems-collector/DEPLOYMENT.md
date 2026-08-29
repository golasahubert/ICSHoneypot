# Deployment Guide: 24/7 PLC Collector with systemd

Production-ready deployment instructions for continuous Modbus data collection on 4 systems with hourly uploads to ingest server.

## Quick Summary

- **Collector**: runs continuously (24/7) via systemd service
- **Rotation**: automatic hourly rotation of log files
- **Upload**: hourly push to ingest server via rsync+SSH (encrypted, with retry)
- **Security**: SSH keys, restricted permissions, no exposed ports

---

## Prerequisites

- Linux host (Ubuntu 20.04+, CentOS 7+, Debian 10+)
- Python 3.7+
- SSH access to ingest server (or remote storage)
- sudo privileges to install systemd services

## Installation Steps

### 1. Prepare Environment

```bash
# Create collector user (non-privileged)
sudo useradd -r -s /bin/bash -m -d /home/plc-collector plc-collector

# Create log directory
sudo mkdir -p /var/log/plc-collector
sudo mkdir -p /var/log/plc-collector/archive
sudo chown plc-collector:plc-collector /var/log/plc-collector
sudo chmod 750 /var/log/plc-collector

# Create collector installation directory
sudo mkdir -p /opt/plc-collector
sudo chown plc-collector:plc-collector /opt/plc-collector
```

### 2. Install Collector Code

```bash
# Copy collector files to /opt/plc-collector
sudo cp final_collector.py config.yaml requirements.txt /opt/plc-collector/
sudo cp uploader.sh /opt/plc-collector/
sudo chmod +x /opt/plc-collector/uploader.sh

# Set ownership
sudo chown -R plc-collector:plc-collector /opt/plc-collector
sudo chmod 750 /opt/plc-collector
sudo chmod 640 /opt/plc-collector/config.yaml  # Config should not be world-readable
```

### 3. Create Python Virtual Environment

```bash
# Create venv as plc-collector user
sudo -u plc-collector python3 -m venv /opt/plc-collector/venv

# Install dependencies
sudo -u plc-collector /opt/plc-collector/venv/bin/pip install -r /opt/plc-collector/requirements.txt
```

### 4. Configure for Your Environment

Edit `/opt/plc-collector/config.yaml`:

```bash
sudo -u plc-collector nano /opt/plc-collector/config.yaml
```

**Key settings for 24/7**:

```yaml
runtime:
  mode: "continuous"        # IMPORTANT: continuous, not duration
  # no duration_seconds needed

polling:
  interval_ms: 1000         # 1 Hz (adjust as needed)

output:
  dir: "/var/log/plc-collector"  # systemd service writes here
  format: "jsonl"
  ack_url: ""               # leave empty unless using webhook
```

### 5. Generate SSH Keys for Secure Upload

```bash
# Generate ED25519 key (modern, secure)
sudo -u plc-collector ssh-keygen -t ed25519 \
    -f /home/plc-collector/.ssh/collector_key \
    -N ""  # no passphrase

# Set permissions
sudo chmod 600 /home/plc-collector/.ssh/collector_key
sudo chmod 644 /home/plc-collector/.ssh/collector_key.pub
```

### 6. Configure Remote Ingest Server

On the **ingest server** (where logs are uploaded to):

```bash
# Create collector user (or use existing restricted account)
sudo useradd -r -s /bin/rbash -d /var/ingest/collector collector

# Create log directory
sudo mkdir -p /data/plc-logs
sudo chown collector:collector /data/plc-logs
sudo chmod 750 /data/plc-logs

# Add public key to authorized_keys with restrictions
# (First, get the public key from /home/plc-collector/.ssh/collector_key.pub)
echo 'command="rsync --server -avzR --partial .",no-pty,no-agent-forwarding,no-port-forwarding ssh-ed25519 AAAAC3Nz...' | \
    sudo tee -a /var/ingest/collector/.ssh/authorized_keys

# Lock down SSH for this key (no shell, rsync only)
sudo chmod 600 /var/ingest/collector/.ssh/authorized_keys
```

### 7. Update Uploader Script Configuration

Edit `/opt/plc-collector/uploader.sh` and update these lines:

```bash
REMOTE_HOST="192.168.1.100"           # or your ingest server hostname
REMOTE_USER="collector"
REMOTE_PATH="/data/plc-logs"
SSH_KEY="/home/plc-collector/.ssh/collector_key"
RETENTION_DAYS=7
```

### 8. Install systemd Service Files

```bash
# Copy service files
sudo cp collector.service /etc/systemd/system/
sudo cp collector-upload.timer /etc/systemd/system/
sudo cp collector-upload.service /etc/systemd/system/

# Set permissions
sudo chmod 644 /etc/systemd/system/collector*.{service,timer}

# Reload systemd configuration
sudo systemctl daemon-reload

# Enable services (auto-start on reboot)
sudo systemctl enable collector.service
sudo systemctl enable collector-upload.timer

# Start services
sudo systemctl start collector.service
sudo systemctl start collector-upload.timer
```

### 9. Test the Setup

```bash
# Check service status
systemctl status collector
systemctl list-timers --all | grep collector-upload

# View logs
journalctl -u collector -f

# Tail uploader logs (after ~1 hour, or trigger manually)
sudo systemctl start collector-upload.service
journalctl -u collector-upload.service -f
```

---

## Monitoring

### Check Collector Health

```bash
# Service status
systemctl status collector

# Recent logs
journalctl -u collector -n 50

# Watch real-time logs
journalctl -u collector -f

# Check if writing files
ls -lh /var/log/plc-collector/
```

### Check Upload Health

```bash
# Timer status and last run
systemctl list-timers collector-upload.timer

# Upload logs
journalctl -u collector-upload.service -n 50

# Check archived files
ls -lh /var/log/plc-collector/archive/

# Check remote server
ssh collector@ingest-server ls -lh /data/plc-logs/
```

### Alert Setup (Optional)

Create a simple health check script (e.g., `/usr/local/bin/plc-collector-health.sh`):

```bash
#!/bin/bash
# Alert if no new log files in 2 hours
LOGDIR="/var/log/plc-collector"
LAST_MODIFIED=$(find "$LOGDIR" -maxdepth 1 -name "*.jsonl*" -type f -printf '%T@\n' | sort -n | tail -1)
NOW=$(date +%s)
AGE=$((NOW - LAST_MODIFIED))
ALERT_THRESHOLD=$((2 * 3600))  # 2 hours

if [[ $AGE -gt $ALERT_THRESHOLD ]]; then
    echo "ALERT: No new collector data in 2 hours"
    systemctl status collector
    exit 1
fi
exit 0
```

Add to crontab:

```bash
# Check health every 30 minutes
*/30 * * * * /usr/local/bin/plc-collector-health.sh || mail -s "PLC Collector ALERT" admin@example.com
```

---

## Common Issues & Solutions

### Issue: Service won't start
```bash
journalctl -u collector -n 100
# Check: config.yaml exists, Python can import modules, permissions OK
sudo -u plc-collector /opt/plc-collector/venv/bin/python -c "import yaml; print('OK')"
```

### Issue: Logs not appearing
```bash
# Check collector is writing
ls -lh /var/log/plc-collector/
# Check permissions
sudo -u plc-collector test -w /var/log/plc-collector && echo "writable"
```

### Issue: Upload fails (SSH)
```bash
# Test SSH connection manually
sudo -u plc-collector ssh -i /home/plc-collector/.ssh/collector_key \
    collector@ingest-server ls /data/plc-logs/
# Check key permissions
stat /home/plc-collector/.ssh/collector_key
```

### Issue: Disk space growing
```bash
# Check local logs size
du -sh /var/log/plc-collector/
# Check retention policy in uploader.sh
# Adjust RETENTION_DAYS if needed
```

---

## Security Checklist

- [x] Collector runs as non-root user (plc-collector)
- [x] SSH key is ED25519 (modern)
- [x] SSH key has 600 permissions (no passphrase needed)
- [x] Remote SSH key restricted: `command="rsync --server"`, `no-pty`, etc.
- [x] Config file readable only by plc-collector (640)
- [x] Log directory writable only by plc-collector (750)
- [x] Firewall: only outbound SSH (port 22) allowed
- [x] Modbus ports bound to localhost only (127.0.0.1, no 0.0.0.0)
- [x] systemd service has memory/CPU limits

---

## Sizing & Performance

### Disk Usage Estimate

Per PLC at 1 Hz:
- 1 snapshot/second = 86,400 snapshots/day
- ~250 bytes per snapshot (JSON) = ~21.6 MB/day per PLC
- 4 PLCs = ~86.4 MB/day

Local retention (7 days):
- 4 PLCs × 86.4 MB = ~604 MB/week

Remote retention (1 year):
- 4 PLCs × 86.4 MB × 365 = ~126 GB/year

**Recommendation**: 1 TB drive for ingest server (years of data).

### Network Bandwidth

Upload (rsync compression ~30%):
- 86.4 MB/day × 30% = ~26 MB/day outbound
- Negligible impact on most networks

---

## Updating & Maintenance

### Update Collector Code

```bash
# Pull new version
cd /opt/plc-collector
sudo -u plc-collector git pull origin main

# Install any new dependencies
sudo -u plc-collector /opt/plc-collector/venv/bin/pip install -r requirements.txt

# Restart
sudo systemctl restart collector
```

### Backup Logs

```bash
# Manual backup to external storage
rsync -avz /var/log/plc-collector/archive/ backup@nas:/backups/plc-logs/

# Or use tar
tar czf plc-logs-backup-$(date +%Y%m%d).tar.gz /var/log/plc-collector/archive/
```

### Rotate Ingest Server Retention

```bash
# On ingest server: keep only 1 year of data
find /data/plc-logs -name "*.jsonl.gz" -mtime +365 -delete

# Archive to cold storage (S3, tape, etc.)
aws s3 cp s3://... s3://archive/ ...
```

---

## Advanced: Multiple Collectors

If you have 4 separate hosts (Host1, Host2, Host3, Host4):

**Each host gets**:
- `/opt/plc-collector/` with its own config.yaml (different PLC addresses)
- Same systemd service files
- Same SSH key (or different keys with restricted remote accounts)

**Ingest server**:
- `/data/plc-logs/host1/`, `/data/plc-logs/host2/`, etc.
- Or flat directory with prefixed filenames (e.g., `host1_20260829_14.jsonl.gz`)

Adjust uploader script or use per-host script versions.

---

## Files Included

- `final_collector.py` — main collector (2500 lines)
- `config.yaml` — configuration (edit per host)
- `requirements.txt` — Python dependencies
- `collector.service` — systemd service (continuous)
- `collector-upload.timer` — triggers hourly upload
- `collector-upload.service` — upload job (rsync)
- `uploader.sh` — rsync wrapper with retry logic
- `README.md` — full feature documentation
- `DEPLOYMENT.md` — this guide

---

## Support & Issues

1. Check service logs: `journalctl -u collector -f`
2. Test config syntax: `python -m yaml /opt/plc-collector/config.yaml`
3. Test Modbus connection: `python -c "from pymodbus.client.sync import ..."`
4. Test SSH: `ssh -i ~/.ssh/collector_key collector@ingest-server`

For bugs or questions, refer to README.md or raise an issue.
