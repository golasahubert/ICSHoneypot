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
  mode: "duration"         # "continuous", "duration" or "24h"
  duration_seconds: 21600   # 6h run

polling:
  interval_ms: 1000

output:
  dir: "./logs"
  format: "jsonl"
  ack_url: ""
```

For a 6h run every 6h, keep `mode: "duration"` and `duration_seconds: 21600`.
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

## 5) Run every 6h safely

Use a scheduler like cron or systemd timer:

```bash
0 */6 * * * cd /path/to/folder && python final_collector.py --config config.yaml
```

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
