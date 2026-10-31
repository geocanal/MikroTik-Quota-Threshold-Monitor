import subprocess

sql = 'DELETE FROM webhook_entity WHERE "workflowId" = \'mikrotik-interactive-telegram-bot\';'
p = subprocess.Popen(['sudo', 'docker', 'exec', '-i', 'n8n-postgres', 'psql', '-U', 'n8n', '-d', 'n8n'], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
out, err = p.communicate(sql.encode('utf-8'))
print('OUT:', out.decode('utf-8'))
print('ERR:', err.decode('utf-8'))
