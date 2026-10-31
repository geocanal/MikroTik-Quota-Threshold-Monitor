import subprocess

script = """
cat << 'EOF' > /tmp/fix_q_history.sql
INSERT INTO workflow_history (
    "versionId", "workflowId", nodes, connections, "createdAt", authors
)
SELECT 
    "versionId", id, nodes, connections, NOW(), 'system'
FROM workflow_entity
WHERE id = 'mikrotik-wan-quality-monitor'
ON CONFLICT ("versionId") DO NOTHING;

UPDATE workflow_entity
SET "activeVersionId" = "versionId",
    "triggerCount" = 1
WHERE id = 'mikrotik-wan-quality-monitor';
EOF

sudo docker cp /tmp/fix_q_history.sql n8n-postgres:/tmp/fix_q_history.sql
sudo docker exec n8n-postgres psql -U n8n -d n8n -f /tmp/fix_q_history.sql
sudo docker restart n8n
"""

cmd = [
    'ssh', '-F', r'C:\Users\Ahmed Mohamed\.ssh\config',
    'deploy-server',
    script
]
print(subprocess.check_output(cmd, text=True))
