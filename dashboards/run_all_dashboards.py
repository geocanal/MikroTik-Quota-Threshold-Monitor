import subprocess
import json

queries = [
    ("WAN Quota Status Gauge", "SELECT CASE interface_name WHEN 'wan1' THEN 'Vodafone DSL (WAN1)' WHEN 'wan2' THEN 'WE Egypt (WAN2)' ELSE UPPER(interface_name) END AS isp, used_percentage::float AS used_pct FROM view_mikrotik_wan_quota_status ORDER BY interface_name;"),
    ("WAN Traffic Distribution Pie", "SELECT 'WAN1' AS metric, ROUND(COALESCE(SUM(wan1_rx_bytes + wan1_tx_bytes), 0)/(1024.0*1024.0*1024.0), 2) AS value FROM mikrotik_wan_usage WHERE usage_at >= NOW() - INTERVAL '24 hours' AND counter_reset = false UNION ALL SELECT 'WAN2' AS metric, ROUND(COALESCE(SUM(wan2_rx_bytes + wan2_tx_bytes), 0)/(1024.0*1024.0*1024.0), 2) AS value FROM mikrotik_wan_usage WHERE usage_at >= NOW() - INTERVAL '24 hours' AND counter_reset = false;"),
    ("WAN Bandwidth Throughput Timeseries", "SELECT usage_at AS time, ROUND((wan1_rx_bytes + wan1_tx_bytes)/(1024.0*1024.0), 2) AS wan1_mb, ROUND((wan2_rx_bytes + wan2_tx_bytes)/(1024.0*1024.0), 2) AS wan2_mb, ROUND(total_bytes/(1024.0*1024.0), 2) AS total_mb FROM mikrotik_wan_usage WHERE usage_at >= NOW() - INTERVAL '24 hours' AND counter_reset = false ORDER BY usage_at ASC LIMIT 5;"),
    ("WAN Daily Consumption Bar Chart", "SELECT (usage_date::timestamp AT TIME ZONE 'Africa/Cairo') AS time, wan1_total_gb AS wan1, wan2_total_gb AS wan2 FROM view_mikrotik_wan_daily_usage WHERE usage_date >= ((CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Cairo')::date - INTERVAL '30 days') ORDER BY usage_date ASC;"),
    ("ISP Quota Cycle Summary Table", "SELECT UPPER(interface_name) AS interface, provider_name AS provider, quota_gb || ' GB' AS quota, used_gb || ' GB' AS used, remaining_gb || ' GB' AS remaining, used_percentage || '%' AS used_pct, daily_burn_rate_gb || ' GB/d' AS burn_rate, projected_exhaustion_date::text AS exhaustion_date, days_left || ' days (' || renewal_date || ')' AS renewal FROM view_mikrotik_wan_quota_status ORDER BY interface_name;"),
    ("Hotspot Online Sessions Stat", "SELECT COUNT(DISTINCT user_name) AS active_users FROM hotspot_user_telemetry WHERE is_active = TRUE AND recorded_at >= (NOW() - INTERVAL '10 minutes');"),
    ("Hotspot High Quota Consumers Stat", "SELECT COUNT(DISTINCT user_name) AS alerting_users FROM hotspot_user_telemetry WHERE alert_tier IN ('80%', '100%') AND recorded_at >= (NOW() - INTERVAL '24 hours');"),
    ("Hotspot Top 10 Heavy Users Table", "SELECT ROW_NUMBER() OVER (ORDER BY total_mb DESC) AS \"#\", user_name AS \"User\", COALESCE(profile, '-') AS \"Profile\", ROUND(total_mb, 0) AS \"Total (MB)\", ROUND(total_gb, 2) AS \"Total (GB)\", COALESCE(limit_gb::text || ' GB', 'No Limit') AS \"Limit\", is_active AS \"Online\", to_char(recorded_at AT TIME ZONE 'Africa/Cairo', 'MM-DD HH24:MI') AS \"Last Seen\" FROM (SELECT DISTINCT ON (user_name) * FROM hotspot_user_telemetry ORDER BY user_name, recorded_at DESC) latest WHERE total_mb > 0 ORDER BY total_mb DESC LIMIT 10;"),
    ("Hotspot Quota & Incident Audit Table", "SELECT user_name AS \"User\", COALESCE(profile, '-') AS \"Profile\", total_gb || ' GB' AS \"Used\", COALESCE(limit_gb::text || ' GB', 'No Limit') AS \"Limit\", COALESCE(remaining_gb::text || ' GB', '-') AS \"Remaining\", used_percentage || '%' AS \"Usage %\", CASE alert_tier WHEN 'NORMAL' THEN 'OK' WHEN '80%' THEN '⚠ 80%+' WHEN '100%' THEN '🔴 Exceeded' ELSE alert_tier END AS \"Status\", to_char(recorded_at AT TIME ZONE 'Africa/Cairo', 'MM-DD HH24:MI') AS \"Last Seen\" FROM (SELECT DISTINCT ON (user_name) * FROM hotspot_user_telemetry ORDER BY user_name, recorded_at DESC) latest WHERE total_mb > 0 ORDER BY total_mb DESC LIMIT 25;")
]

remote_script = f"""
cat << 'EOF' > /tmp/run_all_dashboards_test.py
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
python3 /tmp/run_all_dashboards_test.py
"""

cmd = ['ssh', '-F', r'C:\Users\Ahmed Mohamed\.ssh\config', 'deploy-server', remote_script]
res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
print("STDOUT:")
print(res.stdout)
