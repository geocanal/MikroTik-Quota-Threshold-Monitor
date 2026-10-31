"""Unit tests for offline quota alert dry-run utility."""

import decimal
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

# Add directory to sys.path
sys.path.insert(0, str(Path(__file__).parent))
from quota_alert_dry_run import preview_alerts


class TestPreviewAlerts(unittest.TestCase):
    def test_basic_below_threshold(self):
        payload = {
            "statuses": [
                {
                    "router_id": "rt-1",
                    "interface_name": "ether1",
                    "cycle_start": "2026-10-01",
                    "used_percentage": 50.0,
                }
            ],
            "alert_state": [],
        }
        res = preview_alerts(payload)
        self.assertTrue(res["dry_run"])
        self.assertFalse(res["side_effects"])
        self.assertEqual(res["would_send"], 0)
        self.assertEqual(res["results"][0]["triggered_tier"], None)
        self.assertEqual(res["results"][0]["reason"], "below_threshold")

    def test_tier_80_would_alert_and_already_alerted(self):
        payload = {
            "statuses": [
                {
                    "router_id": "rt-1",
                    "interface_name": "ether1",
                    "cycle_start": "2026-10-01",
                    "used_percentage": 80.0,
                }
            ]
        }
        res = preview_alerts(payload)
        self.assertEqual(res["would_send"], 1)
        self.assertEqual(res["results"][0]["triggered_tier"], "80")
        self.assertEqual(res["results"][0]["reason"], "would_alert")

        # Now with alerted_80=True
        payload["alert_state"] = [
            {
                "router_id": "rt-1",
                "interface_name": "ether1",
                "cycle_start": "2026-10-01",
                "alerted_80": True,
            }
        ]
        res2 = preview_alerts(payload)
        self.assertEqual(res2["would_send"], 0)
        self.assertIsNone(res2["results"][0]["triggered_tier"])
        self.assertEqual(res2["results"][0]["reason"], "already_alerted")

    def test_tier_95_and_99_thresholds(self):
        payload = {
            "statuses": [
                {
                    "router_id": "rt-1",
                    "interface_name": "ether1",
                    "cycle_start": "2026-10-01",
                    "used_percentage": decimal.Decimal("98.999999999999999999"),
                },
                {
                    "router_id": "rt-2",
                    "interface_name": "ether2",
                    "cycle_start": "2026-10-01",
                    "used_percentage": decimal.Decimal("99.0"),
                },
            ]
        }
        res = preview_alerts(payload)
        self.assertEqual(res["would_send"], 2)
        self.assertEqual(res["results"][0]["triggered_tier"], "95")
        self.assertEqual(res["results"][1]["triggered_tier"], "100")

    def test_no_fallback_to_lower_tiers(self):
        # When tier 100 is triggered and alerted_100 is True, do not fall back to 95 even if alerted_95 is False
        payload = {
            "statuses": [
                {
                    "router_id": "rt-1",
                    "interface_name": "ether1",
                    "cycle_start": "2026-10-01",
                    "used_percentage": 99.5,
                }
            ],
            "alert_state": [
                {
                    "router_id": "rt-1",
                    "interface_name": "ether1",
                    "cycle_start": "2026-10-01",
                    "alerted_80": False,
                    "alerted_95": False,
                    "alerted_100": True,
                }
            ],
        }
        res = preview_alerts(payload)
        self.assertEqual(res["would_send"], 0)
        self.assertIsNone(res["results"][0]["triggered_tier"])
        self.assertEqual(res["results"][0]["reason"], "already_alerted")

    def test_different_cycle_not_suppressed(self):
        payload = {
            "statuses": [
                {
                    "router_id": "rt-1",
                    "interface_name": "ether1",
                    "cycle_start": "2026-10-01",
                    "used_percentage": 85.0,
                }
            ],
            "alert_state": [
                {
                    "router_id": "rt-1",
                    "interface_name": "ether1",
                    "cycle_start": "2026-09-01",
                    "alerted_80": True,
                }
            ],
        }
        res = preview_alerts(payload)
        self.assertEqual(res["would_send"], 1)
        self.assertEqual(res["results"][0]["triggered_tier"], "80")
        self.assertEqual(res["results"][0]["reason"], "would_alert")

    def test_invalid_payload_validations(self):
        # Non-dict
        with self.assertRaises(TypeError):
            preview_alerts(["not a dict"])

        # Unknown top-level key
        with self.assertRaises(ValueError):
            preview_alerts({"statuses": [], "extra_key": 123})

        # Duplicate status key
        with self.assertRaises(ValueError):
            preview_alerts({
                "statuses": [
                    {"router_id": "r1", "interface_name": "e1", "cycle_start": "2026-10-01", "used_percentage": 50},
                    {"router_id": "r1", "interface_name": "e1", "cycle_start": "2026-10-01", "used_percentage": 60},
                ]
            })

        # Negative used_percentage
        with self.assertRaises(ValueError):
            preview_alerts({
                "statuses": [
                    {"router_id": "r1", "interface_name": "e1", "cycle_start": "2026-10-01", "used_percentage": -1.0}
                ]
            })

        # Invalid calendar date
        with self.assertRaises(ValueError):
            preview_alerts({
                "statuses": [
                    {"router_id": "r1", "interface_name": "e1", "cycle_start": "2026-02-29", "used_percentage": 50}
                ]
            })


