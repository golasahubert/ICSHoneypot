#!/usr/bin/env python3
# Unified Modbus collector for systems 1..4.
# This file contains the main collector and helpers to read Modbus points
# and write compact JSON snapshots (JSONL by default).
#
# Command-line arguments accepted:
#   --config PATH    Path to YAML configuration file (default: config.example.yaml)
#
# Config keys (example shown in config.example.yaml):
#   max_runtime_seconds: 0      # 0 = run forever
#   poll_interval_ms: 1000
#   log_dir: "./logs"
#   per_file: false
#   ack_url: ""
#   plcs: [ {name, host, port, unit_id, points: [...]}, ... ]

"""Unified Modbus collector for systems 1..4.

Reads configured PLC points and writes compact JSON snapshots.
"""

# Standard library imports
import argparse
import json
import logging
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List

# Third-party imports
import requests
import yaml
from pymodbus.client.sync import ModbusTcpClient
from pymodbus.constants import Endian
from pymodbus.payload import BinaryPayloadDecoder

# Configure basic logging for the module (ISO timestamps shown by the collector)
logging.basicConfig(level=logging.INFO, format='%(asctime)s %(levelname)s %(message)s')


def load_config(path: str) -> Dict[str, Any]:
    """
    Load YAML configuration from `path` and return it as a dictionary.

    Args:
        path: filesystem path to a YAML config file.

    Returns:
        Parsed configuration as a Python dict. If the file is empty, returns {}.
    """
    with open(path, 'r', encoding='utf-8') as fh:
        return yaml.safe_load(fh) or {}


def write_jsonl(path: Path, record: Dict[str, Any]):
    """
    Append a single JSON object as one line to a JSONL file.

    Args:
        path: Path to the JSONL file. Parent directories are created if missing.
        record: The Python dict to serialize and append as one line.
    """
    # Ensure parent directory exists
    path.parent.mkdir(parents=True, exist_ok=True)
    # Open file in append mode and write a compact JSON line
    with path.open('a', encoding='utf-8') as fh:
        fh.write(json.dumps(record, ensure_ascii=False) + '\n')


def write_json_file(path: Path, record: Dict[str, Any]):
    """
    Write a single JSON file (pretty-printed) containing `record`.

    Args:
        path: Path to output JSON file.
        record: Python dict to serialize.
    """
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open('w', encoding='utf-8') as fh:
        json.dump(record, fh, ensure_ascii=False, indent=2)


def send_ack(url: str, payload: Dict[str, Any], timeout: int = 10):
    """
    POST the snapshot payload to an acknowledgement URL (if configured).

    Args:
        url: The destination URL to POST JSON to. If empty, the function returns quickly.
        payload: The JSON-serializable payload to send.
        timeout: HTTP request timeout in seconds.
    """
    if not url:
        # No ack configured; nothing to do.
        return
    try:
        resp = requests.post(url, json=payload, timeout=timeout)
        resp.raise_for_status()
        logging.info('ACK sent to %s (HTTP %s)', url, resp.status_code)
    except Exception:
        logging.exception('Failed to send ACK to %s', url)


def decode_modbus_value(registers: List[int], datatype: str):
    """
    Decode raw Modbus register values into a Python numeric value according to `datatype`.

    Args:
        registers: list of 16-bit register integers returned by pymodbus.
        datatype: textual datatype (e.g. 'uint16', 'int16', 'uint32', 'int32', 'float32').

    Returns:
        Decoded numeric value or the raw first register if datatype is unknown.
    """
    # Build a decoder that interprets registers as big-endian words
    decoder = BinaryPayloadDecoder.fromRegisters(registers, byteorder=Endian.Big, wordorder=Endian.Big)
    dt = datatype.lower()
    if dt == 'uint16':
        return decoder.decode_16bit_uint()
    if dt == 'int16':
        return decoder.decode_16bit_int()
    if dt == 'uint32':
        return decoder.decode_32bit_uint()
    if dt == 'int32':
        return decoder.decode_32bit_int()
    if dt in ('float32', 'float'):
        return decoder.decode_32bit_float()
    # Fallback: return the first register value (raw) if no decoder matched
    return registers[0] if registers else None


