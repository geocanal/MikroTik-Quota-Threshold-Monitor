import subprocess

sql = """
SELECT 
    usage_date,
    usage_hour,
    wan1_bytes / (1024*1024) as wan1_mb,
    wan2_bytes / (1024*1024) as wan2_mb
FROM (
    SELECT 
        (usage_at AT TIME ZONE 'Africa/Cairo')::date as usage_date,
        EXTRACT(HOUR FROM usage_at AT TIME ZONE 'Africa/Cairo') as usage_hour,
        SUM(wan1_rx_bytes + wan1_tx_bytes) as wan1_bytes,
        SUM(wan2_rx_bytes + wan2_tx_bytes) as wan2_bytes
    FROM mikrotik_wan_usage
    WHERE (usage_at AT TIME ZONE 'Africa/Cairo')::date = '2026-09-28'
    GROUP BY 1, 2
) t
ORDER BY usage_hour ASC;
"""

cmd = [
    'ssh', '-F', r'C:\Users\Ahmed Mohamed\.ssh\config',
    'deploy-server',
    f'''sudo docker exec app-postgres-1 psql -U campaign -d campaign_db -c "{sql}"'''
]

print(subprocess.check_output(cmd, text=True))
