# Final PLC Data Collector

Production-ready Modbus TCP data collector for OpenPLC and industrial systems. Reads data at configurable intervals and writes to JSON/JSONL with full customization via YAML config.

## Features

- **Multiple PLC Support**: Poll multiple Modbus TCP devices (OpenPLC, industrial PLCs, etc.)
- **Customizable Input/Output**: 
  - Choose which Modbus points to read (registers, coils, discrete inputs)
  - Customize output format (include/exclude timestamp, duration, data)
  - Support for multiple datatypes: uint16, int16, uint32, int32, float32
- **Two Runtime Modes**:
  - `continuous` — runs forever (until Ctrl+C)
  - `duration` — runs for specified seconds then exits
- **Flexible Output**:
  - **JSONL** (recommended for streaming/analysis): one JSON object per line
  - **JSON**: single JSON file per snapshot
- **Real-time Webhooks**: Optional POST to external service for live ingestion
- **Detailed Logging**: INFO/DEBUG output for troubleshooting

## Installation

1. **Create virtual environment**:
   ```bash
   python3 -m venv venv
   source venv/bin/activate
   ```

2. **Install dependencies**:
   ```bash
   pip install -r requirements.txt
   ```

## Usage

**Basic command**:
```bash
python final_collector.py --config config.yaml
```

**With verbose logging**:
```bash
python final_collector.py --config config.yaml --verbose
```

## Configuration

Edit `config.yaml` to customize:

### Runtime Mode

```yaml
runtime:
  mode: "continuous"        # or "duration" to run for X seconds
  duration_seconds: 20      # applies only if mode: "duration"
```

### Polling and Output

```yaml
polling:
  interval_ms: 1000         # read PLCs every N ms (1000ms = 1 Hz)

output:
  dir: "./logs"             # where to save files
  format: "jsonl"           # "jsonl" or "json"
  ack_url: ""               # optional: POST to this URL (leave empty to disable)
```

### Output Fields

Choose what to include in output:

```yaml
output_fields:
  include_timestamp: true   # ISO 8601 UTC timestamp
  include_duration: false   # cumulative runtime in seconds
  include_data: true        # actual PLC values
```

### PLC Configuration

Define all PLCs to monitor:

```yaml
plcs:
  - name: "PLC1 (T-201 Control)"
    host: "127.0.0.1"       # or hostname/docker network address
    port: 2502              # Modbus TCP port
    unit_id: 1              # Modbus slave unit (usually 1)
    
    points:                 # Points to read from this PLC
      - name: "water_level"
        type: "input"       # "input", "holding", "coil", "discrete"
        address: 0          # Modbus address (0-based)
        count: 1            # Number of registers/coils
        datatype: "uint16"  # "uint16", "int16", "uint32", "int32", "float32"
        scale: 1.0          # Multiply value by this
      
      - name: "pump_on"
        type: "coil"
        address: 0
        count: 1
```

## Output Format Examples

**JSONL (one line per snapshot)**:
```json
{"timestamp": "2026-08-29T20:23:00+00:00", "data": {"PLC1 (T-201 Control)": {"water_level": 39, "pump_on": true, "_status": "connected"}}}
{"timestamp": "2026-08-29T20:23:01+00:00", "data": {"PLC1 (T-201 Control)": {"water_level": 40, "pump_on": true, "_status": "connected"}}}
```

**With duration included**:
```json
{"timestamp": "2026-08-29T20:23:00+00:00", "duration": 0.15, "data": {"PLC1": {...}}}
```

## Common Scenarios

### Scenario 1: Continuous monitoring for 24/7 operation (use systemd)

```yaml
runtime:
  mode: "continuous"

polling:
  interval_ms: 1000
```

Run with systemd service (see deployment guide).

### Scenario 2: Hourly data snapshots (use cron)

```yaml
runtime:
  mode: "duration"
  duration_seconds: 3600    # 1 hour

polling:
  interval_ms: 1000         # 1 Hz
```

Cron job example:
```bash
0 * * * * cd /opt/collector && python final_collector.py --config config.yaml
```

### Scenario 3: Quick diagnostic check (5 seconds)

```yaml
runtime:
  mode: "duration"
  duration_seconds: 5

polling:
  interval_ms: 500          # 2 Hz
```

### Scenario 4: Low-frequency background monitoring

```yaml
polling:
  interval_ms: 5000         # Every 5 seconds (0.2 Hz)

output_fields:
  include_duration: false   # Save space, skip duration
  include_data: true
```

## Modbus Point Types

| Type | Modbus FC | Read/Write | Usage |
|------|-----------|-----------|-------|
| `input` | 4 | Read-only | Input registers (analog values from PLC) |
| `holding` | 3 | Read/Write | Holding registers (control & feedback) |
| `coil` | 5/15 | Read/Write | Discrete outputs (boolean control signals) |
| `discrete` | 2 | Read-only | Discrete inputs (boolean sensor inputs) |

## Troubleshooting

**Cannot connect to PLC**:
- Check host IP and port are correct
- Verify firewall allows TCP connection
- If PLC is in Docker: use host-mapped ports or docker network address
- Enable `--verbose` for detailed connection logs

**Wrong values or scaling**:
- Verify register address matches your PLC documentation
- Check datatype (uint16, float32, etc.) matches actual value type
- Use `scale` parameter to adjust (e.g., `scale: 0.01` for centimeters from raw data)

**Output file not created**:
- Verify output directory exists and is writable
- Check logs for permission errors
- Ensure `output.dir` path is correct (relative or absolute)

**Performance / CPU usage**:
- Reduce `poll_interval_ms` (e.g., 5000ms instead of 1000ms)
- Reduce number of points read per PLC
- Consider splitting into multiple collector instances

## Network Considerations

**Local PLCs** (same network):
- Use direct IP:port (e.g., 127.0.0.1:2502)

**Remote PLCs** (over network):
- Use SSH tunneling for security:
  ```bash
  ssh -L 127.0.0.1:2502:172.25.0.3:502 user@host &
  # Then configure with 127.0.0.1:2502
  ```
- Or use VPN if available

**Docker PLCs**:
- Use host-mapped port (e.g., 127.0.0.1:2502 → container 502)
- Or use docker network address (e.g., 172.25.0.3:502)

## Real-time Ingestion (Webhooks)

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
