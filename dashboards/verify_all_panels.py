import subprocess
import json

def run_remote(command):
    cmd = ['ssh', '-F', r'C:\Users\Ahmed Mohamed\.ssh\config', 'deploy-server', command]
    res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    return res.stdout, res.stderr, res.returncode

wan_panels = [
    ("Panel 1 (Gauge Quota)", "SELECT CASE interface_name WHEN 'wan1' THEN 'Vodafone DSL (WAN1)' WHEN 'wan2' THEN 'WE Egypt (WAN2)' ELSE UPPER(interface_name) END AS isp, used_percentage::float AS used_pct FROM view_mikrotik_wan_quota_status ORDER BY interface_name;"),
    ("Panel 2 (Piechart Traffic)", "SELECT 'WAN1' AS metric, ROUND(COALESCE(SUM(wan1_rx_bytes + wan1_tx_bytes), 0)/(1024.0*1024.0*1024.0), 2) AS value FROM mikrotik_wan_usage WHERE usage_at >= NOW() - INTERVAL '24 hours' AND counter_reset = false UNION ALL SELECT 'WAN2' AS metric, ROUND(COALESCE(SUM(wan2_rx_bytes + wan2_tx_bytes), 0)/(1024.0*1024.0*1024.0), 2) AS value FROM mikrotik_wan_usage WHERE usage_at >= NOW() - INTERVAL '24 hours' AND counter_reset = false;"),
    ("Panel 3 (Timeseries Bandwidth)", "SELECT usage_at AS time, ROUND((wan1_rx_bytes + wan1_tx_bytes)/(1024.0*1024.0), 2) AS wan1_mb, ROUND((wan2_rx_bytes + wan2_tx_bytes)/(1024.0*1024.0), 2) AS wan2_mb, ROUND(total_bytes/(1024.0*1024.0), 2) AS total_mb FROM mikrotik_wan_usage WHERE usage_at >= NOW() - INTERVAL '24 hours' AND counter_reset = false ORDER BY usage_at ASC LIMIT 5;"),
    ("Panel 4 (Barchart Daily)", "SELECT (usage_date::timestamp AT TIME ZONE 'Africa/Cairo') AS time, wan1_total_gb AS wan1, wan2_total_gb AS wan2 FROM view_mikrotik_wan_daily_usage WHERE usage_date >= ((CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Cairo')::date - INTERVAL '30 days') ORDER BY usage_date ASC;"),
    ("Panel 5 (Table ISP Quota)", "SELECT UPPER(interface_name) AS interface, provider_name AS provider, quota_gb || ' GB' AS quota, used_gb || ' GB' AS used, remaining_gb || ' GB' AS remaining, used_percentage || '%' AS used_pct, daily_burn_rate_gb || ' GB/d' AS burn_rate, projected_exhaustion_date::text AS exhaustion_date, days_left || ' days (' || renewal_date || ')' AS renewal FROM view_mikrotik_wan_quota_status ORDER BY interface_name;")
]

hotspot_panels = [
    ("Hotspot Panel 1 (Stat Online)", "SELECT COUNT(DISTINCT user_name) AS active_users FROM hotspot_user_telemetry WHERE is_active = TRUE AND recorded_at >= (NOW() - INTERVAL '10 minutes');"),
    ("Hotspot Panel 2 (Pie Share)", "SELECT COALESCE(profile, 'Default') AS metric, ROUND(SUM(total_mb), 2) AS value FROM (SELECT DISTINCT ON (user_name) profile, total_mb FROM hotspot_user_telemetry ORDER BY user_name, recorded_at DESC) u GROUP BY COALESCE(profile, 'Default') HAVING ROUND(SUM(total_mb), 2) > 0;"),
    ("Hotspot Panel 3 (Stat High Quota)", "SELECT COUNT(DISTINCT user_name) AS alerting_users FROM hotspot_user_telemetry WHERE alert_tier IN ('80%', '100%') AND recorded_at >= (NOW() - INTERVAL '24 hours');"),
    ("Hotspot Panel 4 (Table Top 10)", "SELECT ROW_NUMBER() OVER (ORDER BY total_mb DESC) AS \"#\", user_name AS \"User\", COALESCE(profile, '-') AS \"Profile\", ROUND(total_mb, 0) AS \"Total (MB)\", ROUND(total_gb, 2) AS \"Total (GB)\", COALESCE(limit_gb::text || ' GB', 'No Limit') AS \"Limit\", is_active AS \"Online\", to_char(recorded_at AT TIME ZONE 'Africa/Cairo', 'MM-DD HH24:MI') AS \"Last Seen\" FROM (SELECT DISTINCT ON (user_name) * FROM hotspot_user_telemetry ORDER BY user_name, recorded_at DESC) latest WHERE total_mb > 0 ORDER BY total_mb DESC LIMIT 10;"),
    ("Hotspot Panel 5 (Table Incident Audit)", "SELECT user_name AS \"User\", COALESCE(profile, '-') AS \"Profile\", total_gb || ' GB' AS \"Used\", COALESCE(limit_gb::text || ' GB', 'No Limit') AS \"Limit\", COALESCE(remaining_gb::text || ' GB', '-') AS \"Remaining\", used_percentage || '%' AS \"Usage %\", CASE alert_tier WHEN 'NORMAL' THEN 'OK' WHEN '80%' THEN '⚠ 80%+' WHEN '100%' THEN '🔴 Exceeded' ELSE alert_tier END AS \"Status\", to_char(recorded_at AT TIME ZONE 'Africa/Cairo', 'MM-DD HH24:MI') AS \"Last Seen\" FROM (SELECT DISTINCT ON (user_name) * FROM hotspot_user_telemetry ORDER BY user_name, recorded_at DESC) latest WHERE total_mb > 0 ORDER BY total_mb DESC LIMIT 25;")
]

print("=== TESTING WAN DASHBOARD PANELS ===")
for title, query in wan_panels:
    payload = {
        "queries": [
            {
                "refId": "A",
                "datasource": {"type": "postgres", "uid": "PCC52D03280B7034C"},
                "rawSql": query,
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
            print(f"[+] {title}: PASS (status: {status})")
    except Exception as e:
        print(f"[-] {title}: ERROR parsing response -> {e}, raw: {out[:200]}")

print("\n=== TESTING HOTSPOT DASHBOARD PANELS ===")
for title, query in hotspot_panels:
    payload = {
        "queries": [
            {
                "refId": "A",
                "datasource": {"type": "postgres", "uid": "PCC52D03280B7034C"},
                "rawSql": query,
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
            print(f"[+] {title}: PASS (status: {status})")
    except Exception as e:
        print(f"[-] {title}: ERROR parsing response -> {e}, raw: {out[:200]}")
