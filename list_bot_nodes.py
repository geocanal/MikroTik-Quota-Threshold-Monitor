import json
import subprocess

cmd = ["sudo", "docker", "exec", "-i", "n8n-postgres", "psql", "-U", "n8n", "-d", "n8n", "-t", "-A", "-c", "SELECT nodes FROM workflow_entity WHERE id = 'mikrotik-interactive-telegram-bot';"]
raw = subprocess.check_output(cmd)
nodes = json.loads(raw.decode("utf-8"))
for n in nodes:
    print(n.get("name"), "-->", n.get("type"))
