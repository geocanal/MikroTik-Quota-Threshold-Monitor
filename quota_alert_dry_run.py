"""Offline quota alert dry-run utility.

Pure offline tool for evaluating router quota alert thresholds
based on the local threshold query contract.
"""

from __future__ import annotations

import argparse
import datetime
import decimal
import json
import math
import pathlib
import sys
from typing import Any, Dict, List, Set, Tuple

MAX_INPUT_BYTES: int = 1024 * 1024  # 1 MiB
MAX_RECORDS: int = 1000
MAX_ROUTER_ID_LEN: int = 64
MAX_INTERFACE_NAME_LEN: int = 32

TIER_80 = decimal.Decimal("80")
TIER_95 = decimal.Decimal("95")
TIER_99 = decimal.Decimal("99")


def _reject_json_constant(val: str) -> None:
    raise ValueError(f"Disallowed JSON constant: {val}")


def _duplicate_key_pairs_hook(pairs: List[Tuple[str, Any]]) -> Dict[str, Any]:
    obj: Dict[str, Any] = {}
    for key, value in pairs:
        if key in obj:
            raise ValueError("Duplicate object key in JSON")
        obj[key] = value
    return obj


def _validate_identifier(val: Any, field_name: str, max_len: int) -> str:
    if not isinstance(val, str) or isinstance(val, bool):
        raise ValueError(f"{field_name} must be a string")
    if not val or val.strip() != val:
        raise ValueError(f"{field_name} must be a trimmed non-empty string")
    if len(val) > max_len:
        raise ValueError(f"{field_name} exceeds maximum length of {max_len} characters")
    return val


def _validate_cycle_start(val: Any) -> str:
    if not isinstance(val, str) or isinstance(val, bool):
        raise ValueError("cycle_start must be a string")
    if len(val) != 10 or val[4] != "-" or val[7] != "-":
        raise ValueError("cycle_start must strictly follow YYYY-MM-DD format")
    try:
        parsed = datetime.date.fromisoformat(val)
    except ValueError as exc:
        raise ValueError("cycle_start is not a valid calendar date") from exc
    if parsed.isoformat() != val:
        raise ValueError("cycle_start is not a valid calendar date")
    return val


def _validate_used_percentage(val: Any) -> decimal.Decimal:
    if isinstance(val, bool) or val is None:
        raise ValueError("used_percentage cannot be boolean or null")
    if isinstance(val, str):
        raise ValueError("used_percentage cannot be a string")
    if isinstance(val, decimal.Decimal):
        if val.is_nan() or val.is_infinite():
            raise ValueError("used_percentage must be a finite number")
        pct = val
    elif isinstance(val, int):
        pct = decimal.Decimal(val)
    elif isinstance(val, float):
        if math.isnan(val) or math.isinf(val):
            raise ValueError("used_percentage must be a finite number")
        pct = decimal.Decimal(str(val))
    else:
        raise ValueError("used_percentage must be a number or Decimal")

    if pct < 0:
        raise ValueError("used_percentage must be non-negative")
    return pct


