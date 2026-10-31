import urllib.request
import json

url = 'https://api.telegram.org/botYOUR_TELEGRAM_BOT_TOKEN/sendMessage'
data = json.dumps({
    'chat_id': 123456789,
    'text': '🎛️ <b>لوحة التحكم والعمليات المباشرة - MikroTik WAN</b>\n\nيرجى تجربة الضغط على أحد الأزرار التفاعلية أدناه:',
    'parse_mode': 'HTML',
    'reply_markup': {
        'inline_keyboard': [
            [{'text': '🔄 تحديث البيانات الآن', 'callback_data': 'refresh_status'}],
            [{'text': '⚡ فحص جودة الخطوط (Latency)', 'callback_data': 'ping_quality'}],
            [{'text': '🔒 عزل خط وي WAN2', 'callback_data': 'isolate_wan2'},
             {'text': '🔓 إلغاء عزل WAN2', 'callback_data': 'restore_wan2'}]
        ]
    }
}).encode('utf-8')

req = urllib.request.Request(url, data=data, headers={'Content-Type': 'application/json'})
resp = urllib.request.urlopen(req)
print("SENT SUCCESS:", resp.status)
