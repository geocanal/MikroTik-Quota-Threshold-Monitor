import os
import time
import requests
import psycopg2
from psycopg2.extras import RealDictCursor

# Zero-dependency .env loader for local or container standalone runs
def _load_env_file():
    env_paths = [
        os.path.join(os.path.dirname(os.path.abspath(__file__)), '.env'),
        '/opt/mikrotik-monitoring/.env',
        '.env'
    ]
    for p in env_paths:
        if os.path.isfile(p):
            try:
                with open(p, 'r', encoding='utf-8') as f:
                    for line in f:
                        line = line.strip()
                        if not line or line.startswith('#') or '=' not in line:
                            continue
                        k, v = line.split('=', 1)
                        k = k.strip()
                        v = v.strip().strip('"').strip("'")
                        if k and k not in os.environ:
                            os.environ[k] = v
                break
            except Exception:
                pass

_load_env_file()

BOT_TOKEN = os.getenv("TELEGRAM_BOT_TOKEN")
ADMIN_CHAT_ID = int(os.getenv("TELEGRAM_ADMIN_CHAT_ID", "123456789"))
BASE_URL = f"https://api.telegram.org/bot{BOT_TOKEN}" if BOT_TOKEN else ""

DB_HOST = os.getenv("DB_HOST", "127.0.0.1")
DB_PORT = int(os.getenv("DB_PORT", "55432"))
DB_NAME = os.getenv("DB_NAME", "campaign_db")
DB_USER = os.getenv("DB_USER", "campaign")
DB_PASS = os.getenv("DB_PASS", os.getenv("DB_PASSWORD", ""))

def get_db():
    return psycopg2.connect(
        host=DB_HOST,
        port=DB_PORT,
        dbname=DB_NAME,
        user=DB_USER,
        password=DB_PASS
    )

def send_message(chat_id, text, reply_markup=None):
    payload = {
        "chat_id": chat_id,
        "text": text,
        "parse_mode": "HTML"
    }
    if reply_markup:
        payload["reply_markup"] = reply_markup
    try:
        r = requests.post(f"{BASE_URL}/sendMessage", json=payload, timeout=10)
        return r.json()
    except Exception as e:
        print(f"Error sending message: {e}", flush=True)
        return None

def answer_callback(callback_query_id, text=None):
    payload = {"callback_query_id": callback_query_id}
    if text:
        payload["text"] = text
    try:
        requests.post(f"{BASE_URL}/answerCallbackQuery", json=payload, timeout=10)
    except Exception as e:
        print(f"Error answering callback: {e}", flush=True)

