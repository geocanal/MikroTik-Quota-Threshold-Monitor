from check_cols import run_remote

script = """
python3 -c "
import json
with open('/home/deploy/mikrotik-monitoring/provisioning/dashboards/mikrotik-overview.json') as f:
    d = json.load(f)
panels = d.get('panels', [])
print('TOTAL PANELS IN mikrotik-overview.json:', len(panels))
for p in panels:
    print(p.get('id'), p.get('title'))
"
"""
out, err, code = run_remote(script)
print(out)
if err: print("ERR:", err)
