# Updates

Changelog of changes to the project. Newest entries on top.

## 2026-10-12

### 5.NewScada: same ScadaLTS as variant 4

- The custom ScadaLTS setup in variant 5 is replaced by a copy of `4.ScadaLTSv2.7.4`. The custom setup had JSP/tag overrides, a custom startup script, a MySQL init dump from a newer ScadaLTS and the `superadmin` import account.
  - Copied from 4: `docker-compose.yml`, `build_system.sh`, and `automation/` (`login_scada.py`, `dataHMI.txt`, `setup_import.sh`, `setup_openplc.sh`, `login_openplc.py`, `requirements.txt`).
  - The only differences left are PLC2 Modbus on host port `3502` (instead of `502`) and the collector being installed with `5.config.yaml`.
- Removed: `5.NewScada/SCADA-LTS/` (custom JSP/tags/assets and `scadalts_backup.sql`), `automation/dataHMI2.txt`, `README.md` and `clear_docker.sh`. They are still in git history.
- Fixes the problems found on the test server with the old setup:
  - The `dataHMI.txt` import never applied. `login_scada.py` closed the browser right after clicking Import, and the import failed on the scripts.
  - The HMI had no connection to PLC3.
  - Point history was never saved, because `PROCEDURE prc_alarms_notify does not exist` (the dump had schema `2.7.7.1` without routines, while the container runs v2.7.4).
- MySQL now uses the named volume `db_storage` (as in 4) instead of `./db_data`. Root-owned leftovers in `5.NewScada/db_data` can be deleted by hand (`sudo rm -rf 5.NewScada/db_data`).
- **Visible to attackers** (HMI look, users, MySQL setup): deploy on server 5 between measurement periods.
- Verified on the test server after a full build:
  - `http://<ip>/` (nginx) and `:8080` serve the HMI.
  - The import created `DATA PLC1/2/3` and the `HMI SYSTEM` view.
  - ScadaLTS holds Modbus connections to all 3 PLCs and stores point history (no more `prc_alarms_notify` errors).
  - The collector writes all 3 PLCs as `connected`.
- `CLAUDE.md`: corrected the SCADA users line, since the import in 4/5 creates only `admin`.

### 5.NewScada: HMI on port 8080 and nginx on port 80

- ScadaLTS is now published on host port `8080` (was `8181`), and a new `nginx` service (`nginx_proxy`, `172.25.0.8`) publishes port `80`. Opening `http://<server-ip>/` redirects to `/Scada-LTS/`, as in variants 2–4 and 6.
- `5.NewScada/nginx.conf` is a copy of the one in variants 4 and 6. `automation/login_scada.py` and `5.NewScada/README.md` now use port `8080`.
- **Visible to attackers** (exposed ports): deploy on server 5 between measurement periods.

### build_system.sh: installs the PLC data collector service

- Every `build_system.sh` (variants 1–6) now ends with `install_service.sh`, so the collector (`plc-collector` systemd service) runs continuously after a build and starts again after reboot. No separate manual step is needed anymore.
- Variants 1–4 and 6 use `all-systems-collector/config.yaml` (PLC2 on host port `502`); `5.NewScada` uses `5.config.yaml` (PLC2 on `3502`). Port mappings were checked against each variant's `docker-compose.yml`.
- Re-running a build restarts the service with the current code and config. The collector's virtualenv (`all-systems-collector/.venv`) is now git-ignored.
- The collector only reads the PLCs locally; nothing changes from an attacker's point of view.

### build_system.sh: faster repeated builds

Rebuilding a variant that was already built once now skips work that was redone every time. The end result (containers, OpenPLC programs, SCADA import) is the same.

- **Docker build cache is kept** (variants 4–6): `kill_docker.sh` ran `docker system prune -f`, which also deleted the Docker build cache, so every build recompiled OpenPLC (`install.sh`) in all PLC images. It now runs `docker container prune -f` instead. Variants 1–3 never pruned the cache.
  - Side effect: dangling images from old builds are no longer removed automatically. Run `docker image prune -f` by hand if disk space gets low.
  - With the cache, the OpenPLC `git clone` layer is reused, so a rebuild keeps the OpenPLC version from the first build instead of pulling the latest master.
- **Only Chromium is downloaded** (variants 1–6): `playwright install` / `install-deps` became `playwright install chromium` / `install-deps chromium` in `automation/setup_import.sh`, `automation/setup_openplc.sh` and `1.Custom-HMI/build_system.sh`. All automation scripts only use `p.chromium.launch`; Firefox and WebKit were downloaded for nothing.
- **apt is skipped when packages are already installed** (variants 1–6):
  - `build_system.sh` skips `apt update` + `apt install python3-venv docker.io docker-compose` if all three are installed. As a consequence, a rebuild no longer upgrades these packages.
  - `automation/setup_import.sh` (2–6) skips the `apt install` of the Playwright libraries if they are installed. The check also accepts the Ubuntu 24.04 `t64` package names.
  - `playwright install-deps chromium` (which always runs `apt-get update`) is skipped if it already succeeded for the same Playwright version. The version is stored in `automation/.playwright_deps` (git-ignored); delete that file to force it.
- Host-side scripts only; nothing changes from an attacker's point of view.

### automation: Playwright version aligned in variants 5 and 6

- `5.NewScada` and `6.ScadaLTS-no-buttons` pinned `playwright==1.44.0` in `automation/requirements.txt`; variants 1–4 already used `playwright>=1.48`. All six now use `playwright>=1.48`.
- Playwright 1.44 does not recognise Ubuntu 24.04, so `playwright install-deps` fell back to an old package list (`libasound2`, `libicu70`, `libffi7`, `libx264-163`) and failed with apt exit code 100.
- Host-side automation only; nothing changes from an attacker's point of view.

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
