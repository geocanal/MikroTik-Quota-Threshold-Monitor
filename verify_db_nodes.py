import json
import subprocess

cmd = ["sudo", "docker", "exec", "-i", "n8n-postgres", "psql", "-U", "n8n", "-d", "n8n", "-t", "-A", "-c", "SELECT nodes FROM workflow_entity WHERE id = 'PPAQLTX0UUv4OnZl';"]
raw = subprocess.check_output(cmd)
nodes = json.loads(raw.decode("utf-8"))

print("TOTAL_NODES:", len(nodes))
for n in nodes:
    name = n.get("name", "")
    if any(k in name for k in ["Email", "Outage", "WAN", "Alert"]):
        print("  *", name)
