#!/usr/bin/env python3
# ============================================================================
# FINAL PLC DATA COLLECTOR
# ============================================================================
# Purpose: Read data from one or more Modbus TCP devices (PLCs) at regular
#          intervals and write snapshots to JSON/JSONL files with full
#          customization via YAML config.
#
# Usage:   python final_collector.py --config config.yaml
#
# Config controls:
#   - Runtime mode: continuous or duration-limited
#   - Poll interval (milliseconds)
#   - PLC addresses, ports, and points to read
#   - Output format (JSON Lines or single JSON per snapshot)
#   - Which fields to include in output (timestamp, duration, data)
#
# Output example (JSONL):
# {"timestamp": "2026-08-29T20:23:00+00:00", "data": {"PLC1 (T-201 Control)": {"water_level": 39}}}
# {"timestamp": "2026-08-29T20:23:01+00:00", "data": {"PLC1 (T-201 Control)": {"water_level": 39}}}
# ============================================================================

import argparse
import json
import logging
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional

import requests
import yaml
from pymodbus.client.sync import ModbusTcpClient
from pymodbus.constants import Endian
from pymodbus.payload import BinaryPayloadDecoder

# Configure logging with timestamps and log levels
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s'
)
logger = logging.getLogger(__name__)


# ============================================================================
# CONFIGURATION LOADING
# ============================================================================

def load_yaml_config(config_path: str) -> Dict[str, Any]:
    """
    Load and parse YAML configuration file.
    
    Args:
        config_path: Path to YAML config file.
    
    Returns:
        Parsed configuration as Python dict.
        
    Raises:
        FileNotFoundError: If config file does not exist.
        yaml.YAMLError: If config is malformed YAML.
    """
    config_file = Path(config_path)
    if not config_file.exists():
        raise FileNotFoundError(f"Config file not found: {config_path}")
    
    logger.info(f"Loading configuration from: {config_file.resolve()}")
    with open(config_file, 'r', encoding='utf-8') as fh:
        config = yaml.safe_load(fh) or {}
    
    logger.info("Configuration loaded successfully")
    return config


# ============================================================================
# MODBUS CONNECTION AND READING
# ============================================================================

def create_modbus_client(host: str, port: int, timeout: int = 5) -> ModbusTcpClient:
    """
    Create and return a ModbusTcpClient instance.
    
    Args:
        host: IP address or hostname of Modbus device.
        port: TCP port (usually 502 or 20502 for OpenPLC).
        timeout: Connection timeout in seconds.
    
    Returns:
        ModbusTcpClient instance (not yet connected).
    """
    return ModbusTcpClient(host, port=port, timeout=timeout)


def connect_plc(client: ModbusTcpClient, name: str, host: str, port: int) -> bool:
    """
    Attempt to connect ModbusTcpClient and log the result.
    
    Args:
        client: ModbusTcpClient instance to connect.
        name: Friendly name for logging.
        host: IP/hostname.
        port: TCP port.
    
    Returns:
        True if connection succeeded, False otherwise.
    """
    try:
        connected = client.connect()
        if connected:
            logger.debug(f"Connected to {name} ({host}:{port})")
            return True
        else:
            logger.warning(f"Failed to connect to {name} ({host}:{port})")
            return False
    except Exception as e:
        logger.error(f"Exception connecting to {name}: {e}")
        return False


def close_plc(client: ModbusTcpClient):
    """
    Close a ModbusTcpClient connection gracefully.
    
    Args:
        client: ModbusTcpClient to close.
    """
    try:
        client.close()
    except Exception as e:
        logger.debug(f"Exception closing client: {e}")


# ============================================================================
# MODBUS DATA DECODING
# ============================================================================