def get_quota_dashboard():
    try:
        conn = get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("""
            SELECT interface_name, provider_name, quota_gb, used_gb, remaining_gb, used_percentage, days_left, renewal_date
            FROM view_mikrotik_wan_quota_status
            ORDER BY interface_name;
        """)
        rows = cur.fetchall()
        
        cur.execute("""
            SELECT interface_name, is_down, is_isolated, isolated_reason, speed_limit_rx, speed_limit_tx
            FROM wan_incident_state
            ORDER BY interface_name;
        """)
        incidents = {r['interface_name']: r for r in cur.fetchall()}
        conn.close()

        def pbar(pct):
            filled = min(10, max(0, round(float(pct or 0) / 10)))
            return "▓" * filled + "░" * (10 - filled)

        msg = "🎛️ <b>لوحة التحكم والعمليات المباشرة - MikroTik WAN</b>\n"
        msg += "━━━━━━━━━━━━━━━━━━━━━\n\n"

        for row in rows:
            iface = row['interface_name']
            inc = incidents.get(iface, {})
            status_emoji = "🔴 مفصول" if inc.get('is_down') else ("🟡 معزول" if inc.get('is_isolated') else "🟢 متصل وطبيعي")
            
            msg += f"🌐 <b>{row['provider_name']} ({iface.upper()}):</b>\n"
            msg += f"  • الحالة التشغيلية: <b>{status_emoji}</b>\n"
            msg += f"  • استهلاك الكوتا: [<code>{pbar(row['used_percentage'])}</code>] <b>{row['used_percentage']}%</b>\n"
            msg += f"  • المتبقي: <b>{row['remaining_gb']} GB</b> من أصل <b>{row['quota_gb']} GB</b>\n"
            msg += f"  • التجديد: بعد <b>{row['days_left']} يوم</b> ({row['renewal_date']})\n"
            if inc.get('is_isolated'):
                msg += f"  • سبب العزل: <i>{inc.get('isolated_reason')}</i>\n"
            msg += "\n"

        inline_keyboard = {
            "inline_keyboard": [
                [
                    {"text": "🔄 تحديث البيانات الآن", "callback_data": "refresh_status"},
                    {"text": "⚡ الفحص والتحويل الذكي", "callback_data": "smart_failover"}
                ],
                [
                    {"text": "🎫 كروت ومستخدمي الهوت سبوت", "callback_data": "hotspot_vouchers"},
                    {"text": "🛡️ مطابقة العزل (PBR)", "callback_data": "reconcile_status"}
                ],
                [
                    {"text": "⚡ جودة الخطوط (Latency)", "callback_data": "ping_quality"},
                    {"text": "📋 سجل الانقطاعات الأخير", "callback_data": "recent_outages"}
                ],
                [
                    {"text": "🔒 عزل خط فودافون WAN1", "callback_data": "isolate_wan1"},
                    {"text": "🔓 إعادة تفعيل WAN1", "callback_data": "restore_wan1"}
                ],
                [
                    {"text": "🔒 عزل خط وي WAN2", "callback_data": "isolate_wan2"},
                    {"text": "🔓 إعادة تفعيل WAN2", "callback_data": "restore_wan2"}
                ]
            ]
        }
        return msg, inline_keyboard
    except Exception as e:
        return f"⚠️ خطأ أثناء قراءة قاعدة البيانات: {e}", None

def get_persistent_reply_keyboard():
    return {
        "keyboard": [
            [{"text": "🔄 تحديث البيانات"}, {"text": "⚡ الفحص والتحويل الذكي"}],
            [{"text": "🎫 كروت ومستخدمي الهوت سبوت"}, {"text": "⚡ جودة الخطوط"}],
            [{"text": "🔒 عزل خط وي WAN2"}, {"text": "🔓 إلغاء عزل WAN2"}],
            [{"text": "📋 سجل الانقطاعات"}, {"text": "🛡️ مطابقة العزل"}]
        ],
        "resize_keyboard": True,
        "is_persistent": True
    }

def get_hotspot_report():
    try:
        conn = get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("""
            SELECT 
                COUNT(DISTINCT user_name) AS total_users,
                COUNT(DISTINCT CASE WHEN is_active THEN user_name END) AS active_sessions
            FROM hotspot_user_telemetry
            WHERE recorded_at >= NOW() - INTERVAL '15 minutes';
        """)
        stats = cur.fetchone() or {"total_users": 0, "active_sessions": 0}

        cur.execute("""
            SELECT DISTINCT ON (user_name)
                user_name,
                COALESCE(profile, 'default') AS profile,
                total_gb,
                limit_gb,
                is_active,
                session_uptime
            FROM hotspot_user_telemetry
            WHERE recorded_at >= NOW() - INTERVAL '15 minutes'
            ORDER BY user_name, total_gb DESC;
        """)
        users = cur.fetchall()
        conn.close()

        users.sort(key=lambda x: float(x.get('total_gb') or 0), reverse=True)

        msg = "🎫 <b>لوحة تحكم مستخدمي وكروت الهوت سبوت (Hotspot Users)</b>\n"
        msg += "━━━━━━━━━━━━━━━━━━━━━\n\n"
        msg += f"👥 إجمالي المستخدمين المتصلين: <b>{stats['active_sessions']}</b> متصل حالياً (من أصل {stats['total_users']} مسجل)\n\n"
        msg += "📊 <b>أعلى المستخدمين استهلاكاً للباقة:</b>\n"
        
        for u in users[:6]:
            act_icon = "🟢" if u['is_active'] else "⚪"
            uptime = f" | مدة: <code>{u['session_uptime']}</code>" if u.get('session_uptime') else ""
            limit = f" / {u['limit_gb']} GB" if u.get('limit_gb') else ""
            msg += f"{act_icon} <b>{u['user_name']}</b> [<code>{u['profile']}</code>]\n"
            msg += f"   • الاستهلاك: <b>{u['total_gb']} GB</b>{limit}{uptime}\n"

        inline_keyboard = {
            "inline_keyboard": [
                [
                    {"text": "🔄 تحديث تقرير الهوت سبوت", "callback_data": "hotspot_vouchers"}
                ],
                [
                    {"text": "🎛️ العودة للوحة التحكم الرئيسية", "callback_data": "refresh_status"}
                ]
            ]
        }
        return msg, inline_keyboard
    except Exception as e:
        return f"⚠️ خطأ أثناء قراءة تقرير الهوت سبوت: {e}", None

