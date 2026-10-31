from check_cols import run_remote

script = """
# 1. Backup original file
cp /home/deploy/mikrotik-monitoring/provisioning/dashboards/mikrotik-overview.json /home/deploy/mikrotik-monitoring/provisioning/dashboards/mikrotik-overview.json.bak

# 2. Overwrite with upgraded dashboard
mv /tmp/mikrotik-overview.json /home/deploy/mikrotik-monitoring/provisioning/dashboards/mikrotik-overview.json
chown deploy:deploy /home/deploy/mikrotik-monitoring/provisioning/dashboards/mikrotik-overview.json

# 3. Post to Grafana HTTP API to apply immediately without waiting
python3 -c "
import urllib.request, json
with open('/home/deploy/mikrotik-monitoring/provisioning/dashboards/mikrotik-overview.json', 'r', encoding='utf-8') as f:
    dash = json.load(f)

payload = {
    'dashboard': dash,
    'overwrite': True,
    'folderUid': 'cfzjjzd1osdmof'
}
req = urllib.request.Request(
    'http://127.0.0.1:3000/api/dashboards/db',
    headers={
        'Authorization': 'Basic YWRtaW46YWRtaW4=',
        'Content-Type': 'application/json'
    },
    data=json.dumps(payload).encode('utf-8')
)
resp = urllib.request.urlopen(req)
print('GRAFANA API UPDATE:', resp.status, resp.read().decode())
"

# 4. Restart container to ensure provisioning sync is locked
cd /home/deploy/mikrotik-monitoring && docker compose restart grafana
"""
out, err, code = run_remote(script)
print("OUT:", out)
if err: print("ERR:", err)
