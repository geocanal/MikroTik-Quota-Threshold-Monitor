import subprocess

sql = """
INSERT INTO wan_outage_events (
    router_id,
    interface_name,
    provider_name,
    landline_number,
    account_holder,
    started_at,
    ended_at,
    duration_minutes,
    outage_cause,
    email_sent,
    email_sent_at,
    email_recipient,
    email_subject
)
VALUES (
    'RB5009-Core',
    'wan1',
    'Vodafone DSL',
    '055XXXXXXX',
    'اسم المشترك',
    '2026-09-28 08:45:23+03',
    '2026-09-28 10:15:23+03',
    90,
    'ISP_FAILURE',
    TRUE,
    NOW(),
    'vodafone.online@vodafone.com',
    'شكوى انقطاع خدمة الإنترنت والمطالبة بالتعويض - خط رقم: 055XXXXXXX'
);
"""

cmd = [
    'ssh', '-F', r'C:\Users\Ahmed Mohamed\.ssh\config',
    'deploy-server',
    f'''sudo docker exec app-postgres-1 psql -U campaign -d campaign_db -c "{sql}"'''
]
print(subprocess.check_output(cmd, text=True))
