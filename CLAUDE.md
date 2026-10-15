# ICSHoneypot

Research ICS honeypots imitating a simplified SWaT water-treatment process: 3 OpenPLC containers (PLC1–3, one tank each), a Python physics simulator (`physical_sim_docker/physics_sim.py`, ODE via scipy) talking to the PLCs over UDP, and an HMI that differs per variant.

## Deployment model

- Each production server runs exactly **one** variant folder, continuously:
  `1.Custom-HMI`, `2.scadaBR`, `3.scadaBR-without-buttons`, `4.ScadaLTSv2.7.4`, `5.NewScada`, `6.ScadaLTS-no-buttons`.
  `scadaLTS/` is an older, unused variant.
- It is a comparative study of HMI variants, so the PLC/simulator layer is a controlled variable:
  - Changes visible to attackers (exposed ports, data scaling/noise, PLC logic, web pages) must be applied to **all** servers at once, between measurement periods.
  - Operational changes (restart policy, firewall, resource limits, capture/collector fixes) are safe at any time.
- Data collected on each server:
  - pcap: `data-collection/capture.sh` (tcpdump on the default-route interface: `ens3` on 1–5, `eth0` on 6; systemd `capture.service`), pcaps in `/var/log/tcpdump/YYYY/MM/`, one file per 12 h. Installed and verified by `data-collection/install_capture.sh`, which `rebuild-all.sh` runs on every server (`./rebuild-all.sh --capture-only` does only that, without a rebuild); `build_system.sh` does not install it.
  - Both pcaps and CSVs are pulled to the analysis machine by `data-collection/log-collector.sh` (rsync over the `singapore-00N` SSH aliases, into `~/data-collection/hmi-deploy-logs/<variant>/{pcap,plc_collector}/`).
  - `data-collection/check-logs.sh` checks over SSH that every server is still writing pcaps and CSVs; `rebuild-all.sh` runs it after every rebuild.
  - `data-collection/rebuild-all.sh` does `git pull --ff-only origin main` on each server before `build_system.sh` (local edits are stashed, see `git stash list`), so servers always build the current `main`.
  - Modbus process snapshots: `all-systems-collector/final_collector.py`, run as systemd service `plc-collector` (installed automatically by every `build_system.sh`: at the end in 1–5, right after `docker-compose up` in 6; or by hand with `sudo bash all-systems-collector/install_service.sh`), CSV in `/var/log/plc_collector/MM/DD/`, one file per 6h slot (4 per day).

## Per-variant differences to remember

- `5.NewScada` is a copy of `4.ScadaLTSv2.7.4` (stock ScadaLTS v2.7.4, same import, MySQL and nginx) with one exposed difference: PLC2 Modbus on host port `3502`. Keep 4 and 5 in sync (`diff -r 4.ScadaLTSv2.7.4 5.NewScada` should only show the PLC2 port and the collector config in `build_system.sh`).
- `6.ScadaLTS-no-buttons` is the same as 5 with two differences: PLC2 Modbus is **not published** on the host at all, and `automation/dataHMI.txt` is the one from 3 (no buttons, users `admin` and `user`). `diff -r 5.NewScada 6.ScadaLTS-no-buttons` should only show those, plus the collector config/step and the 2 GB swap step in `build_system.sh`, and the Scada-LTS heap (`-Xmx512m` in 6, server has 1 GB RAM).
- PLC2 Modbus is exposed on host port `502` in variants 1–4, on `3502` in 5, and not at all in 6. Collector configs: `config.yaml` (1–4), `5.config.yaml` (5), and `6.config.yaml` (6, which reads PLC2 from its container IP `172.25.0.4:502`). Each `build_system.sh` passes the right config; by hand: `sudo bash all-systems-collector/install_service.sh <config>`.
- Host ports: PLC1 `2502`, PLC3 `4502`, OpenPLC web `28080/38080/48080` (login `openplc/openplc`).
- HMI: nginx on port `80` (redirects to the HMI) in variants 2–6; ScadaLTS directly on `8080` in 4–6.
- SCADA users (from `automation/dataHMI.txt`): `admin/admin` in 2–6; additionally `user/user` in 3 and 6 (checked on the test server for 5 and 6, 2026-10-13).

## Code layout / conventions

- PLC, simulator and automation code is **duplicated identically** in every variant folder. A fix to `physics_sim.py`, `plc_*/main.py`, `comm_modbus.py`, `*.st` etc. must be applied to all 6 folders (verify with `md5sum */<path>`).
- `build_system.sh` wipes all containers (`kill_docker.sh`), rebuilds and runs Playwright automation (OpenPLC "Save changes", SCADA import). On a running server, use `docker-compose up -d` for compose-only changes instead of a full rebuild.
- All services use `restart: unless-stopped` (`scadalts` in 4 and 6: `always`).
- Every change made to the repo must also be described in English in `UPDATE.md` (newest entries on top).
- **Everything in the repo is written in English**: code, comments, log/print messages, commit messages, `UPDATE.md` and docs. Translate any non-English comment or message you touch (the user may talk to you in Polish; that does not change the repo language).

## Known open issues (not yet fixed)

- PLC containers start snap7 (S7, port 102) and a fake Siemens web page (port 80), but no compose file publishes those ports.
- No egress filtering or resource limits on containers.
- MySQL in 4–6 still has weak credentials (`root/root`, `scadalts/scadalts`). Since 2026-10-15 it is published only on `127.0.0.1`; before that, bots wiped the `scadalts` database on servers 4 and 5 (servers need a rebuild to pick up the fix and restore the DB).
- UDP between simulator and PLCs uses `pickle` (should be JSON).
- `clean.sh` would delete pcaps after 7 days regardless of whether they were synced, but (checked 2026-10-14) it is not in cron on any server.
- Until `rebuild-all.sh` (with `install_capture.sh`) is run on them, servers 5 and 6 have no `capture.service` (checked 2026-10-14), so there are no pcaps from them yet. Server 6 is at 88% disk usage.
- Servers 2, 3 and 4 have a dead user cron entry `0 2 * * * ~/ICSHoneypot/data-collection/copy_logs.sh` (the script does not exist).
- OpenPLC is not pinned (`#RUN git checkout ...` is commented out in the PLC Dockerfiles), so each server may run a different OpenPLC commit depending on when its Docker layer was built.
- `automation/dataHMI.txt` in 4 and 5 has no `pointLinks`, while 2, 3 and 6 have 6. Setting a point from the HMI may therefore reach the PLC in 2/3/6 but not in 4/5 (to be checked in the lab). This is a confound in the 4 vs 6 comparison.
