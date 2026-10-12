# Updates

Changelog of changes to the project. Newest entries on top.

## 2026-10-12

### automation: setup_import.sh works on Ubuntu 20.04 and 24.04

- In `*/automation/setup_import.sh` (variants 2–6) the ALSA library for Playwright is now picked automatically: `libasound2t64` if apt knows it (Ubuntu 24.04+), otherwise `libasound2` (Ubuntu 20.04/22.04). Before this, `apt install libasound2` failed on 24.04 because it is only a virtual package there.
- This only affects the host-side setup script. Containers, PLCs and HMIs are untouched, so nothing changes from an attacker's point of view.

### all-systems-collector: persistent Modbus connections

- The collector now keeps **one open TCP connection per PLC** and reuses it for every poll. Previously it opened and closed a new connection to each PLC every second (~260k connections/day).
  - Behaves like a real SCADA poller instead of a scanner-like connect/disconnect pattern.
  - Avoids flooding the OpenPLC "Runtime Logs" (visible on the exposed OpenPLC web pages) with "client accepted / closed" entries.
- If a read fails or the PLC goes down, the connection is closed, the row gets `_status = offline`, and the collector reconnects automatically on the next poll. Each (re)connect is logged once at INFO level.
- Only the collector changed. PLCs, simulator, HMIs and docker-compose files are untouched, so nothing changes from an attacker's point of view.

### all-systems-collector: quieter logs

- The per-row message `Appended snapshot to ...` is now DEBUG instead of INFO (it was 86,400 lines/day in `journalctl` and `collector.log`). Use `--verbose` to see it again.

### all-systems-collector: CSV files every 6 hours

- In continuous mode a new CSV file is started every 6 hours instead of once a day, so each day has 4 files:
  ```
  /var/log/plc_collector/MM/DD/collector_data_YYYYMMDD_000000.csv   # 00:00-06:00
  /var/log/plc_collector/MM/DD/collector_data_YYYYMMDD_060000.csv   # 06:00-12:00
  /var/log/plc_collector/MM/DD/collector_data_YYYYMMDD_120000.csv   # 12:00-18:00
  /var/log/plc_collector/MM/DD/collector_data_YYYYMMDD_180000.csv   # 18:00-24:00
  ```
- Slots are aligned to the server's local time and files are named after the slot start. A restart within a slot appends to the same file, so a day never has more than 4 files.
- New config option `output.rotate_hours` (default `6`, must divide 24).

### all-systems-collector: config for server 5

- Added `all-systems-collector/5.config.yaml` for `5.NewScada`, where PLC2 Modbus is published on host port `3502` instead of `502`. All other settings match `config.yaml`. Changes to `config.yaml` must also be made in `5.config.yaml`.
- `install_service.sh` now accepts an optional config file (default `config.yaml`) and always restarts the service, so re-running it applies new code/config:
  ```bash
  sudo bash all-systems-collector/install_service.sh                # servers 1-4, 6
  sudo bash all-systems-collector/install_service.sh 5.config.yaml  # server 5
  ```

### Deploying these changes on a running server

```bash
git pull
sudo bash all-systems-collector/install_service.sh                # or 5.config.yaml on server 5
```

Re-running the installer rewrites the service and restarts it with the new code and config, without rebuilding containers. On servers where the service already used the right config, `sudo systemctl restart plc-collector` is enough.