def decode_modbus_registers(registers: List[int], datatype: str) -> Any:
    """
    Decode raw Modbus register values according to specified datatype.
    
    Supports:
      - uint16: unsigned 16-bit (0-65535)
      - int16: signed 16-bit (-32768 to 32767)
      - uint32: unsigned 32-bit (combines two 16-bit registers)
      - int32: signed 32-bit
      - float32: 32-bit IEEE 754 floating point
    
    Args:
        registers: List of 16-bit integers from Modbus device.
        datatype: String name of datatype (case-insensitive).
    
    Returns:
        Decoded numeric value, or None if unknown datatype.
    """
    if not registers:
        return None
    
    try:
        # Build decoder from register data using big-endian byte/word order
        decoder = BinaryPayloadDecoder.fromRegisters(
            registers,
            byteorder=Endian.Big,
            wordorder=Endian.Big
        )
        
        dt = datatype.lower().strip()
        
        if dt == 'uint16':
            return decoder.decode_16bit_uint()
        elif dt == 'int16':
            return decoder.decode_16bit_int()
        elif dt == 'uint32':
            return decoder.decode_32bit_uint()
        elif dt == 'int32':
            return decoder.decode_32bit_int()
        elif dt in ('float32', 'float'):
            return decoder.decode_32bit_float()
        else:
            logger.warning(f"Unknown datatype: {datatype}; returning raw value")
            return registers[0]
    except Exception as e:
        logger.error(f"Error decoding {datatype}: {e}")
        return None


def read_modbus_point(
    client: ModbusTcpClient,
    point_config: Dict[str, Any],
    unit_id: int
) -> Any:
    """
    Read a single Modbus point (register, coil, etc.) from a connected client.
    
    Point config keys:
      - type: "input", "holding", "coil", "discrete" (defaults to "input")
      - address: register address (0-based, defaults to 0)
      - count: number of registers/bits to read (defaults to 1)
      - datatype: "uint16", "int16", "uint32", "int32", "float32" (defaults to "uint16")
      - scale: multiply result by this value (defaults to 1.0)
    
    Args:
        client: Connected ModbusTcpClient.
        point_config: Dict describing the point to read.
        unit_id: Modbus slave unit ID (overrides point config if needed).
    
    Returns:
        Decoded and scaled value, or None on error.
    """
    try:
        # Extract point parameters
        point_type = str(point_config.get('type', 'input')).lower().strip()
        address = int(point_config.get('address', 0))
        count = int(point_config.get('count', 1))
        datatype = point_config.get('datatype', 'uint16')
        scale = float(point_config.get('scale', 1.0))
        
        # Use provided unit_id if present in point config, else use the PLCs default
        if 'unit_id' in point_config:
            unit_id = int(point_config['unit_id'])
        
        # Read based on point type
        if point_type in ('input', 'input_register', 'ir'):
            # Input registers (function code 4 - read-only)
            result = client.read_input_registers(address, count, unit=unit_id)
            if result.isError():
                logger.error(f"Input register read error at address {address}: {result}")
                return None
            value = decode_modbus_registers(result.registers, datatype)
        
        elif point_type in ('holding', 'holding_register', 'hr'):
            # Holding registers (function code 3 - read/write)
            result = client.read_holding_registers(address, count, unit=unit_id)
            if result.isError():
                logger.error(f"Holding register read error at address {address}: {result}")
                return None
            value = decode_modbus_registers(result.registers, datatype)
        
        elif point_type in ('coil', 'coils'):
            # Coils (single-bit read/write values)
            result = client.read_coils(address, count, unit=unit_id)
            if result.isError():
                logger.error(f"Coil read error at address {address}: {result}")
                return None
            # Return single bool or list of bools depending on count
            value = bool(result.bits[0]) if count == 1 else result.bits
        
        elif point_type in ('discrete', 'discrete_input', 'di'):
            # Discrete inputs (single-bit read-only values)
            result = client.read_discrete_inputs(address, count, unit=unit_id)
            if result.isError():
                logger.error(f"Discrete input read error at address {address}: {result}")
                return None
            value = bool(result.bits[0]) if count == 1 else result.bits
        
        else:
            logger.error(f"Unsupported point type: {point_type}")
            return None
        
        # Apply scaling if value is numeric
        if value is not None and isinstance(value, (int, float)):
            value = value * scale
        
        return value
    
    except Exception as e:
        logger.error(f"Unexpected error reading point: {e}")
        return None


# ============================================================================
# SNAPSHOT COLLECTION AND OUTPUT
# ============================================================================

