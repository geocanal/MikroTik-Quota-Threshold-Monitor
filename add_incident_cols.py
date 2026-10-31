import subprocess

sql = """
ALTER TABLE wan_incident_state ADD COLUMN IF NOT EXISTS is_isolated BOOLEAN DEFAULT FALSE;
ALTER TABLE wan_incident_state ADD COLUMN IF NOT EXISTS isolated_reason VARCHAR(128);
ALTER TABLE wan_incident_state ADD COLUMN IF NOT EXISTS isolated_at TIMESTAMPTZ;
ALTER TABLE wan_incident_state ADD COLUMN IF NOT EXISTS speed_limit_rx VARCHAR(32);
ALTER TABLE wan_incident_state ADD COLUMN IF NOT EXISTS speed_limit_tx VARCHAR(32);
"""

cmd = [
    'ssh', '-F', r'C:\Users\Ahmed Mohamed\.ssh\config',
    'deploy-server',
    f'''sudo docker exec app-postgres-1 psql -U campaign -d campaign_db -c "{sql}"'''
]
print(subprocess.check_output(cmd, text=True))
