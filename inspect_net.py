import subprocess

cmd = [
    'ssh', '-F', r'C:\Users\Ahmed Mohamed\.ssh\config',
    'deploy-server',
    'sudo docker inspect app-postgres-1 --format "{{json .NetworkSettings.Networks}}"'
]
print(subprocess.check_output(cmd, text=True))
