# Updates

Changelog of changes to the project. Newest entries on top.

## 2026-10-14

### data-collection: rebuild-all installs and verifies the pcap capture

- On 2026-10-14 servers 5 and 6 had no `capture.service` at all (no pcaps since they were set up). Server 6 also uses interface `eth0` (not `ens3`) and has no global IPv6, so the old `capture.sh` would not have worked there.
- `capture.sh`:
  - interface taken from the default route (or the first argument) instead of a fixed `ens3`;
  - the filter is built only from the global addresses that exist (the old one became `host ` and failed without IPv6);
  - `exec tcpdump` (systemd tracks tcpdump itself) and `-U`, so every packet is written at once.
  - Same filter as before on servers 1–5 (IPv4 + global IPv6 of `ens3`), checked with a dry run on servers 1 and 6.
- New `install_capture.sh` (run as root):
  - installs `tcpdump` if missing, `capture.sh` as `/root/capture.sh` and `capture.service`, then enables the service;
  - restarts it only if one of the files changed or it is not running;
  - then verifies that a pcap is being written (prints journal lines on failure) and warns at ≥ 85% disk usage.
- `rebuild-all.sh`:
  - runs `install_capture.sh` right after `git pull`, before the build, so capture also runs if the build fails. New exit code 15: capture not running.
  - New option `--capture-only`: only `git pull` and the capture install, no rebuild (containers keep running, no new measurement period).
- `clean.sh`: matches pcaps of any interface (`eth0-*.pcap` on server 6).
- Operational only (not visible to attackers). Servers 1–4 get a short capture restart (a few seconds, new pcap file) the first time, because `capture.sh` changed.

### data-collection: log sync for all servers, git pull and log check in rebuild-all

- `log-collector.sh` rewritten. It only listed server 1, under the SSH alias `singapore-001-DC2`, which does not exist in `~/.ssh/config`, and it needed a key `~/.ssh/deploys`. It now uses the `singapore-001` … `singapore-006` aliases (same as `rebuild-all.sh`) and pulls both `/var/log/tcpdump` (pcap) and `/var/log/plc_collector` (CSV) into `~/data-collection/hmi-deploy-logs/<variant>/{pcap,plc_collector}/`. Incremental (`rsync --append-verify`), never deletes local files, prints an OK/FAIL summary, accepts a host list. Needs `rsync` on the analysis machine.
- New `check-logs.sh`: over SSH, checks per server that `capture.service` and `plc-collector` are active, that the newest pcap is at most 15 min old and the newest CSV at most 2 min old, and warns at ≥ 85% disk usage. Exit code = number of servers with a problem.
- `rebuild-all.sh`:
  - Before `build_system.sh` it runs `git pull --ff-only origin main` in the server's clone. Local edits to tracked files are stashed first (`git stash list` on the server). If the pull fails, nothing is rebuilt (new exit code 14).
  - Why: on 2026-10-14 servers 2 and 4 were still on commit `00e9852` (before the collector service and restart policies), so their rebuild did not install `plc-collector`, and no CSVs have been written there since 2026-10-11/12. Servers 1, 3, 5 and 6 were on different commits too.
  - After the summary it runs `check-logs.sh` for the rebuilt hosts and saves the result to `log-check.txt` in the rebuild log directory.
- Operational only (not visible to attackers).

### English only: comments and log messages translated

- Polish comments translated in `1.Custom-HMI/kill_docker.sh`, `docker-compose.yml` of 4–6 and the three collector configs.
- `plc_2_docker/comm_modbus.py` (all folders, still identical): Italian print messages translated and the variable `richiesta` renamed to `request`. Only container stdout changes; it takes effect on the next rebuild.
- `CLAUDE.md`: rule that everything in the repo is written in English; data-collection section and known open issues updated (capture missing on 5 and 6, `clean.sh` not in cron, dead `copy_logs.sh` cron entry, OpenPLC not pinned, `pointLinks` only in 2/3/6).

## 2026-10-13

### 6.ScadaLTS-no-buttons: 2 GB swap created by build_system.sh

- Server 6 (1 GB RAM, no swap) froze twice during `build_system.sh`, while creating the venvs right after `docker-compose up` (Scada-LTS, MySQL and 3x OpenPLC starting at the same time). SSH stopped answering (`Connection timed out during banner exchange`) and the server needed a reboot.
- `build_system.sh` now checks for swap before stopping the old environment. If no swap is active, it creates a 2 GB `/swapfile` (`fallocate`, falling back to `dd`), enables it and adds it to `/etc/fstab`. If swap is already active, the step does nothing.
- Operational only (not visible to attackers). `diff -r 5.NewScada 6.ScadaLTS-no-buttons` now also shows this step.

