from check_cols import run_remote

script = """
python3 -c "
import urllib.request, json

def query_grafana(raw_sql):
    payload = {
        'queries': [
            {
                'refId': 'A',
                'datasource': {'type': 'postgres', 'uid': 'PCC52D03280B7034C'},
                'rawSql': raw_sql,
                'format': 'table'
            }
        ],
        'from': 'now-24h',
        'to': 'now'
    }
    req = urllib.request.Request(
        'http://127.0.0.1:3000/api/ds/query',
        headers={'Authorization': 'Basic YWRtaW46YWRtaW4=', 'Content-Type': 'application/json'},
        data=json.dumps(payload).encode('utf-8')
    )
    resp = urllib.request.urlopen(req)
    res = json.loads(resp.read().decode())
    return res['results']['A']

print('1. Testing WAN Latency Query:')
sql_lat = \\\"SELECT probed_at AS time, CASE WHEN UPPER(interface_name) = 'WAN1' THEN 'Vodafone (WAN1) RTT' ELSE 'WE (WAN2) RTT' END AS metric, latency_ms FROM mikrotik_wan_quality ORDER BY probed_at DESC LIMIT 2;\\\"
res_lat = query_grafana(sql_lat)
print('Latency frames rows:', len(res_lat.get('frames', [{}])[0].get('data', {}).get('values', [[]])[0]))

print('2. Testing SLA Uptime Query:')
sql_sla = \\\"SELECT ROUND((100.0 - (COALESCE(SUM(duration_minutes), 0) / (EXTRACT(DAY FROM DATE_TRUNC('month', NOW()) + INTERVAL '1 month - 1 day') * 24.0 * 60.0) * 100.0))::numeric, 2) AS uptime_pct FROM wan_outage_events WHERE started_at >= DATE_TRUNC('month', NOW());\\\"
res_sla = query_grafana(sql_sla)
print('SLA Uptime Value:', res_sla.get('frames', [{}])[0].get('data', {}).get('values', []))

print('3. Testing Hotspot Top Talkers Query:')
sql_hs = \\\"SELECT user_name, total_gb FROM (SELECT DISTINCT ON (user_name) * FROM hotspot_user_telemetry ORDER BY user_name, recorded_at DESC) latest ORDER BY total_bytes DESC LIMIT 3;\\\"
res_hs = query_grafana(sql_hs)
print('Top Users:', res_hs.get('frames', [{}])[0].get('data', {}).get('values', []))
"
"""
out, err, code = run_remote(script)
print("OUT:", out)
if err: print("ERR:", err)
