import subprocess

script = """
cat << 'EOF' > /tmp/test_bot_query.py
import psycopg2
from psycopg2.extras import RealDictCursor

conn = psycopg2.connect(
    host="172.18.0.8",
    port=5432,
    dbname="campaign_db",
    user="campaign",
    password="password"
)
cur = conn.cursor(cursor_factory=RealDictCursor)
cur.execute("SELECT interface_name, provider_name, quota_gb, used_gb, remaining_gb, used_percentage, days_left, renewal_date FROM view_mikrotik_wan_quota_status ORDER BY interface_name;")
rows = cur.fetchall()
print("ROWS FROM DB:")
for r in rows:
    print(r)
conn.close()
EOF
python3 -m venv /home/deploy/bot_env || true
/home/deploy/bot_env/bin/pip install requests psycopg2-binary
/home/deploy/bot_env/bin/python /tmp/test_bot_query.py
"""

cmd = [
    'ssh', '-F', r'C:\Users\Ahmed Mohamed\.ssh\config',
    'deploy-server',
    script
]
print(subprocess.check_output(cmd, text=True))
