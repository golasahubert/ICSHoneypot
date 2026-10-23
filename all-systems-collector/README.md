# Final PLC Data Collector

Minimal instructions to run the collector.

## 1) Install dependencies

```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

## 2) Edit config

Open `config.yaml` and set:

```yaml
runtime:
  mode: "continuous"       # "continuous", "duration" or "24h"
  duration_seconds: 21600   # used only in "duration" mode

polling:
  interval_ms: 1000

output:
  dir: "./logs"
  format: "jsonl"
  ack_url: ""
```

For a single 6h run use `mode: "duration"` and `duration_seconds: 21600`.
For 24/7 keep `mode: "continuous"`.

## 3) Run the collector

```bash
python final_collector.py --config config.yaml
```

For verbose logs:

```bash
python final_collector.py --config config.yaml --verbose
```

## 4) Output files

The script writes to the folder configured in `output.dir`, for example:

- `./logs/collector_data.jsonl`
- `./logs/collector.log`
- `./logs/collector.pid`

## 5) Run continuously as a systemd service (recommended)

With `mode: "continuous"` in `config.yaml`, the collector runs as a service. Every `build_system.sh` (variants 1–6) installs it automatically as its last step; to install or update it by hand:

```bash
sudo bash install_service.sh
systemctl status plc-collector
journalctl -u plc-collector -f
```

Variants 1–5 use `config.yaml`: every PLC is read over localhost (PLC1 `2502`, PLC2 `502`, PLC3 `4502`; published on `127.0.0.1` only, except PLC2 `502` on server 5, which is public).

On server 6 (`6.ScadaLTS-no-buttons`) PLC2 Modbus is not published on the host, so `6.config.yaml` reads it from the container IP `172.25.0.4:502`:

```bash
sudo bash install_service.sh 6.config.yaml
```

The service restarts automatically if the collector crashes and starts again after a reboot. In continuous mode a new CSV file is started every `output.rotate_hours` (default 6h), aligned to local time, so each day has 4 files:

```
/var/log/plc_collector/10/12/collector_data_20261012_000000.csv   # 00:00-06:00
/var/log/plc_collector/10/12/collector_data_20261012_060000.csv   # 06:00-12:00
/var/log/plc_collector/10/12/collector_data_20261012_120000.csv   # 12:00-18:00
/var/log/plc_collector/10/12/collector_data_20261012_180000.csv   # 18:00-24:00
```

If the service restarts mid-slot, it appends to that slot's file.

If you previously used a cron entry (`0 */6 * * * ...`), remove it with `crontab -e`, otherwise cron and the service will compete for the PID lock.

The script includes a PID lock so a second copy does not start while one is already running. It also writes a rotating log file and keeps going even if one poll fails.


Configure `ack_url` to POST each snapshot to an external server:

```yaml
output:
  ack_url: "https://api.example.com/ingest?token=xyz"
```

Payload sent is the full snapshot JSON. Server should respond with HTTP 200+.

## Files

- `config.yaml` — your active configuration (copy from config.example.yaml)
- `config.example.yaml` — template with all available options
- `final_collector.py` — main script (2500+ lines, fully commented)
- `requirements.txt` — Python dependencies
- `logs/` — default output directory (created at runtime)

## License

Use as needed for ICS/SCADA honeypot or production systems.
