import subprocess

def run_remote(command):
    cmd = ['ssh', '-F', r'C:\Users\Ahmed Mohamed\.ssh\config', 'deploy-server', command]
    res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    return res.stdout, res.stderr, res.returncode

print("=== Quality Table Columns ===")
sql = "SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'mikrotik_wan_quality' ORDER BY ordinal_position;"
out, err, code = run_remote(f"""sudo docker exec app-postgres-1 psql -U campaign -d campaign_db -c "{sql}" """)
print(out)

print("=== Outage Table Columns ===")
sql2 = "SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'wan_outage_events' ORDER BY ordinal_position;"
out2, err2, code2 = run_remote(f"""sudo docker exec app-postgres-1 psql -U campaign -d campaign_db -c "{sql2}" """)
print(out2)
