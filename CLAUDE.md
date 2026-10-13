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
  - pcap: `data-collection/capture.sh` (tcpdump on `ens3`, systemd `capture.service`), pulled by `log-collector.sh` via rsync.
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

## Known open issues (not yet fixed)

- PLC containers start snap7 (S7, port 102) and a fake Siemens web page (port 80), but no compose file publishes those ports.
- No egress filtering or resource limits on containers; MySQL `3306` published with weak credentials in variants 4–6.
- UDP between simulator and PLCs uses `pickle` (should be JSON).
- `capture.sh` builds an invalid filter when the interface has no global IPv6.
- `clean.sh` deletes pcaps after 7 days regardless of whether they were synced; collector CSVs are not synced by `log-collector.sh`.
