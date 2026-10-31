import subprocess

sql = """
SELECT 
    received_at AT TIME ZONE 'Africa/Cairo' as reading_cairo,
    uptime,
    wan1_rx, wan1_tx,
    wan2_rx, wan2_tx
FROM mikrotik_wan_readings
WHERE (received_at AT TIME ZONE 'Africa/Cairo')::date = '2026-09-28'
  AND (received_at AT TIME ZONE 'Africa/Cairo')::time < '13:50:00'
ORDER BY received_at ASC;
"""

cmd = [
    'ssh', '-F', r'C:\Users\Ahmed Mohamed\.ssh\config',
    'deploy-server',
    f'''sudo docker exec app-postgres-1 psql -U campaign -d campaign_db -c "{sql}"'''
]

print(subprocess.check_output(cmd, text=True))