def collect_snapshot(
    plcs_config: List[Dict[str, Any]],
    start_time: float
) -> Dict[str, Any]:
    """
    Poll all configured PLCs once and collect a snapshot.
    
    Creates a snapshot containing:
      - timestamp: ISO 8601 UTC
      - duration: runtime in seconds (if enabled in output_fields)
      - data: per-PLC collected values
    
    Args:
        plcs_config: List of PLC configuration dicts.
        start_time: time.time() when polling started (for duration calc).
    
    Returns:
        Snapshot dict with collected data.
    """
    timestamp_iso = datetime.now(timezone.utc).isoformat()
    duration_sec = time.time() - start_time
    
    snapshot = {
        'timestamp': timestamp_iso,
        'data': {}
    }
    
    # Poll each PLC
    for plc_config in plcs_config:
        plc_name = plc_config.get('name', 'unknown')
        host = plc_config.get('host', 'localhost')
        port = int(plc_config.get('port', 502))
        unit_id = int(plc_config.get('unit_id', 1))
        points = plc_config.get('points', [])
        
        # Create and connect client
        client = create_modbus_client(host, port)
        plc_data = {}
        connection_ok = False
        
        try:
            connection_ok = connect_plc(client, plc_name, host, port)
            
            if not connection_ok:
                logger.warning(f"Skipping points for {plc_name} (connection failed)")
                plc_data['_status'] = 'offline'
            else:
                # Read all points for this PLC
                for point in points:
                    point_name = point.get('name', 'unnamed_point')
                    try:
                        value = read_modbus_point(client, point, unit_id)
                        plc_data[point_name] = value
                        logger.debug(f"{plc_name}.{point_name} = {value}")
                    except Exception as e:
                        logger.error(f"Error reading {plc_name}.{point_name}: {e}")
                        plc_data[point_name] = None
                
                plc_data['_status'] = 'connected'
        
        except Exception as e:
            logger.error(f"Unexpected error polling {plc_name}: {e}")
            plc_data['_status'] = 'error'
        
        finally:
            close_plc(client)
        
        # Add PLC data to snapshot
        snapshot['data'][plc_name] = plc_data
    
    # Optionally add duration
    if plcs_config:  # only if we polled something
        snapshot['duration'] = round(duration_sec, 2)
    
    return snapshot


def write_snapshot_jsonl(snapshot: Dict[str, Any], output_path: Path):
    """
    Append a snapshot to a JSON Lines file (one JSON object per line).
    
    Args:
        snapshot: The snapshot dict to write.
        output_path: Path to JSONL file.
    """
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, 'a', encoding='utf-8') as fh:
        json_line = json.dumps(snapshot, ensure_ascii=False)
        fh.write(json_line + '\n')
    logger.info(f"Appended snapshot to {output_path}")


def write_snapshot_json(snapshot: Dict[str, Any], output_path: Path):
    """
    Write a single snapshot to a JSON file (overwriting if exists).
    
    Args:
        snapshot: The snapshot dict to write.
        output_path: Path to JSON file.
    """
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, 'w', encoding='utf-8') as fh:
        json.dump(snapshot, fh, ensure_ascii=False, indent=2)
    logger.info(f"Wrote snapshot to {output_path}")


def send_ack_webhook(snapshot: Dict[str, Any], ack_url: str, timeout: int = 10):
    """
    POST snapshot to an external webhook URL (for real-time ingestion).
    
    Args:
        snapshot: The snapshot dict to send.
        ack_url: HTTP(S) URL to POST to.
        timeout: Request timeout in seconds.
    """
    if not ack_url:
        return
    
    try:
        response = requests.post(ack_url, json=snapshot, timeout=timeout)
        response.raise_for_status()
        logger.info(f"ACK webhook sent to {ack_url} (HTTP {response.status_code})")
    except requests.exceptions.RequestException as e:
        logger.error(f"Failed to send ACK webhook: {e}")


# ============================================================================
# MAIN COLLECTOR LOOP
# ============================================================================

