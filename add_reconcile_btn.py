with open('/home/deploy/telegram_bot_daemon.py', 'r', encoding='utf-8') as f:
    code = f.read()

# Check if reconcile button exists
if 'reconcile_status' not in code:
    old_btn = '{"text": "🔄 تحديث البيانات الآن", "callback_data": "refresh_status"}'
    new_btn = '{"text": "🔄 تحديث البيانات الآن", "callback_data": "refresh_status"},\n                    {"text": "🛡️ مطابقة العزل (PBR Sync)", "callback_data": "reconcile_status"}'
    code = code.replace(old_btn, new_btn)
    
    old_action = 'elif action == "ping_quality":'
    reconcile_action = '''elif action == "reconcile_status":
            cur.execute("""
                SELECT interface_name, is_isolated, isolated_reason, speed_limit_rx, speed_limit_tx
                FROM wan_incident_state
                ORDER BY interface_name;
            """)
            i_rows = cur.fetchall()
            cur.execute("""
                SELECT interface_name, provider_name, remaining_gb, used_percentage
                FROM view_mikrotik_wan_quota_status
                ORDER BY interface_name;
            """)
            q_rows = cur.fetchall()
            q_map = {r['interface_name']: r for r in q_rows}
            res = "🛡️ <b>تقرير مطابقة حالة الخطوط والعزل (WCCP PBR Sync):</b>\\n\\n"
            for r in i_rows:
                iface = r['interface_name']
                q = q_map.get(iface, {})
                used = q.get('used_percentage', 0)
                st = "🟡 معزول (ISOLATED)" if r['is_isolated'] else "🟢 مدمج بالخدمة (PCC Active)"
                res += f"• <b>خط {iface.upper()}:</b>\\n"
                res += f"  - الاستهلاك: <b>{used}%</b> (المتبقي: <b>{q.get('remaining_gb', 0)} GB</b>)\\n"
                res += f"  - حالة الراوتر: <b>{st}</b>\\n"
                if r['is_isolated']:
                    res += f"  - سبب العزل: <i>{r['isolated_reason']}</i>\\n"
                res += "\\n"
            return res
        ''' + old_action
    code = code.replace(old_action, reconcile_action)
    with open('/home/deploy/telegram_bot_daemon.py', 'w', encoding='utf-8') as f:
        f.write(code)
    print("SUCCESS: Added reconcile action")
else:
    print("ALREADY EXISTS")
