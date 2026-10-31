import subprocess

sql = """
INSERT INTO wan_outage_events (
    router_id,
    interface_name,
    provider_name,
    landline_number,
    account_holder,
    outage_start,
    outage_end,
    duration_minutes,
    is_power_loss,
    compensation_claim_status,
    notes
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
    FALSE,
    'DISPATCHED',
    'Live claim dispatched to vodafone.online@vodafone.com with CC to admin@example.com'
);
"""

cmd = [
    'ssh', '-F', r'C:\Users\Ahmed Mohamed\.ssh\config',
    'deploy-server',
    f'''sudo docker exec app-postgres-1 psql -U campaign -d campaign_db -c "{sql}"'''
]
print(subprocess.check_output(cmd, text=True))