def run_collector(config: Dict[str, Any]):
    """
    Main collector loop: poll PLCs at intervals and write snapshots.
    
    Respects runtime mode from config:
      - "continuous": run until Ctrl+C
      - "duration": run for duration_seconds then exit
    
    Args:
        config: Loaded configuration dict.
    """
    # Parse runtime configuration
    runtime_config = config.get('runtime', {})
    runtime_mode = runtime_config.get('mode', 'continuous')
    max_duration = int(runtime_config.get('duration_seconds', 0))
    
    polling_config = config.get('polling', {})
    poll_interval_ms = int(polling_config.get('interval_ms', 1000))
    
    output_config = config.get('output', {})
    output_dir = output_config.get('dir', './logs')
    output_format = output_config.get('format', 'jsonl').lower()
    ack_url = output_config.get('ack_url', '')
    
    output_fields_config = config.get('output_fields', {})
    include_timestamp = output_fields_config.get('include_timestamp', True)
    include_duration = output_fields_config.get('include_duration', False)
    include_data = output_fields_config.get('include_data', True)
    
    plcs = config.get('plcs', [])
    
    # Resolve output directory
    if not Path(output_dir).is_absolute():
        # Make relative paths relative to config file location
        config_dir = Path.cwd()
        output_dir = str(config_dir / output_dir)
    
    output_path = Path(output_dir)
    output_path.mkdir(parents=True, exist_ok=True)
    
    # Determine output filename
    if output_format == 'jsonl':
        snapshot_file = output_path / 'collector_data.jsonl'
    else:
        snapshot_file = output_path / 'collector_data.json'
    
    # Log startup info
    logger.info(f"Runtime mode: {runtime_mode}")
    if runtime_mode == 'duration':
        logger.info(f"Duration limit: {max_duration} seconds")
    logger.info(f"Poll interval: {poll_interval_ms} ms ({1000/poll_interval_ms:.1f} Hz)")
    logger.info(f"Output format: {output_format}")
    logger.info(f"Output file: {snapshot_file.resolve()}")
    logger.info(f"Number of PLCs: {len(plcs)}")
    
    start_time = time.time()
    snapshot_count = 0
    
    try:
        while True:
            # Check runtime limit
            if runtime_mode == 'duration':
                elapsed = time.time() - start_time
                if elapsed >= max_duration:
                    logger.info(f"Duration limit reached ({elapsed:.1f}s), stopping collector")
                    break
            
            # Collect snapshot
            try:
                snapshot = collect_snapshot(plcs, start_time)
                
                # Filter output fields based on config
                output_snapshot = {}
                if include_timestamp:
                    output_snapshot['timestamp'] = snapshot.get('timestamp')
                if include_duration:
                    output_snapshot['duration'] = snapshot.get('duration')
                if include_data:
                    output_snapshot['data'] = snapshot.get('data')
                
                # Write to file
                if output_format == 'jsonl':
                    write_snapshot_jsonl(output_snapshot, snapshot_file)
                else:
                    write_snapshot_json(output_snapshot, snapshot_file)
                
                # Send ACK webhook if configured
                if ack_url:
                    send_ack_webhook(output_snapshot, ack_url)
                
                snapshot_count += 1
                
            except Exception as e:
                logger.error(f"Error in collection loop: {e}")
            
            # Sleep until next poll
            time.sleep(poll_interval_ms / 1000.0)
    
    except KeyboardInterrupt:
        logger.info("Collector stopped by user (Ctrl+C)")
    
    except Exception as e:
        logger.error(f"Unexpected error in main loop: {e}")
        raise
    
    finally:
        elapsed = time.time() - start_time
        logger.info(f"Collector finished. Collected {snapshot_count} snapshots in {elapsed:.1f}s")


# ============================================================================
# ENTRY POINT
# ============================================================================

def main():
    """
    Parse command-line arguments and start the collector.
    
    Supported CLI arguments:
      --config PATH   Path to YAML configuration file (default: config.yaml)
      --verbose       Enable DEBUG logging
    """
    parser = argparse.ArgumentParser(
        description='Final PLC Data Collector - Read Modbus devices, save to JSON'
    )
    parser.add_argument(
        '--config',
        default='config.yaml',
        help='Path to YAML configuration file (default: config.yaml)'
    )
    parser.add_argument(
        '--verbose',
        action='store_true',
        help='Enable DEBUG logging for detailed diagnostics'
    )
    
    args = parser.parse_args()
    
    # Enable verbose logging if requested
    if args.verbose:
        logger.setLevel(logging.DEBUG)
        for handler in logger.handlers:
            handler.setLevel(logging.DEBUG)
    
    try:
        # Load configuration
        config = load_yaml_config(args.config)
        
        # Validate minimal config structure
        if 'plcs' not in config or not config['plcs']:
            logger.error("Configuration must contain 'plcs' list with at least one PLC")
            return 1
        
        # Run collector
        run_collector(config)
        return 0
    
    except FileNotFoundError as e:
        logger.error(f"Configuration error: {e}")
        return 1
    
    except yaml.YAMLError as e:
        logger.error(f"YAML parsing error: {e}")
        return 1
    
    except Exception as e:
        logger.error(f"Fatal error: {e}")
        return 1


if __name__ == '__main__':
    sys.exit(main())
