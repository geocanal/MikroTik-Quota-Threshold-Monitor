import subprocess

sql = """
UPDATE mikrotik_wan_quotas
SET support_email = 'online.support@vodafone.com'
WHERE interface_name = 'wan1';
"""

cmd = [
    'ssh', '-F', r'C:\Users\Ahmed Mohamed\.ssh\config',
    'deploy-server',
    f'''sudo docker exec app-postgres-1 psql -U campaign -d campaign_db -c "{sql}"'''
]
print(subprocess.check_output(cmd, text=True))
