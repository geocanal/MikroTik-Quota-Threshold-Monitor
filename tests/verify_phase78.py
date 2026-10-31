import subprocess
import json

def run_remote(command):
    cmd = ['ssh', '-F', r'C:\Users\Ahmed Mohamed\.ssh\config', 'deploy-server', command]
    res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    return res.stdout, res.stderr, res.returncode

print("=== 1. Telegram Service Journalctl (last 50 lines) ===")
out, err, code = run_remote("sudo journalctl -u mikrotik-telegram-bot.service -n 50 --no-pager")
print(out)
if err: print("STDERR:", err)

print("=== 2. Telegram Bot Conflict / 409 check in logs ===")
out, err, code = run_remote("sudo journalctl -u mikrotik-telegram-bot.service --grep='409|Conflict' --no-pager")
print("Grep 409/Conflict:", out if out.strip() else "None found!")

print("=== 3. Telegram Webhook Status via Telegram API ===")
out, err, code = run_remote("curl -s -X POST https://api.telegram.org/botYOUR_TELEGRAM_BOT_TOKEN/getWebhookInfo")
print(out)

print("=== 4. Telegram getMe check ===")
out, err, code = run_remote("curl -s -X GET https://api.telegram.org/botYOUR_TELEGRAM_BOT_TOKEN/getMe")
print(out)

print("=== 5. Grafana Datasource Health ===")
out, err, code = run_remote("curl -s -u admin:admin http://localhost:3000/api/datasources/uid/PCC52D03280B7034C/health")
print(out)

print("=== 6. Grafana Search / List Dashboards ===")
out, err, code = run_remote("curl -s -u admin:admin http://localhost:3000/api/search")
print(out)

print("=== 7. Docker Containers & Exposed Ports ===")
out, err, code = run_remote("sudo docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'")
print(out)

print("=== 8. Host Listening Ports (ss -tulpn) ===")
out, err, code = run_remote("sudo ss -tulpn")
print(out)

print("=== 9. UFW Firewall Status ===")
out, err, code = run_remote("sudo ufw status verbose")
print(out)
