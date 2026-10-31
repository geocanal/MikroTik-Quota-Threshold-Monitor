import subprocess

def run_remote(command):
    cmd = ['ssh', '-F', r'C:\Users\Ahmed Mohamed\.ssh\config', 'deploy-server', command]
    res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    return res.stdout, res.stderr, res.returncode

print("=== 1. n8n Workflows ===")
out, err, code = run_remote("""sudo docker exec -i n8n-postgres psql -U n8n -d n8n -c "SELECT id, name, active FROM workflow_entity WHERE name ILIKE '%MikroTik%';" """)
print(out)
if err: print("STDERR:", err)

print("=== 2. Registered Webhooks ===")
out, err, code = run_remote("""sudo docker exec -i n8n-postgres psql -U n8n -d n8n -c "SELECT \\"webhookPath\\", method, \\"workflowId\\" FROM webhook_entity WHERE \\"webhookPath\\" ILIKE '%mikrotik%';" """)
print(out)
if err: print("STDERR:", err)

print("=== 3. All registered webhooks in webhook_entity ===")
out, err, code = run_remote("""sudo docker exec -i n8n-postgres psql -U n8n -d n8n -c "SELECT \\"webhookPath\\", method, \\"workflowId\\" FROM webhook_entity;" """)
print(out)
if err: print("STDERR:", err)

print("=== 4. n8n healthz check ===")
out, err, code = run_remote("""curl -i -s http://127.0.0.1:5678/healthz""")
print(out)
if err: print("STDERR:", err)

print("=== 5. Telemetry Freshness & Record Counts ===")
telemetry_sql = """
SELECT 'mikrotik_wan_readings' AS table_name, count(*) AS total_rows, max(timestamp) AS latest_timestamp FROM mikrotik_wan_readings
UNION ALL
SELECT 'mikrotik_wan_usage', count(*), max(timestamp) FROM mikrotik_wan_usage
UNION ALL
SELECT 'hotspot_user_telemetry', count(*), max(timestamp) FROM hotspot_user_telemetry
UNION ALL
SELECT 'mikrotik_wan_quality', count(*), max(timestamp) FROM mikrotik_wan_quality
UNION ALL
SELECT 'wan_outage_events', count(*), max(start_time) FROM wan_outage_events
UNION ALL
SELECT 'wan_incident_state', count(*), max(updated_at) FROM wan_incident_state;
"""
out, err, code = run_remote(f"""sudo docker exec -i app-postgres-1 psql -U campaign -d campaign_db -c "{telemetry_sql}" """)
print(out)
if err: print("STDERR:", err)

print("=== 6. Outage Events Details ===")
out, err, code = run_remote("""sudo docker exec -i app-postgres-1 psql -U campaign -d campaign_db -c "SELECT * FROM wan_outage_events ORDER BY start_time DESC LIMIT 10;" """)
print(out)

print("=== 7. WAN Incident State ===")
out, err, code = run_remote("""sudo docker exec -i app-postgres-1 psql -U campaign -d campaign_db -c "SELECT * FROM wan_incident_state;" """)
print(out)

print("=== 8. Foreign Key & Integrity Check (mikrotik_wan_readings vs mikrotik_wan_usage) ===")
fk_sql = """
SELECT count(*) AS orphan_usage_records 
FROM mikrotik_wan_usage u 
LEFT JOIN mikrotik_wan_readings r ON u.reading_id = r.id 
WHERE r.id IS NULL;
"""
out, err, code = run_remote(f"""sudo docker exec -i app-postgres-1 psql -U campaign -d campaign_db -c "{fk_sql}" """)
print(out)

print("=== 9. Usage Anomalies Check (negative deltas, counter reset, nulls) ===")
anomaly_sql = """
SELECT 
    count(*) filter (where delta_rx_bytes < 0 or delta_tx_bytes < 0) as negative_deltas,
    count(*) filter (where is_counter_reset = true) as counter_resets,
    count(*) filter (where rx_bytes is null or tx_bytes is null or delta_rx_bytes is null or delta_tx_bytes is null) as null_byte_fields,
    count(*) filter (where reading_id is null) as null_reading_id
FROM mikrotik_wan_usage;
"""
out, err, code = run_remote(f"""sudo docker exec -i app-postgres-1 psql -U campaign -d campaign_db -c "{anomaly_sql}" """)
print(out)

print("=== 10. View Quota Status Check ===")
out, err, code = run_remote("""sudo docker exec -i app-postgres-1 psql -U campaign -d campaign_db -c "SELECT * FROM view_mikrotik_wan_quota_status;" """)
print(out)
