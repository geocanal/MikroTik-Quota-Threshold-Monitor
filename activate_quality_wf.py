import subprocess

sql = '''
UPDATE workflow_entity
SET "activeVersionId" = "versionId",
    "triggerCount" = 1
WHERE id = 'mikrotik-wan-quality-monitor';
'''

cmd = [
    'ssh', '-F', r'C:\Users\Ahmed Mohamed\.ssh\config',
    'deploy-server',
    f'''sudo docker exec n8n-postgres psql -U n8n -d n8n -c '{sql}' && sudo docker restart n8n'''
]
print(subprocess.check_output(cmd, text=True))
