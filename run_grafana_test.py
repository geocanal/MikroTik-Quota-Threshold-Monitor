import subprocess
import json

queries = [
    ("Latency Time-Series", """
    SELECT 
        probed_at AS time,
        CASE WHEN UPPER(interface_name) = 'WAN1' THEN 'Vodafone (WAN1)' ELSE 'WE (WAN2)' END AS metric,
        latency_ms
    FROM mikrotik_wan_quality
    WHERE probed_at >= NOW() - INTERVAL '24 hours'
    ORDER BY probed_at ASC
    LIMIT 5;
    """),
    ("Packet Loss Time-Series", """
    SELECT 
        probed_at AS time,
        CASE WHEN UPPER(interface_name) = 'WAN1' THEN 'Vodafone (WAN1) Loss %' ELSE 'WE (WAN2) Loss %' END AS metric,
        packet_loss_percent
    FROM mikrotik_wan_quality
    WHERE probed_at >= NOW() - INTERVAL '24 hours'
    ORDER BY probed_at ASC
    LIMIT 5;
    """),
    ("Monthly ISP SLA Availability Gauge", """
    SELECT 
        ROUND(
            (100.0 - (COALESCE(SUM(duration_minutes), 0) / (EXTRACT(DAY FROM DATE_TRUNC('month', NOW()) + INTERVAL '1 month - 1 day') * 24.0 * 60.0) * 100.0))::numeric, 
            2
        ) AS monthly_uptime_percent,
        COALESCE(SUM(duration_minutes), 0) AS total_downtime_minutes,
        ROUND((COALESCE(SUM(duration_minutes), 0) / 60.0)::numeric, 1) AS total_downtime_hours,
        COUNT(*) AS total_outage_incidents
    FROM wan_outage_events
    WHERE started_at >= DATE_TRUNC('month', NOW());
    """),
    ("Hotspot Top Users", """
    SELECT 
        user_name AS "User",
        profile AS "Profile",
        ip_address AS "IP Address",
        mac_address AS "MAC Address",
        ROUND(total_mb, 1) || ' MB' AS "Total Consumed",
        ROUND(total_gb, 2) || ' GB' AS "Total (GB)",
        used_percentage || '%' AS "Quota %",
        CASE WHEN is_active THEN 'Active Online' ELSE 'Offline' END AS "Session Status",
        session_uptime AS "Session Uptime",
        recorded_at AS "Last Seen"
    FROM (
        SELECT DISTINCT ON (user_name) *
        FROM hotspot_user_telemetry
        ORDER BY user_name, recorded_at DESC
    ) latest
    ORDER BY total_bytes DESC
    LIMIT 5;
    """)
]

remote_script = f"""
cat << 'EOF' > /tmp/run_grafana_queries.py
import urllib.request
import json
import base64

queries = {json.dumps(queries)}

auth = base64.b64encode(b"admin:admin").decode('ascii')
url = "http://localhost:3000/api/ds/query"

for title, sql in queries:
    payload = {{
        "queries": [
            {{
                "refId": "A",
                "datasource": {{"type": "postgres", "uid": "PCC52D03280B7034C"}},
                "rawSql": sql.strip(),
                "format": "table"
            }}
        ]
    }}
    req = urllib.request.Request(url, data=json.dumps(payload).encode('utf-8'), headers={{
        "Content-Type": "application/json",
        "Authorization": f"Basic {{auth}}"
    }})
    try:
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read().decode('utf-8'))
            res = data.get("results", {{}}).get("A", {{}})
            error = res.get("error")
            if error:
                print(f"[-] {{title}}: FAIL -> {{error}}")
            else:
                frames = res.get("frames", [])
                rowCount = len(frames[0]["data"]["values"][0]) if frames and "data" in frames[0] and frames[0]["data"]["values"] else 0
                print(f"[+] {{title}}: PASS (returned {{rowCount}} rows)")
    except Exception as e:
        print(f"[-] {{title}}: EXCEPTION -> {{e}}")
EOF
python3 /tmp/run_grafana_queries.py
"""

cmd = ['ssh', '-F', r'C:\Users\Ahmed Mohamed\.ssh\config', 'deploy-server', remote_script]
res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
print("STDOUT:")
print(res.stdout)
if res.stderr:
    print("STDERR:", res.stderr)