### 6.ScadaLTS-no-buttons: Scada-LTS heap limited to 512 MB

- `docker-compose.yml`: `CATALINA_OPTS=-Xmx512m -Xms512m` (was `-Xmx2G -Xms512m`, still the value in 4 and 5). Server 6 has 1 GB RAM, and a 2 GB heap next to MySQL and 3x OpenPLC can push the machine into swap, which keeps the CPU at 100%.
- Operational only (resource limit, not visible to attackers). If Scada-LTS restarts or is slow, check `tomcat_log/` for `OutOfMemoryError`.

### 6.ScadaLTS-no-buttons: build script back to the one from 4, collector before Playwright

- Reverts the previous entry ("Playwright installed before the containers"). `build_system.sh` and `automation/setup_import.sh` are again copied from `4.ScadaLTSv2.7.4`: containers start first, Playwright/Chromium are installed afterwards by `setup_import.sh` (under `sudo`, as in 4).
- One difference from 4: the `plc-collector` service is installed right after `docker-compose up` (before Playwright/Chromium and the SCADA import), not at the end. Data collection starts as soon as the PLCs are up. The collector reconnects by itself during the `stop_system.sh`/`start_system.sh` restart at the end.
- The collector still uses `6.config.yaml`. PLC2 Modbus is not published on the host in variant 6, so `config.yaml` (PLC2 on `127.0.0.1:502`) would collect nothing from PLC2.
- Operational only (not visible to attackers). `diff -r 4.ScadaLTSv2.7.4 6.ScadaLTS-no-buttons` now shows only `dataHMI.txt`, the PLC2 port in `docker-compose.yml` and the collector step in `build_system.sh`.

### 6.ScadaLTS-no-buttons: Playwright installed before the containers

- On a fresh Ubuntu 20.04 VPS (1 core, 1 GB RAM, 15 GB disk) `build_system.sh` froze the machine during the Playwright install and it needed a reboot. Chromium and its apt dependencies were installed while the whole stack (Scada-LTS, MySQL, 3x OpenPLC) was already running, and the server ran out of memory.
- `build_system.sh` now installs the venv, `requirements.txt`, Chromium and `install-deps chromium` **before** `docker-compose up`. The containers start only after that.
- `automation/setup_import.sh` only runs `login_scada.py` and `login_openplc.py` with the venv Python. The second `pip install playwright`, the manual `apt install` of browser libraries and the duplicated script header are removed.
- `setup_import.sh` is no longer run with `sudo`, so it uses the same Chromium in the user's `~/.cache/ms-playwright` (no second copy in `/root/.cache`). `build_system.sh` fixes the ownership of `venv` and `.playwright_deps` left by earlier root runs.
- Operational only (not visible to attackers). Variant 5 still has the old order, so `diff -r 5.NewScada 6.ScadaLTS-no-buttons` now also shows these two files.
- Not yet tested on a server. On a 1 GB RAM machine add swap as well (e.g. a 2 GB `/swapfile`).

## 2026-10-12

### 6.ScadaLTS-no-buttons: same as 5, PLC2 Modbus hidden

- `docker-compose.yml`, `build_system.sh` and `automation/` (except `dataHMI.txt`) are copied from `5.NewScada`. That brings the MySQL healthcheck, and the wipe of the `db_storage` volume on every build, so the import always starts from an empty DB.
- **PLC2 Modbus is not published on the host** (no `502`/`3502` mapping). PLC2's OpenPLC web (`38080`) and `39090` stay published. ScadaLTS still reads PLC2 over the internal Docker network.
- `automation/dataHMI.txt` stays the one from `3.scadaBR-without-buttons` (no script buttons, users `admin` and `user`). It was already identical.
- New collector config `all-systems-collector/6.config.yaml`. It reads PLC2 from its container IP `172.25.0.4:502`, which the host can reach directly (checked on the test server). `6.ScadaLTS-no-buttons/build_system.sh` installs the collector with it.
- **Visible to attackers** (PLC2 port closed): deploy on server 6 between measurement periods.
- Verified on the test server after a full build:
  - PLC2 Modbus is closed on all host addresses.
  - The HMI works via `http://<ip>/` and `:8080`.
  - The import created `DATA PLC1/2/3`, `HMI SYSTEM`, the scripts and point links. Its only event handler (`test script high`) was not imported.
  - Logins work with `admin/admin` and `user/user`.
  - ScadaLTS is connected to all 3 PLCs.
  - The collector reads PLC2 via `172.25.0.4:502`.
- `CLAUDE.md`: SCADA users corrected. The second account is `user/user` (only in 3 and 6), not `user/user123`.

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
