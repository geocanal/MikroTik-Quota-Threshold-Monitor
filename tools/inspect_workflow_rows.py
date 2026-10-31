import json
import subprocess

cmd = ["sudo", "docker", "exec", "-i", "n8n-postgres", "psql", "-U", "n8n", "-d", "n8n", "-t", "-A", "-c", "SELECT row_to_json(w) FROM (SELECT id, name, active, \"versionId\" FROM workflow_entity WHERE id IN ('PPAQLTX0UUv4OnZl', 'mikrotik-interactive-telegram-bot')) w;"]
raw = subprocess.check_output(cmd)
for line in raw.decode("utf-8").strip().split("\n"):
    if line:
        print(json.loads(line))
