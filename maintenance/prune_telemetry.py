#!/usr/bin/env python3
"""
Telemetry Retention and Housekeeping Engine for MikroTik Monitoring Stack.
Safely prunes expired high-frequency raw telemetry records in bounded chunks
to prevent PostgreSQL table locks and disk exhaustion.
"""

import os
import sys
import argparse
import datetime
import time
import psycopg2
from psycopg2.extras import RealDictCursor

# Zero-dependency .env loader
def _load_env_file():
    env_paths = [
        os.path.join(os.path.dirname(os.path.abspath(__file__)), '.env'),
        '/opt/mikrotik-monitoring/.env',
        '.env'
    ]
    for p in env_paths:
        if os.path.isfile(p):
            try:
                with open(p, 'r', encoding='utf-8') as f:
                    for line in f:
                        line = line.strip()
                        if not line or line.startswith('#') or '=' not in line:
                            continue
                        k, v = line.split('=', 1)
                        k = k.strip()
                        v = v.strip().strip('"').strip("'")
                        if k and k not in os.environ:
                            os.environ[k] = v
                break
            except Exception:
                pass

_load_env_file()

def get_db_connection(host=None, port=None, dbname=None, user=None, password=None):
    h = host or os.getenv("DB_HOST", "127.0.0.1")
    p = port or int(os.getenv("DB_PORT", "55432"))
    d = dbname or os.getenv("DB_NAME", "campaign_db")
    u = user or os.getenv("DB_USER", "campaign")
    pw = password or os.getenv("DB_PASS", os.getenv("DB_PASSWORD", ""))
    
    return psycopg2.connect(
        host=h,
        port=p,
        dbname=d,
        user=u,
        password=pw
    )

def calculate_cutoffs(now, quality_days=14, hotspot_days=30, readings_days=60):
    """Calculates timezone-aware cutoff datetimes."""
    return {
        "mikrotik_wan_quality": {
            "time_col": "probed_at",
            "cutoff": now - datetime.timedelta(days=quality_days),
            "days": quality_days
        },
        "hotspot_user_telemetry": {
            "time_col": "recorded_at",
            "cutoff": now - datetime.timedelta(days=hotspot_days),
            "days": hotspot_days
        },
        "mikrotik_wan_readings": {
            "time_col": "received_at",
            "cutoff": now - datetime.timedelta(days=readings_days),
            "days": readings_days
        }
    }

def count_eligible_rows(cur, table, time_col, cutoff):
    """Counts expired records eligible for pruning."""
    query = f"SELECT COUNT(*) AS cnt FROM {table} WHERE {time_col} < %s;"
    cur.execute(query, (cutoff,))
    row = cur.fetchone()
    return row["cnt"] if isinstance(row, dict) else row[0]

def prune_table_chunked(conn, table, time_col, cutoff, batch_size=5000, max_deletes=None):
    """
    Deletes records in bounded chunks to prevent lock contention.
    Returns total rows deleted.
    """
    total_deleted = 0
    delete_sql = f"""
        DELETE FROM {table}
        WHERE id IN (
            SELECT id FROM {table}
            WHERE {time_col} < %s
            ORDER BY id ASC
            LIMIT %s
        );
    """
    while True:
        cur = conn.cursor()
        current_limit = batch_size
        if max_deletes and (total_deleted + current_limit > max_deletes):
            current_limit = max_deletes - total_deleted
            if current_limit <= 0:
                break

        cur.execute(delete_sql, (cutoff, current_limit))
        deleted = cur.rowcount
        conn.commit()
        cur.close()

        total_deleted += deleted
        if deleted < current_limit:
            break
        # Yield brief moment for concurrent read/write queries
        time.sleep(0.05)

    return total_deleted

def run_retention_plan(conn, cutoffs, batch_size=5000, dry_run=True, max_deletes=None):
    """Executes or dry-runs retention plan across all target tables."""
    results = {}
    for table, meta in cutoffs.items():
        time_col = meta["time_col"]
        cutoff = meta["cutoff"]
        days = meta["days"]

        cur = conn.cursor(cursor_factory=RealDictCursor)
        eligible = count_eligible_rows(cur, table, time_col, cutoff)
        cur.close()

        if dry_run:
            results[table] = {
                "days_retained": days,
                "cutoff": str(cutoff),
                "eligible_count": eligible,
                "deleted_count": 0,
                "status": "DRY_RUN_PREVIEW"
            }
        else:
            if eligible > 0:
                deleted = prune_table_chunked(conn, table, time_col, cutoff, batch_size, max_deletes)
            else:
                deleted = 0
            results[table] = {
                "days_retained": days,
                "cutoff": str(cutoff),
                "eligible_count": eligible,
                "deleted_count": deleted,
                "status": "PRUNED"
            }

    return results

def main():
    parser = argparse.ArgumentParser(
        description="MikroTik Telemetry Retention & Chunked Pruning Utility"
    )
    parser.add_argument("--quality-days", type=int, default=14, help="Retention period for WAN quality probes (default: 14 days)")
    parser.add_argument("--hotspot-days", type=int, default=30, help="Retention period for Hotspot user sessions (default: 30 days)")
    parser.add_argument("--readings-days", type=int, default=60, help="Retention period for raw WAN readings (default: 60 days)")
    parser.add_argument("--batch-size", type=int, default=5000, help="Batch limit per delete transaction (default: 5000)")
    parser.add_argument("--max-deletes", type=int, default=None, help="Maximum total deletes across a run")
    parser.add_argument("--dry-run", action="store_true", default=False, help="Preview eligible rows without deleting")
    parser.add_argument("--commit", action="store_true", default=False, help="Confirm execution of actual deletions")

    args = parser.parse_args()

    # Default to dry-run unless --commit is explicitly passed
    is_dry_run = args.dry_run or not args.commit

    now = datetime.datetime.now(datetime.timezone.utc)
    cutoffs = calculate_cutoffs(
        now=now,
        quality_days=args.quality_days,
        hotspot_days=args.hotspot_days,
        readings_days=args.readings_days
    )

    mode_label = "DRY-RUN (No changes applied)" if is_dry_run else "LIVE PRUNING"
    print("=" * 70)
    print(f" MikroTik Telemetry Retention Engine — {mode_label}")
    print(f" Execution Timestamp (UTC): {now.isoformat()}")
    print("=" * 70)

    try:
        conn = get_db_connection()
    except Exception as e:
        print(f"❌ Database connection failed: {e}", file=sys.stderr)
        sys.exit(1)

    try:
        results = run_retention_plan(
            conn=conn,
            cutoffs=cutoffs,
            batch_size=args.batch_size,
            dry_run=is_dry_run,
            max_deletes=args.max_deletes
        )

        print("\n| Table Name | Retention (Days) | Cutoff Threshold | Eligible | Deleted | Status |")
        print("|" + "-" * 26 + "|" + "-" * 18 + "|" + "-" * 22 + "|" + "-" * 10 + "|" + "-" * 9 + "|" + "-" * 17 + "|")
        for tbl, res in results.items():
            print(f"| {tbl:<24} | {res['days_retained']:>16} | {res['cutoff'][:19]:<20} | {res['eligible_count']:>8} | {res['deleted_count']:>7} | {res['status']:<15} |")

        if is_dry_run:
            print("\n💡 Tip: To apply these deletions to the live database, run with --commit.")
        else:
            print("\n✅ Retention policy completed successfully.")
    finally:
        conn.close()

if __name__ == "__main__":
    main()
