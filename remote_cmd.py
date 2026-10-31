import subprocess
import sys

def run():
    remote_cmd = sys.argv[1] if len(sys.argv) > 1 else 'sudo docker ps'
    cmd = ['ssh', '-F', r'C:\Users\Ahmed Mohamed\.ssh\config', 'deploy-server', remote_cmd]
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.stdout:
        print(res.stdout)
    if res.stderr:
        print("STDERR:", res.stderr)

if __name__ == '__main__':
    run()