def read_point(client: ModbusTcpClient, point: Dict[str, Any]):
    """
    Read a single configured point from a connected ModbusTcpClient.

    The `point` dict supports keys:
      - type: 'holding'|'input'|'coil'|'discrete' (defaults to 'holding')
      - address: numeric register/coil address (defaults to 0)
      - count: number of registers/coils to read (defaults to 1)
      - unit_id: Modbus unit/slave id (defaults to 1)
      - datatype: how to decode registers (defaults to 'uint16')

    Args:
        client: an already-created ModbusTcpClient instance.
        point: dict describing the point to read.

    Returns:
        The decoded value (int/float/bool/list) depending on point type.

    Raises:
        RuntimeError on Modbus errors, ValueError on unsupported point type.
    """
    # Normalize and extract point parameters
    ptype = str(point.get('type', 'holding')).lower()
    address = int(point.get('address', 0))
    count = int(point.get('count', 1))
    unit_id = int(point.get('unit_id', 1))
    datatype = point.get('datatype', 'uint16')

    # Holding registers (function code 3)
    if ptype in ('holding', 'holding_register', 'hr'):
        rr = client.read_holding_registers(address, count, unit=unit_id)
        if rr.isError():
            raise RuntimeError(f'read_holding_registers error at {address}: {rr}')
        return decode_modbus_value(rr.registers, datatype)

    # Input registers (function code 4)
    if ptype in ('input', 'input_register', 'ir'):
        rr = client.read_input_registers(address, count, unit=unit_id)
        if rr.isError():
            raise RuntimeError(f'read_input_registers error at {address}: {rr}')
        return decode_modbus_value(rr.registers, datatype)

    # Coils (single-bit writeable values)
    if ptype in ('coil', 'coils'):
        rr = client.read_coils(address, count, unit=unit_id)
        if rr.isError():
            raise RuntimeError(f'read_coils error at {address}: {rr}')
        if count == 1:
            return bool(rr.bits[0])
        return rr.bits

    # Discrete inputs (single-bit read-only values)
    if ptype in ('discrete', 'discrete_input'):
        rr = client.read_discrete_inputs(address, count, unit=unit_id)
        if rr.isError():
            raise RuntimeError(f'read_discrete_inputs error at {address}: {rr}')
        if count == 1:
            return bool(rr.bits[0])
        return rr.bits

    # Unknown point type
    raise ValueError(f'Unsupported point type: {ptype}')


