import subprocess

cmd_ssh = [
    'ssh', '-F', r'C:\Users\Ahmed Mohamed\.ssh\config', 'deploy-server',
    r'sudo docker exec -i n8n-postgres psql -U n8n -d n8n -t -A -c "SELECT data FROM execution_data WHERE \"executionId\" = 20494;"'
]
data = subprocess.check_output(cmd_ssh).decode('utf-8')
print("DATA LENGTH:", len(data))
print(data[:1000])
