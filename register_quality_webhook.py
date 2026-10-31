import subprocess

script = """
cat << 'EOF' > /tmp/add_quality_webhook.sql
INSERT INTO webhook_entity (
    "workflowId",
    "webhookPath",
    method,
    "node",
    "webhookId",
    "pathLength"
)
VALUES (
    'mikrotik-wan-quality-monitor',
    'mikrotik/wan-quality',
    'POST',
    'WAN Quality Webhook',
    'b1a2c3d4-wan-quality-webhook',
    2
)
ON CONFLICT DO NOTHING;
EOF

sudo docker cp /tmp/add_quality_webhook.sql n8n-postgres:/tmp/add_quality_webhook.sql
sudo docker exec n8n-postgres psql -U n8n -d n8n -f /tmp/add_quality_webhook.sql
sudo docker restart n8n
"""

cmd = [
    'ssh', '-F', r'C:\Users\Ahmed Mohamed\.ssh\config',
    'deploy-server',
    script
]
print(subprocess.check_output(cmd, text=True))
