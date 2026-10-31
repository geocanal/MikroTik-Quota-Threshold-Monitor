import json
import uuid
import subprocess

with open("MikroTik - WAN Quality Ingestion.json", "r", encoding="utf-8") as f:
    wf = json.load(f)

workflow_id = "mikrotik-wan-quality-monitor"
version_id = str(uuid.uuid4())

nodes_json = json.dumps(wf["nodes"], ensure_ascii=False)
connections_json = json.dumps(wf["connections"], ensure_ascii=False)
settings_json = json.dumps(wf.get("settings", {}), ensure_ascii=False)

sql = f"""
INSERT INTO workflow_entity (
    id, name, active, nodes, connections, settings, "createdAt", "updatedAt", "versionId", "triggerCount"
)
VALUES (
    '{workflow_id}',
    'MikroTik - WAN Quality Monitor',
    true,
    '{nodes_json.replace("'", "''")}'::json,
    '{connections_json.replace("'", "''")}'::json,
    '{settings_json.replace("'", "''")}'::json,
    NOW(),
    NOW(),
    '{version_id}',
    1
)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    active = EXCLUDED.active,
    nodes = EXCLUDED.nodes,
    connections = EXCLUDED.connections,
    settings = EXCLUDED.settings,
    "updatedAt" = NOW(),
    "versionId" = EXCLUDED."versionId",
    "triggerCount" = EXCLUDED."triggerCount";
"""

with open("insert_quality_wf.sql", "w", encoding="utf-8") as f:
    f.write(sql)

cmd = [
    'scp', '-F', r'C:\Users\Ahmed Mohamed\.ssh\config',
    'insert_quality_wf.sql',
    'deploy-server:/tmp/insert_quality_wf.sql'
]
subprocess.check_call(cmd)

cmd_exec = [
    'ssh', '-F', r'C:\Users\Ahmed Mohamed\.ssh\config',
    'deploy-server',
    'sudo docker cp /tmp/insert_quality_wf.sql n8n-postgres:/tmp/insert_quality_wf.sql && sudo docker exec n8n-postgres psql -U n8n -d n8n -f /tmp/insert_quality_wf.sql && sudo docker restart n8n'
]
print(subprocess.check_output(cmd_exec, text=True))