def get_smart_failover_status():
    try:
        conn = get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("""
            SELECT 
                interface_name,
                ROUND(AVG(latency_ms), 2) AS avg_latency_ms,
                MAX(latency_ms) AS max_latency_ms,
                ROUND(AVG(packet_loss_percent), 2) AS avg_packet_loss,
                MAX(packet_loss_percent) AS max_packet_loss,
                ROUND(AVG(jitter_ms), 2) AS avg_jitter_ms,
                COUNT(*) AS sample_count
            FROM (
                SELECT interface_name, latency_ms, packet_loss_percent, jitter_ms
                FROM mikrotik_wan_quality
                WHERE probed_at >= NOW() - INTERVAL '15 minutes'
                ORDER BY probed_at DESC
            ) q
            GROUP BY interface_name
            ORDER BY interface_name;
        """)
        rows = cur.fetchall()

        cur.execute("SELECT interface_name, is_isolated, isolated_reason FROM wan_incident_state;")
        incidents = {r['interface_name']: r for r in cur.fetchall()}
        conn.close()

        if not rows:
            return "ℹ️ لا توجد عينات جودة كافية خلال الـ 15 دقيقة الأخيرة للتقييم.", None

        msg = "⚡ <b>المحرك الذكي لفحص الاستقرار وتحويل الترافيك (Smart Failover Engine)</b>\n"
        msg += "━━━━━━━━━━━━━━━━━━━━━\n\n"

        degraded_lines = []
        for r in rows:
            iface = r['interface_name']
            inc = incidents.get(iface, {})
            avg_lat = float(r['avg_latency_ms'] or 0)
            avg_loss = float(r['avg_packet_loss'] or 0)
            
            is_bad = avg_lat > 150.0 or avg_loss > 10.0
            if is_bad and not inc.get('is_isolated'):
                degraded_lines.append(iface)

            icon = "🔴 غير مستقر" if is_bad else "🟢 ممتاز ومستقر"
            st_iso = " (🟡 معزول حالياً)" if inc.get('is_isolated') else ""
            msg += f"🌐 <b>خط {iface.upper()}:</b> {icon}{st_iso}\n"
            msg += f"  • متوسط الاستجابة: <b>{avg_lat} ms</b> (الذروة: {r['max_latency_ms']} ms)\n"
            msg += f"  • فقدان الحزم: <b>{avg_loss}%</b> (الذروة: {r['max_packet_loss']}%)\n"
            msg += f"  • تذبذب الإشارة (Jitter): <b>{r['avg_jitter_ms']} ms</b>\n\n"

        buttons = []
        if degraded_lines:
            msg += "⚠️ <b>توصية النظام:</b> تم رصد تدهور في مؤشرات الخطوط أعلاه! يمكنك تنفيذ العزل الفوري أدناه لتفادي تقطيع الإنترنت:\n"
            for d in degraded_lines:
                act = f"isolate_{d.lower()}"
                buttons.append([{"text": f"🔒 عزل فوري لخط {d.upper()}", "callback_data": act}])
        else:
            msg += "✅ <b>تقييم الذكاء الاصطناعي:</b> جميع خطوط WAN في أفضل حالاتها التشغيلية بدون فقدان حزم وبزمن استجابة فائق.\n"

        buttons.append([
            {"text": "🔄 إعادة الفحص الآن", "callback_data": "smart_failover"},
            {"text": "🎛️ لوحة التحكم", "callback_data": "refresh_status"}
        ])

        return msg, {"inline_keyboard": buttons}
    except Exception as e:
        return f"⚠️ خطأ أثناء تقييم المحرك الذكي: {e}", None

