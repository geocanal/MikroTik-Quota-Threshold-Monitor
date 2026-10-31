import subprocess
import json

def run_remote(command):
    cmd = ['ssh', '-F', r'C:\Users\Ahmed Mohamed\.ssh\config', 'deploy-server', command]
    res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    return res.stdout, res.stderr, res.returncode

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

print("=== Executing Quality, SLA, and Hotspot Queries via Grafana Query API ===")
for title, q in queries:
    payload = {
        "queries": [
            {
                "refId": "A",
                "datasource": {"type": "postgres", "uid": "PCC52D03280B7034C"},
                "rawSql": q.strip(),
                "format": "table"
            }
        ]
    }
    cmd_curl = f"""curl -s -u admin:admin -X POST http://localhost:3000/api/ds/query -H "Content-Type: application/json" -d '{json.dumps(payload)}' """
    out, err, code = run_remote(cmd_curl)
    try:
        data = json.loads(out)
        res = data.get("results", {}).get("A", {})
        status = res.get("status")
        error = res.get("error")
        if error:
            print(f"[-] {title}: FAIL -> {error}")
        else:
            frames = res.get("frames", [])
            row_count = len(frames[0]["data"]["values"][0]) if frames and "data" in frames[0] and frames[0]["data"]["values"] else 0
            print(f"[+] {title}: PASS (status: {status}, rows: {row_count})")
    except Exception as e:
        print(f"[-] {title}: ERROR parsing -> {e}, raw: {out[:200]}")
