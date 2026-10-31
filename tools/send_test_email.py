
import requests
import json

payload = {
    "to": "admin@example.com",
    "subject": "شكوى رسمية ومطالبة بتعويض عن انقطاع خدمة الإنترنت - خط 055XXXXXXX",
    "html": """
    <div dir="rtl" style="font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; border: 1px solid #e0e0e0; border-radius: 8px; padding: 20px;">
        <h2 style="color: #d32f2f; border-bottom: 2px solid #d32f2f; padding-bottom: 10px;">عناية السادة / خدمة عملاء فودافون مصر (Vodafone DSL)</h2>
        <p>تحية طيبة وبعد،،،</p>
        
        <p>نحيط سيادتكم علماً بحدوث <b>انقطاع كامل في خدمة الإنترنت المنزلي DSL</b> على الخط الأرضي الخاص بنا، ونرفق لسيادتكم بيانات الواقعة المسجلة آلياً عبر أنظمة المراقبة والتحكم لشبكتنا:</p>
        
        <table style="width: 100%; border-collapse: collapse; margin: 20px 0; background: #f9f9f9;">
            <tr style="border-bottom: 1px solid #ddd;">
                <td style="padding: 10px; font-weight: bold; width: 40%;">اسم صاحب التعاقد:</td>
                <td style="padding: 10px;">اسم المشترك</td>
            </tr>
            <tr style="border-bottom: 1px solid #ddd;">
                <td style="padding: 10px; font-weight: bold;">رقم التليفون الأرضي:</td>
                <td style="padding: 10px; direction: ltr; text-align: right;">055XXXXXXX</td>
            </tr>
            <tr style="border-bottom: 1px solid #ddd;">
                <td style="padding: 10px; font-weight: bold;">وقت بدء الانقطاع:</td>
                <td style="padding: 10px;">28-09-2026 الساعة 08:45 صباحاً</td>
            </tr>
            <tr style="border-bottom: 1px solid #ddd;">
                <td style="padding: 10px; font-weight: bold;">وقت عودة الخدمة:</td>
                <td style="padding: 10px;">28-09-2026 الساعة 10:15 صباحاً</td>
            </tr>
            <tr style="border-bottom: 1px solid #ddd;">
                <td style="padding: 10px; font-weight: bold;">إجمالي فترة الانقطاع:</td>
                <td style="padding: 10px; color: #d32f2f; font-weight: bold;">ساعة و 30 دقيقة (90 دقيقة)</td>
            </tr>
            <tr>
                <td style="padding: 10px; font-weight: bold;">حالة مصدر الطاقة (الكهرباء):</td>
                <td style="padding: 10px; color: #2e7d32; font-weight: bold;">مستمر دون انقطاع (الراوتر استمر بالعمل Uptime: 1w 15h)</td>
            </tr>
        </table>

        <p>وحيث أن اللوائح الصادرة عن <b>الجهاز القومي لتنظيم الاتصالات (NTRA)</b> تضمن للمستخدمين الحق في جودة الخدمة واستمراريتها، وكذلك التعويض عن فترات انقطاع الخدمة غير المبررة والناتجة عن أعطال بالشبكة أو مزود الخدمة،</p>
        
        <p><b>لذا نلتمس من سيادتكم:</b></p>
        <ol style="margin-right: 20px;">
            <li>تسجيل شكوى رسمية بهذا الانقطاع وموافاتنا برقم الشكوى عبر البريد الإلكتروني.</li>
            <li>إضافة التعويض المستحق طبقاً للوائح الجهاز القومي لتنظيم الاتصالات (إضافة أيام خدمة بديلة أو تعويض بالجيجابايتس المقابلة لفترة العطل).</li>
        </ol>

        <p style="margin-top: 25px; border-top: 1px solid #eee; padding-top: 15px; font-size: 13px; color: #777;">
            تم إصدار هذه الرسالة وتوثيقها آلياً عبر منظومة MikroTik Telemetry & Automated Incident Monitor.<br>
            البريد المسجل للتعاقد والمراسلات: admin@example.com
        </p>
    </div>
    """
}

r = requests.post("http://172.18.0.1:8000/send-email", json=payload, timeout=15)
print("STATUS:", r.status_code)
print("RESPONSE:", r.text)
