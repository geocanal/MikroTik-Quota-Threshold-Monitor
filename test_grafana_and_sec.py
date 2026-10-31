import subprocess
import json

def run_remote(command):
    cmd = ['ssh', '-F', r'C:\Users\Ahmed Mohamed\.ssh\config', 'deploy-server', command]
    res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    return res.stdout, res.stderr, res.returncode

print("=== 1. Test Queries via Grafana Query API ===")
# Let's query Grafana /api/ds/query
payload = {
    "queries": [
        {
            "refId": "A",
            "datasource": {
                "type": "postgres",
                "uid": "PCC52D03280B7034C"
            },
            "rawSql": "SELECT interface_name, provider_name, quota_gb, used_gb, remaining_gb, used_percentage FROM view_mikrotik_wan_quota_status;",
            "format": "table"
        }
    ]
}

cmd_curl = f"""curl -s -u admin:admin -X POST http://localhost:3000/api/ds/query -H "Content-Type: application/json" -d '{json.dumps(payload)}' """
out, err, code = run_remote(cmd_curl)
print("Quota Status Query Response:")
print(out[:500] if len(out) > 500 else out)

print("\n=== 2. Test Quality & Latency Query ===")
payload2 = {
    "queries": [
        {
            "refId": "A",
            "datasource": {
                "type": "postgres",
                "uid": "PCC52D03280B7034C"
            },
            "rawSql": "SELECT timestamp AS time, interface_name AS metric, latency_ms FROM mikrotik_wan_quality ORDER BY timestamp DESC LIMIT 5;",
            "format": "table"
        }
    ]
}
out2, err2, code2 = run_remote(f"""curl -s -u admin:admin -X POST http://localhost:3000/api/ds/query -H "Content-Type: application/json" -d '{json.dumps(payload2)}' """)
print("Quality Query Response:")
print(out2[:500] if len(out2) > 500 else out2)

print("\n=== 3. Test Hotspot Query ===")
payload3 = {
    "queries": [
        {
            "refId": "A",
            "datasource": {
                "type": "postgres",
                "uid": "PCC52D03280B7034C"
            },
            "rawSql": "SELECT user_name, total_mb, used_percentage, is_active FROM hotspot_user_telemetry ORDER BY timestamp DESC LIMIT 5;",
            "format": "table"
        }
    ]
}
out3, err3, code3 = run_remote(f"""curl -s -u admin:admin -X POST http://localhost:3000/api/ds/query -H "Content-Type: application/json" -d '{json.dumps(payload3)}' """)
print("Hotspot Query Response:")
print(out3[:500] if len(out3) > 500 else out3)

print("\n=== 4. Docker Listening Ports & Host Bindings ===")
out4, err4, code4 = run_remote("sudo docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'")
print(out4)

print("\n=== 5. Host Open Ports (ss -tulpn) ===")
out5, err5, code5 = run_remote("sudo ss -tulpn")
print(out5)

print("\n=== 6. UFW Status ===")
out6, err6, code6 = run_remote("sudo ufw status verbose")
print(out6)
