import subprocess

def run_remote(command):
    cmd = ['ssh', '-F', r'C:\Users\Ahmed Mohamed\.ssh\config', 'deploy-server', command]
    res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    return res.stdout, res.stderr, res.returncode

print("=== Check wan_control_pbr.rsc ===")
with open('wan_control_pbr.rsc', 'r', encoding='utf-8') as f:
    lines = f.readlines()
    print("Total lines in wan_control_pbr.rsc:", len(lines))
    # look for comments or triggers
    for i, line in enumerate(lines[:30]):
        print(f"{i+1}: {line.strip()}")

print("\n=== Check Alerting Config in n8n Workflows ===")
# Query workflow_entity for telegram chat id and email recipient
sql_wf = """
SELECT id, name, active, nodes::text LIKE '%123456789%' as has_telegram_chat, nodes::text LIKE '%online.support@vodafone.com%' as has_vodafone_email
FROM workflow_entity WHERE name ILIKE '%MikroTik%';
"""
out, err, code = run_remote(f"""sudo docker exec -i n8n-postgres psql -U n8n -d n8n -c "{sql_wf}" """)
print(out)

print("\n=== Check DB table mikrotik_wan_recipients or similar ===")
sql_recipients = """
SELECT table_name FROM information_schema.tables WHERE table_schema='public' AND (table_name ILIKE '%recipient%' OR table_name ILIKE '%alert%' OR table_name ILIKE '%contact%');
"""
out, err, code = run_remote(f"""sudo docker exec -i app-postgres-1 psql -U campaign -d campaign_db -c "{sql_recipients}" """)
print(out)
