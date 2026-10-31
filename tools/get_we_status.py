from check_cols import run_remote

sql_quota = """
SELECT 
    interface_name, 
    provider_name, 
    quota_gb, 
    used_gb, 
    remaining_gb, 
    used_percentage, 
    renewal_date, 
    days_left, 
    daily_burn_rate_gb, 
    operational_state,
    operational_state_reason
FROM view_mikrotik_wan_quota_status
WHERE LOWER(interface_name) = 'wan2';
"""
out, err, code = run_remote(f"""sudo docker exec -i app-postgres-1 psql -U campaign -d campaign_db -c "{sql_quota}" """)
print("=== QUOTA STATUS ===")
print(out)

sql_quality = """
SELECT 
    interface_name, 
    target_host, 
    latency_ms, 
    packet_loss_percent, 
    jitter_ms, 
    status, 
    probed_at
FROM mikrotik_wan_quality
WHERE LOWER(interface_name) = 'wan2'
ORDER BY probed_at DESC
LIMIT 5;
"""
out_q, err_q, code_q = run_remote(f"""sudo docker exec -i app-postgres-1 psql -U campaign -d campaign_db -c "{sql_quality}" """)
print("=== LIVE QUALITY PROBES ===")
print(out_q)

sql_recent_usage = """
SELECT 
    date_trunc('hour', usage_at AT TIME ZONE 'Africa/Cairo') as usage_hour,
    round(sum(wan2_rx_bytes + wan2_tx_bytes)/(1024*1024)::numeric, 2) as wan2_mb
FROM mikrotik_wan_usage
WHERE usage_at >= NOW() - INTERVAL '12 hours'
GROUP BY 1
ORDER BY 1 DESC
LIMIT 6;
"""
out_u, err_u, code_u = run_remote(f"""sudo docker exec -i app-postgres-1 psql -U campaign -d campaign_db -c "{sql_recent_usage}" """)
print("=== RECENT HOURLY TRAFFIC (MB) ===")
print(out_u)