class TestCli(unittest.TestCase):
    def test_cli_help(self):
        script = Path(__file__).parent / "quota_alert_dry_run.py"
        proc = subprocess.run([sys.executable, str(script), "--help"], capture_output=True, text=True)
        self.assertEqual(proc.returncode, 0)
        self.assertIn("usage:", proc.stdout.lower())

    def test_cli_stdin(self):
        script = Path(__file__).parent / "quota_alert_dry_run.py"
        input_data = json.dumps({
            "statuses": [
                {
                    "router_id": "rt-1",
                    "interface_name": "ether1",
                    "cycle_start": "2026-10-01",
                    "used_percentage": 82.5,
                }
            ]
        })
        proc = subprocess.run([sys.executable, str(script), "-"], input=input_data, capture_output=True, text=True)
        self.assertEqual(proc.returncode, 0)
        out = json.loads(proc.stdout)
        self.assertEqual(out["would_send"], 1)

    def test_cli_invalid_input_exit_2(self):
        script = Path(__file__).parent / "quota_alert_dry_run.py"
        proc = subprocess.run([sys.executable, str(script), "-"], input="not json", capture_output=True, text=True)
        self.assertEqual(proc.returncode, 2)
        self.assertEqual(proc.stdout, "")
        self.assertIn("Validation error", proc.stderr)

    def test_cli_missing_file_safe_stderr(self):
        script = Path(__file__).parent / "quota_alert_dry_run.py"
        secret_path = "non_existent_secret_file_path_12345.json"
        proc = subprocess.run([sys.executable, str(script), secret_path], capture_output=True, text=True)
        self.assertEqual(proc.returncode, 2)
        self.assertEqual(proc.stdout, "")
        self.assertNotIn(secret_path, proc.stderr)
        self.assertIn("Validation error", proc.stderr)

    def test_cli_disallowed_top_level_key_safe_stderr(self):
        script = Path(__file__).parent / "quota_alert_dry_run.py"
        secret_key = "super_secret_auth_token_key"
        input_data = json.dumps({"statuses": [], secret_key: "value"})
        proc = subprocess.run([sys.executable, str(script), "-"], input=input_data, capture_output=True, text=True)
        self.assertEqual(proc.returncode, 2)
        self.assertEqual(proc.stdout, "")
        self.assertNotIn(secret_key, proc.stderr)
        self.assertIn("Validation error", proc.stderr)

    def test_cli_ascii_encoding_with_arabic(self):
        import os
        script = Path(__file__).parent / "quota_alert_dry_run.py"
        input_data = json.dumps({
            "statuses": [
                {
                    "router_id": "روتر-القاهرة-1",
                    "interface_name": "ether1",
                    "cycle_start": "2026-10-01",
                    "used_percentage": 82.5,
                }
            ]
        })
        env = dict(os.environ)
        env["PYTHONIOENCODING"] = "ascii"
        proc = subprocess.run(
            [sys.executable, str(script), "-"],
            input=input_data.encode("utf-8"),
            capture_output=True,
            env=env,
        )
        self.assertEqual(proc.returncode, 0)
        output_str = proc.stdout.decode("utf-8")
        self.assertIn("روتر-القاهرة-1", output_str)
        out = json.loads(output_str)
        self.assertEqual(out["would_send"], 1)

    def test_cli_deeply_nested_json_recursion_error(self):
        script = Path(__file__).parent / "quota_alert_dry_run.py"
        nested = "[" * 3000 + "]" * 3000
        proc = subprocess.run([sys.executable, str(script), "-"], input=nested, capture_output=True, text=True)
        self.assertEqual(proc.returncode, 2)
        self.assertEqual(proc.stdout, "")
        self.assertIn("Validation error", proc.stderr)


if __name__ == "__main__":
    unittest.main()
