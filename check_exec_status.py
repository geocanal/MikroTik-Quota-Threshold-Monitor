import subprocess

cmd_ssh = [
    'ssh', '-F', r'C:\Users\Ahmed Mohamed\.ssh\config', 'deploy-server',
    r'sudo docker exec -i n8n-postgres psql -U n8n -d n8n -t -A -c "SELECT \"workflowId\", status, id FROM execution_entity ORDER BY id DESC LIMIT 10;"'
]
print(subprocess.check_output(cmd_ssh).decode('utf-8'))
