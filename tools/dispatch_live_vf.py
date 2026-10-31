import subprocess

script = """
cat << 'EOF' > /tmp/send_live_vf_email.py
import requests

payload = {
    "to_email": "vodafone.online@vodafone.com",
    "cc_email": "admin@example.com",
    "subject": "شكوى انقطاع خدمة الإنترنت والمطالبة بالتعويض - خط رقم: 055XXXXXXX",
    "html_content": '''
    <div dir="rtl" style="font-family: Arial, Tahoma, sans-serif; line-height: 1.8; color: #222; max-width: 650px; margin: auto; padding: 20px; border: 1px solid #e0e0e0; border-radius: 8px;">
        <h2 style="color: #b71c1c; border-bottom: 2px solid #b71c1c; padding-bottom: 8px; margin-top: 0;">
            عناية السادة / خدمة عملاء وشكاوى شركة فودافون مصر (Vodafone DSL) المحترمين
        </h2>
        <p style="font-size: 15px;">تحية طيبة وبعد،،،</p>
        <p style="font-size: 15px;">
            أحيط سيادتكم علماً بحدوث <b>انقطاع كامل في خدمة الإنترنت المنزلي</b> على الخط الأرضي الخاص بي، وتجدون أدناه تفاصيل مدة وفترة الانقطاع بالتحديد:
        </p>
        
        <table style="width: 100%; border-collapse: collapse; margin: 15px 0; font-size: 14px;">
            <tr style="background-color: #f7f7f7;">
                <td style="padding: 10px; border: 1px solid #ddd; font-weight: bold; width: 35%;">اسم صاحب التعاقد:</td>
                <td style="padding: 10px; border: 1px solid #ddd;">اسم المشترك</td>
            </tr>
            <tr>
                <td style="padding: 10px; border: 1px solid #ddd; font-weight: bold;">رقم التليفون الأرضي:</td>
                <td style="padding: 10px; border: 1px solid #ddd; font-weight: bold; color: #0d47a1;">055XXXXXXX</td>
            </tr>
            <tr style="background-color: #f7f7f7;">
                <td style="padding: 10px; border: 1px solid #ddd; font-weight: bold;">توقيت بدء الانقطاع:</td>
                <td style="padding: 10px; border: 1px solid #ddd; color: #c62828;">28-09-2026 الساعة 08:45 صباحاً</td>
            </tr>
            <tr>
                <td style="padding: 10px; border: 1px solid #ddd; font-weight: bold;">توقيت استعادة الخدمة:</td>
                <td style="padding: 10px; border: 1px solid #ddd; color: #2e7d32;">28-09-2026 الساعة 10:15 صباحاً</td>
            </tr>
            <tr style="background-color: #f7f7f7;">
                <td style="padding: 10px; border: 1px solid #ddd; font-weight: bold;">إجمالي فترة التوقف:</td>
                <td style="padding: 10px; border: 1px solid #ddd; font-weight: bold; color: #b71c1c;">ساعة و 30 دقيقة (90 دقيقة)</td>
            </tr>
            <tr>
                <td style="padding: 10px; border: 1px solid #ddd; font-weight: bold;">حالة مصدر الطاقة (الكهرباء):</td>
                <td style="padding: 10px; border: 1px solid #ddd;">التيار الكهربائي والأجهزة تعمل بشكل مستمر دون انقطاع</td>
            </tr>
        </table>

        <div style="background-color: #fff8e1; border-right: 4px solid #ffa000; padding: 12px; margin: 15px 0; font-size: 14px;">
            <b>المطالبة بالتعويض:</b><br/>
            بناءً على القواعد وحقوق المستخدمين المقررة من <b>الجهاز القومي لتنظيم الاتصالات (NTRA)</b>، وبما أن العطل غير ناتج عن انقطاع كهرباء لدي، أرجو من سيادتكم احتساب فترة التوقف وإضافة <b>التعويض المستحق (جيجابايتس إضافية أو خصم قيمة الانقطاع من الفاتورة)</b> لحساب المشترك مع موافاتي برقم الشكوى.
        </div>

        <p style="font-size: 14px; margin-top: 20px;">
            شاكرين حسن تعاونكم وسرعة استجابتكم.<br/>
            <b>مقدمه لسيادتكم:</b> اسم المشترك<br/>
            <b>رقم الاشتراك:</b> 055XXXXXXX
        </p>
    </div>
    '''
}

r = requests.post("http://n8n-text-overlay:8000/send-email", json=payload, timeout=25)
print("LIVE_VF_EMAIL_RESULT:", r.json())
EOF

sudo docker run --rm --network n8n_n8n -v /tmp/send_live_vf_email.py:/tmp/send_live_vf_email.py python:3.11-alpine sh -c "pip install requests -q && python /tmp/send_live_vf_email.py"
"""

cmd = [
    'ssh', '-F', r'C:\Users\Ahmed Mohamed\.ssh\config',
    'deploy-server',
    script
]
print(subprocess.check_output(cmd, text=True))