def execute_action(action, user_id):
    if user_id != ADMIN_CHAT_ID:
        return "⛔ غير مصرح لك بتنفيذ هذه العملية."
    
    conn = get_db()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    
    try:
        if action in ["isolate_wan1", "🔒 عزل خط فودافون WAN1"]:
            cur.execute("""
                UPDATE wan_incident_state
                SET is_isolated = TRUE, isolated_reason = 'Manual isolation via Telegram bot', isolated_at = NOW()
                WHERE router_id = 'home-router-01' AND LOWER(interface_name) = 'wan1';
            """)
            conn.commit()
            return "✅ تم عزل خط فودافون (WAN1) بنجاح."
        elif action in ["restore_wan1", "🔓 إعادة تفعيل WAN1"]:
            cur.execute("""
                UPDATE wan_incident_state
                SET is_isolated = FALSE, isolated_reason = NULL, isolated_at = NULL
                WHERE router_id = 'home-router-01' AND LOWER(interface_name) = 'wan1';
            """)
            conn.commit()
            return "✅ تم إلغاء عزل وإعادة تفعيل خط فودافون (WAN1)."
        elif action in ["isolate_wan2", "🔒 عزل خط وي WAN2"]:
            cur.execute("""
                UPDATE wan_incident_state
                SET is_isolated = TRUE, isolated_reason = 'Manual isolation via Telegram bot', isolated_at = NOW()
                WHERE router_id = 'home-router-01' AND LOWER(interface_name) = 'wan2';
            """)
            conn.commit()
            return "✅ تم عزل خط وي (WAN2) بنجاح وتوجيه كل الترافيك لفودافون."
        elif action in ["restore_wan2", "🔓 إلغاء عزل WAN2", "🔓 إعادة تفعيل WAN2"]:
            cur.execute("""
                UPDATE wan_incident_state
                SET is_isolated = FALSE, isolated_reason = NULL, isolated_at = NULL
                WHERE router_id = 'home-router-01' AND LOWER(interface_name) = 'wan2';
            """)
            conn.commit()
            return "✅ تم إلغاء عزل وإعادة دمج خط وي (WAN2) في الخدمة."
        elif action in ["recent_outages", "📋 سجل الانقطاعات"]:
            cur.execute("""
                SELECT interface_name, started_at, ended_at, duration_minutes, outage_cause, email_sent, email_recipient
                FROM wan_outage_events
                ORDER BY started_at DESC
                LIMIT 3;
            """)
            rows = cur.fetchall()
            if not rows:
                return "ℹ️ لا توجد انقطاعات مسجلة في السجل القانوني حتى الآن."
            res = "📋 <b>آخر سجلات الانقطاعات والمطالبات:</b>\n\n"
            for r in rows:
                p_text = "عطل مزود خدمة (ISP)" if r['outage_cause'] == 'ISP_FAILURE' else "انقطاع كهرباء"
                claim = f"تم إرسال الشكوى لـ {r['email_recipient']} ✅" if r['email_sent'] else "لم تُرسل"
                res += f"• <b>{r['interface_name'].upper()}</b> ({p_text}): مدة <b>{r['duration_minutes']} دقيقة</b>\n  المطالبة: <i>{claim}</i>\n"
            return res
        elif action in ["reconcile_status", "🛡️ مطابقة العزل"]:
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
            res = "🛡️ <b>تقرير مطابقة حالة الخطوط والعزل (WCCP PBR Sync):</b>\n\n"
            for r in i_rows:
                iface = r['interface_name']
                q = q_map.get(iface, {})
                used = q.get('used_percentage', 0)
                st = "🟡 معزول (ISOLATED)" if r['is_isolated'] else "🟢 مدمج بالخدمة (PCC Active)"
                res += f"• <b>خط {iface.upper()}:</b>\n"
                res += f"  - الاستهلاك: <b>{used}%</b> (المتبقي: <b>{q.get('remaining_gb', 0)} GB</b>)\n"
                res += f"  - حالة الراوتر: <b>{st}</b>\n"
                if r['is_isolated']:
                    res += f"  - سبب العزل: <i>{r['isolated_reason']}</i>\n"
                res += "\n"
            return res
        elif action in ["ping_quality", "⚡ جودة الخطوط", "/quality"]:
            cur.execute("""
                SELECT interface_name, target_host, latency_ms, packet_loss_percent, jitter_ms, status, probed_at
                FROM mikrotik_wan_quality
                WHERE probed_at >= NOW() - INTERVAL '10 minutes'
                ORDER BY probed_at DESC
                LIMIT 2;
            """)
            q_rows = cur.fetchall()
            if not q_rows:
                cur.execute("""
                    SELECT interface_name, target_host, latency_ms, packet_loss_percent, jitter_ms, status, probed_at
                    FROM mikrotik_wan_quality
                    ORDER BY probed_at DESC
                    LIMIT 2;
                """)
                q_rows = cur.fetchall()

            if not q_rows:
                return "⚡ <b>مؤشرات جودة الخطوط:</b>\nلا توجد بيانات فحص مسجلة حتى الآن."

            res = "⚡ <b>مؤشرات جودة الخطوط وزمن الاستجابة (Latency / Loss):</b>\n\n"
            for q in q_rows:
                st = "🟢 ممتاز وطبيعي" if q['status'] == 'HEALTHY' else ("🟡 تراجع في الجودة" if q['status'] == 'DEGRADED' else "🔴 انقطاع كامل")
                res += f"🌐 <b>خط {q['interface_name'].upper()}:</b>\n"
                res += f"  • زمن الاستجابة (Ping): <b>{q['latency_ms']} ms</b>\n"
                res += f"  • فقدان الحزم (Packet Loss): <b>{q['packet_loss_percent']}%</b>\n"
                res += f"  • الحالة الفنية: <b>{st}</b>\n"
                res += f"  • توقيت الفحص: <code>{q['probed_at'].strftime('%H:%M:%S')}</code>\n\n"
            return res
    finally:
        conn.close()
    return "تم استلام الأمر."

