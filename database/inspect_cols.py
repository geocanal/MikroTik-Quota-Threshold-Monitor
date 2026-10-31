import subprocess

def run_remote(command):
    cmd = ['ssh', '-F', r'C:\Users\Ahmed Mohamed\.ssh\config', 'deploy-server', command]
    res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    return res.stdout, res.stderr, res.returncode

print("=== Table Schemas ===")
sql = "SELECT table_name, column_name, data_type FROM information_schema.columns WHERE table_name IN ('mikrotik_wan_readings', 'mikrotik_wan_usage', 'hotspot_user_telemetry', 'mikrotik_wan_quality', 'wan_outage_events') ORDER BY table_name, ordinal_position;"
out, err, code = run_remote(f"""sudo docker exec -i app-postgres-1 psql -U campaign -d campaign_db -c "{sql}" """)
print(out)

print("=== Outage Events Sample ===")
out, err, code = run_remote("""sudo docker exec -i app-postgres-1 psql -U campaign -d campaign_db -c "SELECT * FROM wan_outage_events ORDER BY 1 DESC LIMIT 5;" """)
print(out)
if err: print("STDERR:", err)
