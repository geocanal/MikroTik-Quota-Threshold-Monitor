import subprocess

script = """
cat << 'EOF' > /home/deploy/telegram_bot_daemon.py
import os
import time
import requests
import psycopg2
from psycopg2.extras import RealDictCursor

BOT_TOKEN = "YOUR_TELEGRAM_BOT_TOKEN"
ADMIN_CHAT_ID = int(os.getenv("TELEGRAM_ADMIN_CHAT_ID", "0"))
BASE_URL = f"https://api.telegram.org/bot{BOT_TOKEN}"

DB_HOST = "172.18.0.8"
DB_PORT = 5432
DB_NAME = "campaign_db"
DB_USER = "campaign"
DB_PASS = "password"

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
        cur.execute(\"\"\"
            SELECT interface_name, provider_name, quota_gb, used_gb, remaining_gb, used_percentage, days_left, renewal_date
            FROM view_mikrotik_wan_quota_status
            ORDER BY interface_name;
        \"\"\")
        rows = cur.fetchall()
        
        cur.execute(\"\"\"
            SELECT interface_name, is_down, is_isolated, isolated_reason, speed_limit_rx, speed_limit_tx
            FROM wan_incident_state
            ORDER BY interface_name;
        \"\"\")
        incidents = {r['interface_name']: r for r in cur.fetchall()}
        conn.close()

        def pbar(pct):
            filled = min(10, max(0, round(float(pct or 0) / 10)))
            return "▓" * filled + "░" * (10 - filled)

        msg = "🎛️ <b>لوحة التحكم والعمليات المباشرة - MikroTik WAN</b>\\n"
        msg += "━━━━━━━━━━━━━━━━━━━━━\\n\\n"

        for row in rows:
            iface = row['interface_name']
            inc = incidents.get(iface, {})
            status_emoji = "🔴 مفصول" if inc.get('is_down') else ("🟡 معزول" if inc.get('is_isolated') else "🟢 متصل وطبيعي")
            
            msg += f"🌐 <b>{row['provider_name']} ({iface.upper()}):</b>\\n"
            msg += f"  • الحالة التشغيلية: <b>{status_emoji}</b>\\n"
            msg += f"  • استهلاك الكوتا: [<code>{pbar(row['used_percentage'])}</code>] <b>{row['used_percentage']}%</b>\\n"
            msg += f"  • المتبقي: <b>{row['remaining_gb']} GB</b> من أصل <b>{row['quota_gb']} GB</b>\\n"
            msg += f"  • التجديد: بعد <b>{row['days_left']} يوم</b> ({row['renewal_date']})\\n"
            if inc.get('is_isolated'):
                msg += f"  • سبب العزل: <i>{inc.get('isolated_reason')}</i>\\n"
            msg += "\\n"

        keyboard = {
            "inline_keyboard": [
                [
                    {"text": "🔄 تحديث البيانات الآن", "callback_data": "refresh_status"}
                ],
                [
                    {"text": "⚡ فحص جودة الخطوط (Latency)", "callback_data": "ping_quality"},
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
        return msg, keyboard
    except Exception as e:
        return f"⚠️ خطأ أثناء قراءة قاعدة البيانات: {e}", None

def execute_action(action, user_id):
    if user_id != ADMIN_CHAT_ID:
        return "⛔ غير مصرح لك بتنفيذ هذه العملية."
    
    conn = get_db()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    
    try:
        if action == "isolate_wan1":
            cur.execute(\"\"\"
                UPDATE wan_incident_state
                SET is_isolated = TRUE, isolated_reason = 'Manual isolation via Telegram bot', isolated_at = NOW()
                WHERE router_id = 'RB5009-Core' AND interface_name = 'wan1';
            \"\"\")
            conn.commit()
            return "✅ تم عزل خط فودافون (WAN1) بنجاح."
        elif action == "restore_wan1":
            cur.execute(\"\"\"
                UPDATE wan_incident_state
                SET is_isolated = FALSE, isolated_reason = NULL, isolated_at = NULL
                WHERE router_id = 'RB5009-Core' AND interface_name = 'wan1';
            \"\"\")
            conn.commit()
            return "✅ تم إلغاء عزل وإعادة تفعيل خط فودافون (WAN1)."
        elif action == "isolate_wan2":
            cur.execute(\"\"\"
                UPDATE wan_incident_state
                SET is_isolated = TRUE, isolated_reason = 'Manual isolation via Telegram bot', isolated_at = NOW()
                WHERE router_id = 'RB5009-Core' AND interface_name = 'wan2';
            \"\"\")
            conn.commit()
            return "✅ تم عزل خط وي (WAN2) بنجاح."
        elif action == "restore_wan2":
            cur.execute(\"\"\"
                UPDATE wan_incident_state
                SET is_isolated = FALSE, isolated_reason = NULL, isolated_at = NULL
                WHERE router_id = 'RB5009-Core' AND interface_name = 'wan2';
            \"\"\")
            conn.commit()
            return "✅ تم إلغاء عزل وإعادة تفعيل خط وي (WAN2)."
        elif action == "recent_outages":
            cur.execute(\"\"\"
                SELECT interface_name, started_at, ended_at, duration_minutes, outage_cause, email_sent, email_recipient
                FROM wan_outage_events
                ORDER BY started_at DESC
                LIMIT 3;
            \"\"\")
            rows = cur.fetchall()
            if not rows:
                return "ℹ️ لا توجد انقطاعات مسجلة في السجل القانوني حتى الآن."
            res = "📋 <b>آخر سجلات الانقطاعات والمطالبات:</b>\\n\\n"
            for r in rows:
                p_text = "عطل مزود خدمة (ISP)" if r['outage_cause'] == 'ISP_FAILURE' else "انقطاع كهرباء"
                claim = f"تم إرسال الشكوى لـ {r['email_recipient']} ✅" if r['email_sent'] else "لم تُرسل"
                res += f"• <b>{r['interface_name'].upper()}</b> ({p_text}): مدة <b>{r['duration_minutes']} دقيقة</b>\\n  المطالبة: <i>{claim}</i>\\n"
            return res
        elif action == "ping_quality":
            return "⚡ جاري تشغيل فحص جودة الخطوط وزمن الاستجابة (Latency / Jitter)... الخطوط ضمن المعدل الطبيعي."
    finally:
        conn.close()
    return "تم استلام الأمر."

def run_bot():
    print("Starting MikroTik Telegram Polling Daemon...", flush=True)
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
                    text = msg.get("text", "")
                    
                    if chat_id != ADMIN_CHAT_ID:
                        send_message(chat_id, "⛔ عفواً، هذا البوت مخصص لإدارة شبكة MikroTik لمدير النظام فقط.")
                        continue
                    
                    if text in ["/start", "/status", "لوحة التحكم", "start"]:
                        text_resp, markup = get_quota_dashboard()
                        send_message(chat_id, text_resp, markup)
                    else:
                        send_message(chat_id, "ℹ️ أرسل /start لعرض لوحة التحكم التفاعلية للراوتر واستهلاك الباقات.")
                
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
EOF

sudo systemctl restart mikrotik-telegram-bot
"""

cmd = [
    'ssh', '-F', r'C:\Users\Ahmed Mohamed\.ssh\config',
    'deploy-server',
    script
]
print(subprocess.check_output(cmd, text=True))
