import subprocess

cmd = [
    'ssh', '-F', r'C:\Users\Ahmed Mohamed\.ssh\config',
    'deploy-server',
    '''sudo docker exec n8n-postgres psql -U n8n -d n8n -c "UPDATE workflow_entity SET active = false WHERE id = 'mikrotik-interactive-telegram-bot';"'''
]
print(subprocess.check_output(cmd, text=True))