def poll_all(plcs: List[Dict[str, Any]], log_dir: Path, per_file: bool, ack_url: str):
    """
    Poll all configured PLCs once and write a snapshot.

    Args:
        plcs: list of PLC configuration dictionaries (see config.example.yaml)
        log_dir: directory where snapshots are written
        per_file: if True, write one JSON file per snapshot, otherwise append to JSONL
        ack_url: optional URL to POST the snapshot to after writing
    """
    # Timestamp for the entire snapshot (UTC, ISO format)
    timestamp = datetime.now(timezone.utc).isoformat()
    snapshot: Dict[str, Any] = {'timestamp': timestamp, 'source': 'unified_modbus', 'plcs': {}}

    # Iterate over each PLC configured in the YAML
    for plc in plcs:
        name = plc.get('name', 'unknown')  # Friendly display name
        host = plc.get('host')              # IP or hostname where Modbus TCP listens
        port = int(plc.get('port', 502))    # TCP port (default 502)
        unit_id = int(plc.get('unit_id', 1))

        # Create a Modbus TCP client for this PLC; connection attempted below
        client = ModbusTcpClient(host, port=port)
        plc_record: Dict[str, Any] = {'status': 'unknown', 'data': {}}

        try:
            # Attempt to open TCP connection to the PLC
            if not client.connect():
                logging.warning('Cannot connect to %s (%s:%s)', name, host, port)
                plc_record['status'] = 'offline'
                snapshot['plcs'][name] = plc_record
                continue

            plc_record['status'] = 'connected'

            # Read all points configured for this PLC
            for point in plc.get('points', []):
                try:
                    # Ensure the point dict carries the PLC unit id (overrides point-level unit_id if absent)
                    point_with_unit = {**point, 'unit_id': unit_id}
                    # Read the point value using Modbus
                    value = read_point(client, point_with_unit)
                    # Apply scaling if provided in point config (e.g., scale: 0.1)
                    scale = float(point.get('scale', 1.0)) if point.get('scale') is not None else 1.0
                    if isinstance(value, (int, float)):
                        value = value * scale
                    # Key name for this value in the output (name or field)
                    key = point.get('name', point.get('field', 'value'))
                    plc_record['data'][key] = value
                except Exception:
                    # If a single point fails, log and continue with others
                    logging.exception('Failed reading point %s on %s', point.get('name'), name)
                    plc_record['data'][point.get('name', 'unknown')] = None

            # Store PLC snapshot into main snapshot structure
            snapshot['plcs'][name] = plc_record
        except Exception:
            logging.exception('Unexpected error polling PLC %s', name)
            snapshot['plcs'][name] = plc_record
        finally:
            try:
                client.close()
            except Exception:
                # Ignore close errors
                pass

    # Write snapshot to disk: either single JSON file or appended JSONL
    if per_file:
        filename = f"unified_{timestamp.replace(':','_').replace('+','_')}.json"
        out_path = log_dir / filename
        write_json_file(out_path, snapshot)
        logging.info('Wrote snapshot to %s', out_path)
    else:
        out_path = log_dir / 'unified_modbus.jsonl'
        write_jsonl(out_path, snapshot)
        logging.info('Appended snapshot to %s', out_path)

    # Optionally POST snapshot to an external ack_url for ingestion
    if ack_url:
        send_ack(ack_url, snapshot)


def main():
    """
    Entrypoint for the collector script. Parses CLI arguments, loads config and
    runs the polling loop.

    CLI arguments:
      --config PATH   Path to YAML config file (default: config.example.yaml)
    """
    # Parse command-line arguments
    parser = argparse.ArgumentParser(description='Unified Modbus collector for systems 1..4')
    parser.add_argument('--config', default='config.example.yaml', help='Path to YAML config file')
    args = parser.parse_args()

    # Resolve and load configuration file
    config_path = Path(args.config).resolve()
    config = load_config(str(config_path))

    # Determine log directory and whether per-file mode is enabled
    log_dir_value = config.get('log_dir', './logs')
    per_file = bool(config.get('per_file', False))
    log_dir = Path(log_dir_value)
    if not log_dir.is_absolute():
        # Make relative paths relative to the config file location
        log_dir = config_path.parent / log_dir
    log_dir.mkdir(parents=True, exist_ok=True)

    # Extract runtime parameters from config
    plcs = config.get('plcs', [])
    poll_interval_ms = int(config.get('poll_interval_ms', 1000))
    max_runtime_seconds = int(config.get('max_runtime_seconds', 0))
    ack_url = config.get('ack_url', '')

    start_time = time.monotonic()

    logging.info('Starting unified collector with poll interval %sms', poll_interval_ms)
    if max_runtime_seconds > 0:
        logging.info('Runtime limit: %s seconds', max_runtime_seconds)

    # Main polling loop: run until max_runtime_seconds is reached (if set)
    while True:
        if max_runtime_seconds > 0 and (time.monotonic() - start_time) >= max_runtime_seconds:
            logging.info('Max runtime reached, stopping')
            break

        try:
            poll_all(plcs, log_dir, per_file, ack_url)
        except KeyboardInterrupt:
            logging.info('Stopped by user')
            break
        except Exception:
            # Catch-all to keep the loop alive on unexpected errors
            logging.exception('Unhandled error in collector loop')

        # Sleep between polls (poll_interval_ms controls frequency, e.g. 1000ms = 1Hz)
        time.sleep(poll_interval_ms / 1000.0)


if __name__ == '__main__':
    raise SystemExit(main())
