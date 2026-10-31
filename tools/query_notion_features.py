import sys, os, json, urllib.request
sys.path.append(r'C:\Users\Ahmed Mohamed\.gemini')
import notion_sync

proj_id, title = notion_sync.get_project_id_by_name('MikroTik')

query = {
    'filter': {
        'property': 'Project',
        'relation': {
            'contains': proj_id
        }
    },
    'sorts': [
        {
            'timestamp': 'created_time',
            'direction': 'descending'
        }
    ]
}
res = notion_sync.api_call(f'databases/{notion_sync.FEATURES_DB_ID}/query', data=query)
print(f"TOTAL FEATURES: {len(res.get('results', []))}")
for item in res.get('results', []):
    props = item['properties']
    # find title property key
    title_key = None
    for k, v in props.items():
        if v.get('type') == 'title':
            title_key = k
            break
    
    t_arr = props.get(title_key, {}).get('title', []) if title_key else []
    f_title = t_arr[0].get('text', {}).get('content', 'Untitled') if t_arr else 'Untitled'
    
    status_prop = props.get('Status', {}).get('select', {})
    status = status_prop.get('name', 'No status') if status_prop else 'No status'
    created = item.get('created_time', '')[:19]
    safe_title = f_title.encode('ascii', 'replace').decode('ascii')
    safe_status = status.encode('ascii', 'replace').decode('ascii')
    print(f"[{created}] [{safe_status}] {safe_title}")
