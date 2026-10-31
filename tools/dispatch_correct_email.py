import subprocess

script = """
cat << 'EOF' > /tmp/send_test_email.py
import requests

payload = {
    "to_email": "admin@example.com",
    "subject": "شكوى رسمية ومطالبة بتعويض عن انقطاع خدمة الإنترنت - خط 055XXXXXXX",
    "html_content": '''
    <div dir="rtl" style="font-family: Arial, sans-serif; line-height: 1.6; color: #222; max-width: 600px; border: 1px solid #e0e0e0; border-radius: 8px; padding: 20px; background-color: #ffffff;">
        <div style="background-color: #e60000; color: white; padding: 15px; border-radius: 6px; text-align: center; margin-bottom: 20px;">
            <h2 style="margin: 0; font-size: 20px;">إخطار انقطاع خدمة وتوثيق شكوى رسمية</h2>
            <p style="margin: 5px 0 0 0; font-size: 14px;">الجهاز القومي لتنظيم الاتصالات (NTRA) & خدمة عملاء فودافون</p>
        </div>

        <p>السادة / <b>خدمة عملاء شركة فودافون مصر (Vodafone DSL)</b> المحترمون،</p>
        <p>تحية طيبة وبعد،،،</p>
        
        <p>نحيط سيادتكم علماً برصد وتوثيق <b>انقطاع كامل في خدمة الإنترنت المنزلي</b> عبر أنظمة التليمتري والمراقبة الآلية للشبكة، ونوافيكم بالبيانات الفنية الدقيقة للواقعة:</p>
        
        <table style="width: 100%; border-collapse: collapse; margin: 15px 0; font-size: 14px;">
            <tr style="background-color: #f8f9fa; border-bottom: 1px solid #ddd;">
                <td style="padding: 10px; font-weight: bold; width: 45%;">اسم صاحب التعاقد:</td>
                <td style="padding: 10px;"><b>اسم المشترك</b></td>
            </tr>
            <tr style="border-bottom: 1px solid #ddd;">
                <td style="padding: 10px; font-weight: bold;">رقم التليفون الأرضي (DSL):</td>
                <td style="padding: 10px; direction: ltr; text-align: right;"><b>055XXXXXXX</b></td>
            </tr>
            <tr style="background-color: #f8f9fa; border-bottom: 1px solid #ddd;">
                <td style="padding: 10px; font-weight: bold;">وقت بدء العطل والانقطاع:</td>
                <td style="padding: 10px;">28-09-2026 الساعة <b>08:45 صباحاً</b></td>
            </tr>
            <tr style="border-bottom: 1px solid #ddd;">
                <td style="padding: 10px; font-weight: bold;">وقت استعادة الخدمة:</td>
                <td style="padding: 10px;">28-09-2026 الساعة <b>10:15 صباحاً</b></td>
            </tr>
            <tr style="background-color: #fff3cd; border-bottom: 1px solid #ffeeba;">
                <td style="padding: 10px; font-weight: bold; color: #856404;">إجمالي مدة انقطاع الخدمة:</td>
                <td style="padding: 10px; color: #856404; font-weight: bold;">ساعة و 30 دقيقة (90 دقيقة)</td>
            </tr>
            <tr style="background-color: #d4edda; color: #155724;">
                <td style="padding: 10px; font-weight: bold;">حالة مصدر الطاقة (الكهرباء):</td>
                <td style="padding: 10px; font-weight: bold;">مستمر دون انقطاع (الراوتر يعمل بشكل متصل Uptime: 1w 15h)</td>
            </tr>
        </table>

        <div style="background-color: #f1f3f5; border-right: 4px solid #1971c2; padding: 12px; margin: 15px 0; font-size: 13px;">
            <b>📌 سند المطالبة واللوائح المنظمة:</b><br>
            بناءً على التعليمات والقرارات التنظيمية الصادرة عن <b>الجهاز القومي لتنظيم الاتصالات (NTRA)</b> بشأن حقوق مستخدمي الاتصالات وجودة الخدمة، يحق للمشترك الحصول على تعويض مناسب عن فترات انقطاع الخدمة الناتجة عن أعطال بالشبكة أو مزود الخدمة دون إخطار مسبق.
        </div>

        <p><b>المطلوب برجاء التكرم بـ:</b></p>
        <ul style="margin: 10px 0; padding-right: 20px;">
            <li>قيد وتسجيل الشكوى وتزويدنا برقم الشكوى الرسمي للمتابعة مع الجهاز القومي لتنظيم الاتصالات.</li>
            <li>إضافة التعويض المستحق عن فترة الانقطاع على الخط.</li>
        </ul>

        <div style="margin-top: 25px; border-top: 1px solid #eee; padding-top: 15px; font-size: 12px; color: #6c757d; text-align: center;">
            تم توليد هذا التقرير الفني آلياً بواسطة MikroTik Incident Monitor & Control Plane.<br>
            البريد الإلكتروني للعميل: admin@example.com
        </div>
    </div>
    '''
}

r = requests.post("http://n8n-text-overlay:8000/send-email", json=payload, timeout=20)
print("FINAL_STATUS_CODE:", r.status_code)
print("FINAL_RESPONSE_BODY:", r.text)
EOF

sudo docker run --rm --network n8n_n8n -v /tmp/send_test_email.py:/tmp/send_test_email.py python:3.11-alpine sh -c "pip install requests -q && python /tmp/send_test_email.py"
"""

cmd = [
    'ssh', '-F', r'C:\Users\Ahmed Mohamed\.ssh\config',
    'deploy-server',
    script
]
print(subprocess.check_output(cmd, text=True))
