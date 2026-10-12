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
  - Modbus process snapshots: `all-systems-collector/final_collector.py`, run as systemd service `plc-collector` (install with `sudo bash all-systems-collector/install_service.sh`), CSV in `/var/log/plc_collector/MM/DD/`, one file per 6h slot (4 per day).

## Per-variant differences to remember

- PLC2 Modbus is exposed on host port `502` in all variants **except 5.NewScada, where it is `3502`**. On server 5 install the collector with `sudo bash all-systems-collector/install_service.sh 5.config.yaml`.
- Host ports: PLC1 `2502`, PLC3 `4502`, OpenPLC web `28080/38080/48080` (login `openplc/openplc`).
- SCADA users (variants 2–6): `admin/admin`, `user/user123`.

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
