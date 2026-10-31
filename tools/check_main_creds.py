import subprocess
import json

cmd_ssh = [
    'ssh', '-F', r'C:\Users\Ahmed Mohamed\.ssh\config', 'deploy-server',
    'sudo docker exec -i n8n-postgres psql -U n8n -d n8n -t -A -c "SELECT nodes FROM workflow_entity WHERE id = \'PPAQLTX0UUv4OnZl\';"'
]
raw = subprocess.check_output(cmd_ssh).decode('utf-8')
nodes = json.loads(raw)
for n in nodes:
    if 'postgres' in n.get('type', ''):
        print("NODE:", n.get('name'), "CREDENTIALS:", n.get('credentials'))