def run_bot():
    if not BOT_TOKEN:
        raise RuntimeError("TELEGRAM_BOT_TOKEN environment variable is required.")
    print("Starting MikroTik Telegram Polling Daemon with Smart Failover & Hotspot Engine...", flush=True)
    requests.post(f"{BASE_URL}/deleteWebhook?drop_pending_updates=False")
    
    offset = 0
    while True:
        try:
            r = requests.get(f"{BASE_URL}/getUpdates", params={"offset": offset, "timeout": 20}, timeout=25)
            data = r.json()
            if not data.get("ok"):
                print(f"Telegram API getUpdates error: {data}", flush=True)
                time.sleep(2)
                continue
            
            for update in data.get("result", []):
                offset = update["update_id"] + 1
                print(f"Received update: {update}", flush=True)
                
                if "message" in update:
                    msg = update["message"]
                    chat_id = msg.get("chat", {}).get("id")
                    text = (msg.get("text") or "").strip()
                    
                    if chat_id != ADMIN_CHAT_ID:
                        send_message(chat_id, "⛔ عفواً، هذا البوت مخصص لإدارة شبكة MikroTik لمدير النظام فقط.")
                        continue
                    
                    if text in ["/start", "/menu", "/status", "لوحة التحكم", "start", "menu"]:
                        text_resp, inline_markup = get_quota_dashboard()
                        send_message(chat_id, text_resp, inline_markup)
                        reply_keyboard = get_persistent_reply_keyboard()
                        send_message(chat_id, "👇 يمكنك أيضاً استخدام أزرار لوحة المفاتيح السريعة أدناه:", reply_keyboard)
                    elif text in ["/hotspot", "/vouchers", "🎫 كروت ومستخدمي الهوت سبوت", "hotspot_vouchers"]:
                        text_resp, inline_markup = get_hotspot_report()
                        send_message(chat_id, text_resp, inline_markup)
                    elif text in ["/failover", "⚡ الفحص والتحويل الذكي", "smart_failover"]:
                        text_resp, inline_markup = get_smart_failover_status()
                        send_message(chat_id, text_resp, inline_markup)
                    elif text in [
                        "🔄 تحديث البيانات", "⚡ جودة الخطوط", "🔒 عزل خط وي WAN2",
                        "🔓 إلغاء عزل WAN2", "📋 سجل الانقطاعات", "🛡️ مطابقة العزل",
                        "/quality", "/isolate_wan2", "/restore_wan2", "/sync"
                    ]:
                        action_map = {
                            "🔄 تحديث البيانات": "refresh_status",
                            "⚡ جودة الخطوط": "ping_quality",
                            "/quality": "ping_quality",
                            "🔒 عزل خط وي WAN2": "isolate_wan2",
                            "/isolate_wan2": "isolate_wan2",
                            "🔓 إلغاء عزل WAN2": "restore_wan2",
                            "/restore_wan2": "restore_wan2",
                            "📋 سجل الانقطاعات": "recent_outages",
                            "🛡️ مطابقة العزل": "reconcile_status",
                            "/sync": "reconcile_status"
                        }
                        mapped_action = action_map.get(text, text)
                        if mapped_action == "refresh_status":
                            text_resp, inline_markup = get_quota_dashboard()
                            send_message(chat_id, text_resp, inline_markup)
                        else:
                            res = execute_action(mapped_action, chat_id)
                            send_message(chat_id, res)
                            text_resp, inline_markup = get_quota_dashboard()
                            send_message(chat_id, text_resp, inline_markup)
                    else:
                        text_resp, inline_markup = get_quota_dashboard()
                        send_message(chat_id, text_resp, inline_markup)
                
                elif "callback_query" in update:
                    cb = update["callback_query"]
                    cb_id = cb["id"]
                    user_id = cb.get("from", {}).get("id")
                    action = cb.get("data")
                    chat_id = cb.get("message", {}).get("chat", {}).get("id")
                    
                    if action == "refresh_status":
                        answer_callback(cb_id, "جاري تحديث البيانات...")
                        text_resp, markup = get_quota_dashboard()
                        send_message(chat_id, text_resp, markup)
                    elif action == "hotspot_vouchers":
                        answer_callback(cb_id, "جاري تحميل تقرير الهوت سبوت...")
                        text_resp, markup = get_hotspot_report()
                        send_message(chat_id, text_resp, markup)
                    elif action == "smart_failover":
                        answer_callback(cb_id, "جاري فحص الاستقرار والمحرك الذكي...")
                        text_resp, markup = get_smart_failover_status()
                        send_message(chat_id, text_resp, markup)
                    else:
                        res = execute_action(action, user_id)
                        answer_callback(cb_id, "تم التنفيذ!")
                        send_message(chat_id, res)
                        text_resp, markup = get_quota_dashboard()
                        send_message(chat_id, text_resp, markup)

        except Exception as e:
            print(f"Exception in polling loop: {e}", flush=True)
            time.sleep(2)

if __name__ == "__main__":
    run_bot()
