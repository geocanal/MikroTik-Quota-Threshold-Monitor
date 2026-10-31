import subprocess

sql = '''
UPDATE workflow_entity
SET "activeVersionId" = "versionId",
    "triggerCount" = 1
WHERE id = 'mikrotik-interactive-telegram-bot';
'''

with open('/tmp/fix.sql', 'w') as f:
    f.write(sql)

subprocess.check_call(['sudo', 'docker', 'cp', '/tmp/fix.sql', 'n8n-postgres:/tmp/fix.sql'])
subprocess.check_call(['sudo', 'docker', 'exec', 'n8n-postgres', 'psql', '-U', 'n8n', '-d', 'n8n', '-f', '/tmp/fix.sql'])
print("SUCCESSFULLY_UPDATED_ACTIVE_VERSION")
