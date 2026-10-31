import subprocess

def run_remote(command):
    cmd = ['ssh', '-F', r'C:\Users\Ahmed Mohamed\.ssh\config', 'deploy-server', command]
    res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    return res.stdout, res.stderr, res.returncode

print("=== Telemetry Counts and Latest Timestamps ===")
telemetry_sql = """
SELECT 'mikrotik_wan_readings' AS table_name, count(*) AS total_rows, max(received_at) AS latest_timestamp FROM mikrotik_wan_readings
UNION ALL
SELECT 'mikrotik_wan_usage', count(*), max(usage_at) FROM mikrotik_wan_usage
UNION ALL
SELECT 'hotspot_user_telemetry', count(*), max(recorded_at) FROM hotspot_user_telemetry
UNION ALL
SELECT 'mikrotik_wan_quality', count(*), max(probed_at) FROM mikrotik_wan_quality
UNION ALL
SELECT 'wan_outage_events', count(*), max(started_at) FROM wan_outage_events
UNION ALL
SELECT 'wan_incident_state', count(*), max(updated_at) FROM wan_incident_state;
"""
out, err, code = run_remote(f"""sudo docker exec -i app-postgres-1 psql -U campaign -d campaign_db -c "{telemetry_sql}" """)
print(out)
if err: print("STDERR:", err)

print("=== Check wan_usage anomalies ===")
usage_anomaly_sql = """
SELECT 
    count(*) filter (where wan1_rx_bytes < 0 or wan1_tx_bytes < 0 or wan2_rx_bytes < 0 or wan2_tx_bytes < 0 or total_bytes < 0) as negative_deltas,
    count(*) filter (where counter_reset = true) as counter_resets,
    count(*) filter (where wan1_rx_bytes is null or wan1_tx_bytes is null or wan2_rx_bytes is null or wan2_tx_bytes is null or total_bytes is null) as null_bytes,
    count(*) filter (where reading_id is null) as null_reading_id
FROM mikrotik_wan_usage;
"""
out, err, code = run_remote(f"""sudo docker exec -i app-postgres-1 psql -U campaign -d campaign_db -c "{usage_anomaly_sql}" """)
print(out)
if err: print("STDERR:", err)

print("=== Check latest 5 records in each telemetry table ===")
for tbl, col in [('mikrotik_wan_readings', 'received_at'), ('mikrotik_wan_usage', 'usage_at'), ('hotspot_user_telemetry', 'recorded_at'), ('mikrotik_wan_quality', 'probed_at')]:
    print(f"--- Top 2 latest from {tbl} ---")
    out, _, _ = run_remote(f"""sudo docker exec -i app-postgres-1 psql -U campaign -d campaign_db -c "SELECT * FROM {tbl} ORDER BY {col} DESC LIMIT 2;" """)
    print(out)
