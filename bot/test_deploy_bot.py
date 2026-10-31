import subprocess

def deploy():
    # 1. Copy telegram_bot_daemon.py to remote server
    print("Uploading telegram_bot_daemon.py to deploy-server...")
    subprocess.check_call([
        'scp', '-F', r'C:\Users\Ahmed Mohamed\.ssh\config',
        r'd:\Work\MikroTik - Quota Threshold Monitor\telegram_bot_daemon.py',
        'deploy-server:/home/deploy/telegram_bot_daemon.py'
    ])
    
    # 2. Inspect docker network and postgres IP
    inspect_cmd = [
        'ssh', '-F', r'C:\Users\Ahmed Mohamed\.ssh\config',
        'deploy-server',
        'sudo docker inspect app-postgres-1 -f "{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}"'
    ]
    pg_ip = subprocess.check_output(inspect_cmd, text=True).strip()
    print("Postgres internal IP:", pg_ip)

    # 3. Create systemd service or docker container for telegram bot
    # Let's check python3 on host
    check_python = [
        'ssh', '-F', r'C:\Users\Ahmed Mohamed\.ssh\config',
        'deploy-server',
        'python3 --version; pip3 --version || true'
    ]
    py_out = subprocess.check_output(check_python, text=True)
    print(py_out)

if __name__ == '__main__':
    deploy()
