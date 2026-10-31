with open('/home/deploy/telegram_bot_daemon.py', 'r', encoding='utf-8') as f:
    content = f.read()

old_block = '''        elif action == "ping_quality":
            return "⚡ جاري تشغيل فحص جودة الخطوط وزمن الاستجابة (Latency / Jitter)... الخطوط ضمن المعدل الطبيعي."'''

new_block = '''        elif action == "ping_quality":
            cur.execute("""
                SELECT interface_name, target_host, latency_ms, packet_loss_percent, jitter_ms, status, probed_at
                FROM mikrotik_wan_quality
                WHERE probed_at >= NOW() - INTERVAL '5 minutes'
                ORDER BY probed_at DESC
                LIMIT 2;
            """)
            q_rows = cur.fetchall()
            if not q_rows:
                cur.execute("""
                    SELECT interface_name, target_host, latency_ms, packet_loss_percent, jitter_ms, status, probed_at
                    FROM view_mikrotik_wan_latest_quality
                    ORDER BY probed_at DESC;
                """)
                q_rows = cur.fetchall()

            if not q_rows:
                return "⚡ <b>مؤشرات جودة الخطوط:</b>\\nلا توجد بيانات فحص مسجلة حتى الآن."

            res = "⚡ <b>مؤشرات جودة الخطوط وزمن الاستجابة (Latency / Loss):</b>\\n\\n"
            for q in q_rows:
                st = "🟢 ممتاز وطبيعي" if q['status'] == 'HEALTHY' else ("🟡 تراجع في الجودة" if q['status'] == 'DEGRADED' else "🔴 انقطاع كامل")
                res += f"🌐 <b>خط {q['interface_name'].upper()}:</b>\\n"
                res += f"  • زمن الاستجابة (Ping): <b>{q['latency_ms']} ms</b>\\n"
                res += f"  • فقدان الحزم (Packet Loss): <b>{q['packet_loss_percent']}%</b>\\n"
                res += f"  • الحالة الفنية: <b>{st}</b>\\n"
                res += f"  • توقيت الفحص: <code>{q['probed_at'].strftime('%H:%M:%S')}</code>\\n\\n"
            return res'''

if old_block in content:
    content = content.replace(old_block, new_block)
    with open('/home/deploy/telegram_bot_daemon.py', 'w', encoding='utf-8') as f:
        f.write(content)
    print("SUCCESS: Updated ping_quality in telegram_bot_daemon.py")
else:
    print("WARNING: old_block not found in telegram_bot_daemon.py")
