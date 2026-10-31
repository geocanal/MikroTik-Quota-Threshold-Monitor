import subprocess

sql = '''
INSERT INTO shared_workflow ("workflowId", "projectId", role, "createdAt", "updatedAt")
VALUES ('mikrotik-wan-quality-monitor', 'kAzun8BcreE04ySs', 'workflow:owner', NOW(), NOW())
ON CONFLICT DO NOTHING;
'''

p = subprocess.Popen(['sudo', 'docker', 'exec', '-i', 'n8n-postgres', 'psql', '-U', 'n8n', '-d', 'n8n'], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
out, err = p.communicate(sql.encode('utf-8'))
print("OUT:", out.decode('utf-8'))
print("ERR:", err.decode('utf-8'))
