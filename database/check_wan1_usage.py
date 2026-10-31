from inspect_cols import run_remote

out, err, code = run_remote('''sudo docker exec -i app-postgres-1 psql -U campaign -d campaign_db -c "SELECT round(sum(wan1_rx_bytes + wan1_tx_bytes)/(1024*1024*1024)::numeric, 2) as wan1_cycle_gb FROM mikrotik_wan_usage WHERE usage_at >= '2026-09-19';" ''')
print("CYCLE GB:", out)