def preview_alerts(payload: Dict[str, Any]) -> Dict[str, Any]:
    """Pure offline preview of quota alert evaluations.

    Evaluates quota alert thresholds against supplied statuses and alert states
    without mutating input or performing any side-effects.
    """
    if not isinstance(payload, dict):
        raise TypeError("payload must be a dictionary")

    allowed_top_keys = {"statuses", "alert_state"}
    extra_top_keys = set(payload.keys()) - allowed_top_keys
    if extra_top_keys:
        raise ValueError("Disallowed top-level key(s) in payload")

    if "statuses" not in payload:
        raise ValueError("Missing required top-level key: 'statuses'")

    raw_statuses = payload["statuses"]
    if not isinstance(raw_statuses, list):
        raise ValueError("'statuses' must be a list")
    if len(raw_statuses) > MAX_RECORDS:
        raise ValueError(f"'statuses' list exceeds maximum of {MAX_RECORDS} records")

    raw_alert_state = payload.get("alert_state", [])
    if not isinstance(raw_alert_state, list):
        raise ValueError("'alert_state' must be a list")
    if len(raw_alert_state) > MAX_RECORDS:
        raise ValueError(f"'alert_state' list exceeds maximum of {MAX_RECORDS} records")

    # Validate and index alert_state records
    state_map: Dict[Tuple[str, str, str], Dict[str, bool]] = {}
    seen_state_keys: Set[Tuple[str, str, str]] = set()

    for idx, state_rec in enumerate(raw_alert_state):
        if not isinstance(state_rec, dict):
            raise ValueError(f"alert_state record at index {idx} must be an object")

        if "router_id" not in state_rec or "interface_name" not in state_rec or "cycle_start" not in state_rec:
            raise ValueError(f"alert_state record at index {idx} missing required key(s)")

        router_id = _validate_identifier(state_rec["router_id"], "router_id", MAX_ROUTER_ID_LEN)
        interface_name = _validate_identifier(state_rec["interface_name"], "interface_name", MAX_INTERFACE_NAME_LEN)
        cycle_start = _validate_cycle_start(state_rec["cycle_start"])

        state_key = (router_id, interface_name, cycle_start)
        if state_key in seen_state_keys:
            raise ValueError("Duplicate (router_id, interface_name, cycle_start) key in alert_state")
        seen_state_keys.add(state_key)

        flags: Dict[str, bool] = {}
        for flag_name in ("alerted_80", "alerted_95", "alerted_100"):
            if flag_name in state_rec:
                flag_val = state_rec[flag_name]
                if not isinstance(flag_val, bool):
                    raise ValueError(f"{flag_name} in alert_state must be a boolean")
                flags[flag_name] = flag_val
            else:
                flags[flag_name] = False

        state_map[state_key] = flags

    # Validate and evaluate statuses records
    seen_status_keys: Set[Tuple[str, str, str]] = set()
    validated_statuses = []

    for idx, status_rec in enumerate(raw_statuses):
        if not isinstance(status_rec, dict):
            raise ValueError(f"statuses record at index {idx} must be an object")

        required_status_keys = ("router_id", "interface_name", "cycle_start", "used_percentage")
        for req_k in required_status_keys:
            if req_k not in status_rec:
                raise ValueError(f"statuses record at index {idx} missing required key '{req_k}'")

        router_id = _validate_identifier(status_rec["router_id"], "router_id", MAX_ROUTER_ID_LEN)
        interface_name = _validate_identifier(status_rec["interface_name"], "interface_name", MAX_INTERFACE_NAME_LEN)
        cycle_start = _validate_cycle_start(status_rec["cycle_start"])
        used_percentage = _validate_used_percentage(status_rec["used_percentage"])

        status_key = (router_id, interface_name, cycle_start)
        if status_key in seen_status_keys:
            raise ValueError("Duplicate (router_id, interface_name, cycle_start) key in statuses")
        seen_status_keys.add(status_key)

        validated_statuses.append({
            "router_id": router_id,
            "interface_name": interface_name,
            "cycle_start": cycle_start,
            "used_percentage": used_percentage,
            "key": status_key,
        })

    # Evaluate results preserving input order
    results = []
    would_send_count = 0

    for item in validated_statuses:
        pct = item["used_percentage"]
        st = state_map.get(item["key"], {"alerted_80": False, "alerted_95": False, "alerted_100": False})

        if pct >= TIER_99:
            if st["alerted_100"]:
                triggered_tier = None
                reason = "already_alerted"
            else:
                triggered_tier = "100"
                reason = "would_alert"
                would_send_count += 1
        elif pct >= TIER_95:
            if st["alerted_95"]:
                triggered_tier = None
                reason = "already_alerted"
            else:
                triggered_tier = "95"
                reason = "would_alert"
                would_send_count += 1
        elif pct >= TIER_80:
            if st["alerted_80"]:
                triggered_tier = None
                reason = "already_alerted"
            else:
                triggered_tier = "80"
                reason = "would_alert"
                would_send_count += 1
        else:
            triggered_tier = None
            reason = "below_threshold"

        results.append({
            "router_id": item["router_id"],
            "interface_name": item["interface_name"],
            "cycle_start": item["cycle_start"],
            "triggered_tier": triggered_tier,
            "reason": reason,
        })

    return {
        "dry_run": True,
        "side_effects": False,
        "would_send": would_send_count,
        "results": results,
    }


def _read_input(input_arg: str) -> str:
    try:
        if input_arg == "-":
            raw_bytes = sys.stdin.buffer.read(MAX_INPUT_BYTES + 1)
        else:
            path = pathlib.Path(input_arg)
            if not path.is_file():
                raise ValueError("Input file not found or not a regular file")
            with path.open("rb") as f:
                raw_bytes = f.read(MAX_INPUT_BYTES + 1)
    except OSError as exc:
        raise ValueError("Failed to read input") from exc

    if len(raw_bytes) > MAX_INPUT_BYTES:
        raise ValueError(f"Input data exceeds maximum allowed size of {MAX_INPUT_BYTES} bytes (1 MiB)")

    try:
        return raw_bytes.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise ValueError("Input data is not valid UTF-8") from exc


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Offline dry-run preview for MikroTik quota alerts based on local threshold semantics."
    )
    parser.add_argument(
        "input",
        metavar="INPUT",
        help="Path to UTF-8 JSON file containing statuses and optional alert_state, or '-' to read from stdin.",
    )

    args = parser.parse_args()

    try:
        raw_text = _read_input(args.input)
        payload = json.loads(
            raw_text,
            object_pairs_hook=_duplicate_key_pairs_hook,
            parse_float=decimal.Decimal,
            parse_constant=_reject_json_constant,
        )
        output = preview_alerts(payload)
        formatted = json.dumps(output, indent=2, ensure_ascii=False)
        output_bytes = (formatted + "\n").encode("utf-8")
        if getattr(sys.stdout, "buffer", None) is not None:
            sys.stdout.buffer.write(output_bytes)
            sys.stdout.buffer.flush()
        else:
            sys.stdout.write(formatted + "\n")
        return 0
    except (ValueError, TypeError, json.JSONDecodeError) as exc:
        sys.stderr.write(f"Validation error: {exc}\n")
        return 2
    except RecursionError:
        sys.stderr.write("Validation error: Maximum JSON nesting depth exceeded\n")
        return 2
    except OSError:
        sys.stderr.write("Validation error: Failed to read input\n")
        return 2


if __name__ == "__main__":
    sys.exit(main())
