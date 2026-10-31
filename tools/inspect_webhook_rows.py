import subprocess

cmd = [
    'ssh', '-F', r'C:\Users\Ahmed Mohamed\.ssh\config',
    'deploy-server',
    '''sudo docker exec -i n8n-postgres psql -U n8n -d n8n -c "SELECT \\"webhookPath\\", method, \\"workflowId\\" FROM webhook_entity;"'''
]
print(subprocess.check_output(cmd, text=True))
