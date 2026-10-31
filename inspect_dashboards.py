import json

def inspect_dashboard(file_path):
    try:
        with open(file_path, 'r', encoding='utf-16') as f:
            d = json.load(f)
    except Exception:
        with open(file_path, 'r', encoding='utf-8') as f:
            d = json.load(f)

    dash = d.get('dashboard', d)
    print(f"=== Dashboard: {dash.get('title')} (UID: {dash.get('uid')}) ===")
    panels = dash.get('panels', [])
    for p in panels:
        clean_title = p.get('title', '').encode('ascii', 'replace').decode('ascii')
        print(f"ID {p.get('id')}: {clean_title} | Type: {p.get('type')} | GridPos: {p.get('gridPos')}")
        targets = p.get('targets', [])
        for t in targets:
            raw_sql = t.get('rawSql', '').strip().replace('\n', ' ')
            if raw_sql:
                print(f"   SQL: {raw_sql[:100]}...")

print("\n--- VERIFY DASHBOARD ---")
inspect_dashboard('d:/Work/MikroTik - Quota Threshold Monitor/verify_dash.json')

print("\n--- HOTSPOT DASHBOARD ---")
inspect_dashboard('d:/Work/MikroTik - Quota Threshold Monitor/hotspot_dashboard_backup.json')
