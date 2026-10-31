import subprocess

cmd1 = [
    'ssh', '-F', r'C:\Users\Ahmed Mohamed\.ssh\config',
    'deploy-server',
    '''sudo docker exec -i n8n-postgres psql -U n8n -d n8n -c "DELETE FROM webhook_entity WHERE \\"workflowId\\" = 'mikrotik-interactive-telegram-bot';"'''
]
print("DELETE WEBHOOK ROW:", subprocess.check_output(cmd1, text=True))

cmd2 = [
    'ssh', '-F', r'C:\Users\Ahmed Mohamed\.ssh\config',
    'deploy-server',
    'curl -s -X POST https://api.telegram.org/botYOUR_TELEGRAM_BOT_TOKEN/deleteWebhook?drop_pending_updates=True'
]
print("TELEGRAM DELETE WEBHOOK:", subprocess.check_output(cmd2, text=True))

cmd3 = [
    'ssh', '-F', r'C:\Users\Ahmed Mohamed\.ssh\config',
    'deploy-server',
    'sudo systemctl restart mikrotik-telegram-bot.service'
]
print("RESTART SYSTEMD BOT:", subprocess.check_output(cmd3, text=True))
