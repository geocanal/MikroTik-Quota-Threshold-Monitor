from check_cols import run_remote

sql = """
UPDATE billing_cycles
SET initial_offset_gb = -47.50,
    metadata = jsonb_set(COALESCE(metadata, '{}'::jsonb), '{offset_calibrated_at}', to_jsonb(NOW()::text))
WHERE router_id = 'home-router-01' AND LOWER(interface_name) = 'wan1' AND cycle_start = '2026-09-19';
"""
out, err, code = run_remote(f"""sudo docker exec -i app-postgres-1 psql -U campaign -d campaign_db -c "{sql}" """)
print("UPDATE OFFSET:", out)

out_v, err_v, code_v = run_remote("""sudo docker exec -i app-postgres-1 psql -U campaign -d campaign_db -c "SELECT interface_name, quota_gb, used_gb, remaining_gb, used_percentage FROM view_mikrotik_wan_quota_status;" """)
print("VIEW STATUS:")
print(out_v)
