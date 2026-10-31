#!/usr/bin/env python3
"""
Unit tests for prune_telemetry.py
Runs completely offline using mock cursor/connection to verify retention logic,
boundary conditions, and batch chunking.
"""

import unittest
import datetime
from unittest.mock import MagicMock
import prune_telemetry

class TestPruneTelemetry(unittest.TestCase):

    def test_calculate_cutoffs(self):
        fixed_now = datetime.datetime(2026, 10, 31, 12, 0, 0, tzinfo=datetime.timezone.utc)
        cutoffs = prune_telemetry.calculate_cutoffs(
            now=fixed_now,
            quality_days=14,
            hotspot_days=30,
            readings_days=60
        )
        
        self.assertIn("mikrotik_wan_quality", cutoffs)
        self.assertIn("hotspot_user_telemetry", cutoffs)
        self.assertIn("mikrotik_wan_readings", cutoffs)
        
        self.assertEqual(cutoffs["mikrotik_wan_quality"]["cutoff"], datetime.datetime(2026, 10, 17, 12, 0, 0, tzinfo=datetime.timezone.utc))
        self.assertEqual(cutoffs["hotspot_user_telemetry"]["cutoff"], datetime.datetime(2026, 10, 1, 12, 0, 0, tzinfo=datetime.timezone.utc))
        self.assertEqual(cutoffs["mikrotik_wan_readings"]["cutoff"], datetime.datetime(2026, 9, 1, 12, 0, 0, tzinfo=datetime.timezone.utc))

    def test_count_eligible_rows_dict(self):
        mock_cur = MagicMock()
        mock_cur.fetchone.return_value = {"cnt": 1500}
        count = prune_telemetry.count_eligible_rows(mock_cur, "mikrotik_wan_quality", "probed_at", datetime.datetime.now())
        self.assertEqual(count, 1500)

    def test_count_eligible_rows_tuple(self):
        mock_cur = MagicMock()
        mock_cur.fetchone.return_value = (4200,)
        count = prune_telemetry.count_eligible_rows(mock_cur, "hotspot_user_telemetry", "recorded_at", datetime.datetime.now())
        self.assertEqual(count, 4200)

    def test_prune_table_chunked_single_batch(self):
        mock_conn = MagicMock()
        mock_cur = MagicMock()
        mock_conn.cursor.return_value = mock_cur
        mock_cur.rowcount = 120  # less than batch size 5000 -> terminates loop
        
        cutoff = datetime.datetime.now()
        deleted = prune_telemetry.prune_table_chunked(
            mock_conn, "mikrotik_wan_quality", "probed_at", cutoff, batch_size=5000
        )
        self.assertEqual(deleted, 120)
        mock_conn.commit.assert_called_once()

    def test_prune_table_chunked_multi_batch(self):
        mock_conn = MagicMock()
        mock_cur1 = MagicMock()
        mock_cur1.rowcount = 5000  # full batch
        mock_cur2 = MagicMock()
        mock_cur2.rowcount = 2300  # last batch
        mock_conn.cursor.side_effect = [mock_cur1, mock_cur2]

        cutoff = datetime.datetime.now()
        deleted = prune_telemetry.prune_table_chunked(
            mock_conn, "hotspot_user_telemetry", "recorded_at", cutoff, batch_size=5000
        )
        self.assertEqual(deleted, 7300)
        self.assertEqual(mock_conn.commit.call_count, 2)

    def test_run_retention_plan_dry_run(self):
        mock_conn = MagicMock()
        mock_cur = MagicMock()
        mock_conn.cursor.return_value = mock_cur
        mock_cur.fetchone.return_value = {"cnt": 250}

        fixed_now = datetime.datetime(2026, 10, 31, 12, 0, 0, tzinfo=datetime.timezone.utc)
        cutoffs = prune_telemetry.calculate_cutoffs(now=fixed_now)

        results = prune_telemetry.run_retention_plan(
            conn=mock_conn,
            cutoffs=cutoffs,
            dry_run=True
        )

        for tbl in ["mikrotik_wan_quality", "hotspot_user_telemetry", "mikrotik_wan_readings"]:
            self.assertEqual(results[tbl]["status"], "DRY_RUN_PREVIEW")
            self.assertEqual(results[tbl]["eligible_count"], 250)
            self.assertEqual(results[tbl]["deleted_count"], 0)

    def test_run_retention_plan_live_commit(self):
        mock_conn = MagicMock()
        mock_cur = MagicMock()
        mock_cur.rowcount = 100
        mock_cur.fetchone.return_value = {"cnt": 100}
        mock_conn.cursor.return_value = mock_cur

        fixed_now = datetime.datetime(2026, 10, 31, 12, 0, 0, tzinfo=datetime.timezone.utc)
        cutoffs = prune_telemetry.calculate_cutoffs(now=fixed_now)

        results = prune_telemetry.run_retention_plan(
            conn=mock_conn,
            cutoffs=cutoffs,
            dry_run=False
        )

        for tbl in ["mikrotik_wan_quality", "hotspot_user_telemetry", "mikrotik_wan_readings"]:
            self.assertEqual(results[tbl]["status"], "PRUNED")
            self.assertEqual(results[tbl]["eligible_count"], 100)
            self.assertEqual(results[tbl]["deleted_count"], 100)

if __name__ == "__main__":
    unittest.main()
