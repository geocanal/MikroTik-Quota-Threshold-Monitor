import json

with open("MikroTik - Quota Threshold Monitor.json", "r", encoding="utf-8") as f:
    wf = json.load(f)

nodes = wf["nodes"]
connections = wf["connections"]

# 1. Update "Check WAN Inactivity1" query
for n in nodes:
    if n["name"] == "Check WAN Inactivity1":
        n["parameters"]["query"] = """WITH recent_stats AS (
    SELECT 
        (wan1_rx_bytes + wan1_tx_bytes) AS wan1_bytes,
        (wan2_rx_bytes + wan2_tx_bytes) AS wan2_bytes
    FROM mikrotik_wan_usage
    WHERE router_id = $1
    ORDER BY usage_at DESC
    LIMIT 3
),
aggregates AS (
    SELECT 
        SUM(wan1_bytes) AS sum_wan1,
        SUM(wan2_bytes) AS sum_wan2,
        COUNT(*) AS total_samples
    FROM recent_stats
)
SELECT 
    a.sum_wan1,
    a.sum_wan2,
    CASE 
        WHEN a.total_samples >= 3 AND a.sum_wan1 = 0 AND a.sum_wan2 > 100000 THEN TRUE 
        ELSE FALSE 
    END AS wan1_suspected_down,
    CASE 
        WHEN a.total_samples >= 3 AND a.sum_wan2 = 0 AND a.sum_wan1 > 100000 THEN TRUE 
        ELSE FALSE 
    END AS wan2_suspected_down,
    s1.is_down AS wan1_currently_down,
    s1.outage_started_at AS wan1_outage_started_at,
    s2.is_down AS wan2_currently_down,
    s2.outage_started_at AS wan2_outage_started_at,
    q1.landline_number AS wan1_landline,
    q1.account_holder AS wan1_holder,
    q1.support_email AS wan1_email,
    q2.landline_number AS wan2_landline,
    q2.account_holder AS wan2_holder,
    q2.support_email AS wan2_email
FROM aggregates a
CROSS JOIN (SELECT is_down, outage_started_at FROM wan_incident_state WHERE router_id = $1 AND interface_name = 'wan1') s1
CROSS JOIN (SELECT is_down, outage_started_at FROM wan_incident_state WHERE router_id = $1 AND interface_name = 'wan2') s2
CROSS JOIN (SELECT landline_number, account_holder, support_email FROM mikrotik_wan_quotas WHERE router_id = $1 AND interface_name = 'wan1') q1
CROSS JOIN (SELECT landline_number, account_holder, support_email FROM mikrotik_wan_quotas WHERE router_id = $1 AND interface_name = 'wan2') q2;"""

    if n["name"] == "Process WAN Alerts":
        n["parameters"]["jsCode"] = """const item = $input.first().json;
const routerId = $('Calculate WAN Delta').first().json.router_id;

if (!item) return [];

let alerts = [];
const nowIso = new Date().toISOString();

function formatCairo(dateObj) {
  if (!dateObj) return 'غير محدد';
  return new Date(dateObj).toLocaleString('ar-EG', {
    timeZone: 'Africa/Cairo',
    year: 'numeric', month: '2-digit', day: '2-digit',
    hour: '2-digit', minute: '2-digit', second: '2-digit'
  });
}

function buildCompensationEmail(provider, landline, holder, startAt, endAt, durationMin) {
  const hours = Math.floor(durationMin / 60);
  const mins = durationMin % 60;
  const durationText = hours > 0 ? `${hours} ساعة و ${mins} دقيقة` : `${mins} دقيقة`;
  const startStr = formatCairo(startAt);
  const endStr = formatCairo(endAt);

  const subject = `شكوى انقطاع خدمة الإنترنت والمطالبة بالتعويض - خط رقم: ${landline}`;
  
  const html = `
  <div dir="rtl" style="font-family: Arial, Tahoma, sans-serif; line-height: 1.8; color: #222; max-width: 650px; margin: auto; padding: 20px; border: 1px solid #e0e0e0; border-radius: 8px;">
    <h2 style="color: #b71c1c; border-bottom: 2px solid #b71c1c; padding-bottom: 8px; margin-top: 0;">
      عناية السادة / خدمة عملاء وشكاوى ${provider} المحترمين
    </h2>
    <p style="font-size: 15px;">تحية طيبة وبعد،،،</p>
    <p style="font-size: 15px;">
      أحيط سيادتكم علماً بحدوث <b>انقطاع كامل في خدمة الإنترنت المنزلي</b> على الخط الأرضي الخاص بي، وتجدون أدناه تفاصيل مدة وفترة الانقطاع بالتحديد:
    </p>
    
    <table style="width: 100%; border-collapse: collapse; margin: 15px 0; font-size: 14px;">
      <tr style="background-color: #f7f7f7;">
        <td style="padding: 10px; border: 1px solid #ddd; font-weight: bold; width: 35%;">اسم صاحب التعاقد:</td>
        <td style="padding: 10px; border: 1px solid #ddd;">${holder}</td>
      </tr>
      <tr>
        <td style="padding: 10px; border: 1px solid #ddd; font-weight: bold;">رقم التليفون الأرضي:</td>
        <td style="padding: 10px; border: 1px solid #ddd; font-weight: bold; color: #0d47a1;">${landline}</td>
      </tr>
      <tr style="background-color: #f7f7f7;">
        <td style="padding: 10px; border: 1px solid #ddd; font-weight: bold;">توقيت بدء الانقطاع:</td>
        <td style="padding: 10px; border: 1px solid #ddd; color: #c62828;">${startStr}</td>
      </tr>
      <tr>
        <td style="padding: 10px; border: 1px solid #ddd; font-weight: bold;">توقيت استعادة الخدمة:</td>
        <td style="padding: 10px; border: 1px solid #ddd; color: #2e7d32;">${endStr}</td>
      </tr>
      <tr style="background-color: #f7f7f7;">
        <td style="padding: 10px; border: 1px solid #ddd; font-weight: bold;">إجمالي فترة التوقف:</td>
        <td style="padding: 10px; border: 1px solid #ddd; font-weight: bold; color: #b71c1c;">${durationText} (${durationMin} دقيقة)</td>
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
      <b>مقدمه لسيادتكم:</b> ${holder}<br/>
      <b>رقم الاشتراك:</b> ${landline}
    </p>
  </div>
  `;

  return { subject, html };
}

// WAN1 (Vodafone)
if (item.wan1_suspected_down && !item.wan1_currently_down) {
  alerts.push({
    router_id: routerId,
    interface: 'wan1',
    provider_name: 'Vodafone DSL',
    landline_number: item.wan1_landline || '055XXXXXXX',
    account_holder: item.wan1_holder || 'اسم المشترك',
    support_email: item.wan1_email || 'vodafone.online@vodafone.com',
    event: 'DOWN',
    is_down: true,
    started_at: nowIso,
    ended_at: null,
    duration_minutes: null,
    should_send_email: false,
    message: `🚨 <b>تحذير: توقف خدمة الإنترنت على WAN1 (فودافون)</b>\\n\\nالراوتر: <code>${routerId}</code>\\nالخط الأرضي: <code>${item.wan1_landline}</code>\\n⏱️ وقت بدء الانقطاع: <code>${formatCairo(nowIso)}</code>\\nℹ️ تم التأكد أن الراوتر والكهرباء تعملان طبيعياً (انقطاع من مزود الخدمة).`
  });
} else if (!item.wan1_suspected_down && item.wan1_currently_down) {
  const startedAt = item.wan1_outage_started_at ? new Date(item.wan1_outage_started_at) : new Date(Date.now() - 15 * 60000);
  const endedAt = new Date();
  const durationMin = Math.max(1, Math.round((endedAt.getTime() - startedAt.getTime()) / 60000));
  
  const emailData = buildCompensationEmail('شركة فودافون مصر (Vodafone DSL)', item.wan1_landline, item.wan1_holder, startedAt, endedAt, durationMin);

  alerts.push({
    router_id: routerId,
    interface: 'wan1',
    provider_name: 'Vodafone DSL',
    landline_number: item.wan1_landline || '055XXXXXXX',
    account_holder: item.wan1_holder || 'اسم المشترك',
    support_email: item.wan1_email || 'vodafone.online@vodafone.com',
    event: 'RECOVERED',
    is_down: false,
    started_at: startedAt.toISOString(),
    ended_at: endedAt.toISOString(),
    duration_minutes: durationMin,
    should_send_email: true,
    email_subject: emailData.subject,
    email_html: emailData.html,
    message: `✅ <b>استعادة اتصال WAN1 (فودافون) - تم إرسال طلب التعويض</b>\\n\\nالراوتر: <code>${routerId}</code>\\nالخط الأرضي: <code>${item.wan1_landline}</code>\\n⏱️ مدة الانقطاع الفعلي: <b>${durationMin} دقيقة</b>\\n📩 <i>تم إرسال إيميل رسمي تلقائياً لخدمة عملاء فودافون للمطالبة بالتعويض عن فترة التوقف طبقاً للائحة NTRA.</i>`
  });
}

// WAN2 (WE Egypt)
if (item.wan2_suspected_down && !item.wan2_currently_down) {
  alerts.push({
    router_id: routerId,
    interface: 'wan2',
    provider_name: 'WE Egypt (DSL/Fiber)',
    landline_number: item.wan2_landline || '055YYYYYYY',
    account_holder: item.wan2_holder || 'اسم المشترك',
    support_email: item.wan2_email || 'CustomerCare@te.eg',
    event: 'DOWN',
    is_down: true,
    started_at: nowIso,
    ended_at: null,
    duration_minutes: null,
    should_send_email: false,
    message: `🚨 <b>تحذير: توقف خدمة الإنترنت على WAN2 (شركة وي - WE)</b>\\n\\nالراوتر: <code>${routerId}</code>\\nالخط الأرضي: <code>${item.wan2_landline}</code>\\n⏱️ وقت بدء الانقطاع: <code>${formatCairo(nowIso)}</code>\\nℹ️ تم التأكد أن الراوتر والكهرباء تعملان طبيعياً (انقطاع من مزود الخدمة).`
  });
} else if (!item.wan2_suspected_down && item.wan2_currently_down) {
  const startedAt = item.wan2_outage_started_at ? new Date(item.wan2_outage_started_at) : new Date(Date.now() - 15 * 60000);
  const endedAt = new Date();
  const durationMin = Math.max(1, Math.round((endedAt.getTime() - startedAt.getTime()) / 60000));
  
  const emailData = buildCompensationEmail('الشركة المصرية للاتصالات (WE)', item.wan2_landline, item.wan2_holder, startedAt, endedAt, durationMin);

  alerts.push({
    router_id: routerId,
    interface: 'wan2',
    provider_name: 'WE Egypt (DSL/Fiber)',
    landline_number: item.wan2_landline || '055YYYYYYY',
    account_holder: item.wan2_holder || 'اسم المشترك',
    support_email: item.wan2_email || 'CustomerCare@te.eg',
    event: 'RECOVERED',
    is_down: false,
    started_at: startedAt.toISOString(),
    ended_at: endedAt.toISOString(),
    duration_minutes: durationMin,
    should_send_email: true,
    email_subject: emailData.subject,
    email_html: emailData.html,
    message: `✅ <b>استعادة اتصال WAN2 (شركة وي) - تم إرسال طلب التعويض</b>\\n\\nالراوتر: <code>${routerId}</code>\\nالخط الأرضي: <code>${item.wan2_landline}</code>\\n⏱️ مدة الانقطاع الفعلي: <b>${durationMin} دقيقة</b>\\n📩 <i>تم إرسال إيميل رسمي تلقائياً لخدمة عملاء WE للمطالبة بالتعويض عن فترة التوقف طبقاً للائحة NTRA.</i>`
  });
}

return alerts.map(a => ({ json: a }));"""

    if n["name"] == "Update Incident State":
        n["parameters"]["query"] = """INSERT INTO wan_incident_state (
    router_id,
    interface_name,
    is_down,
    outage_started_at,
    last_alert_sent_at,
    updated_at
)
VALUES (
    $1,
    $2,
    (CASE WHEN $3 = 'DOWN' THEN TRUE ELSE FALSE END),
    (CASE WHEN $3 = 'DOWN' THEN NOW() ELSE NULL END),
    NOW(),
    NOW()
)
ON CONFLICT (router_id, interface_name)
DO UPDATE SET
    is_down = EXCLUDED.is_down,
    outage_started_at = (CASE WHEN EXCLUDED.is_down THEN COALESCE(wan_incident_state.outage_started_at, NOW()) ELSE NULL END),
    last_alert_sent_at = NOW(),
    updated_at = NOW();"""
        n["parameters"]["options"]["queryReplacement"] = "={{ [\n  $json.router_id,\n  $json.interface,\n  $json.event\n] }}"

# Add new nodes if not already present
node_names = [n["name"] for n in nodes]

if "Should Dispatch Compensation Email?" not in node_names:
    nodes.append({
        "parameters": {
            "conditions": {
                "boolean": [
                    {
                        "value1": "={{ $json.should_send_email }}",
                        "value2": True
                    }
                ]
            }
        },
        "type": "n8n-nodes-base.if",
        "typeVersion": 1,
        "position": [3160, 512],
        "id": "if-should-email-compensation",
        "name": "Should Dispatch Compensation Email?"
    })

if "Dispatch Compensation Email" not in node_names:
    nodes.append({
        "parameters": {
            "method": "POST",
            "url": "http://n8n-text-overlay:8000/send-email",
            "sendBody": True,
            "specifyBody": "json",
            "jsonBody": "={{ JSON.stringify({\n  to_email: $json.support_email,\n  cc_email: 'admin@example.com',\n  subject: $json.email_subject,\n  html_content: $json.email_html\n}) }}",
            "options": {}
        },
        "type": "n8n-nodes-base.httpRequest",
        "typeVersion": 4.2,
        "position": [3380, 416],
        "id": "http-dispatch-compensation-email",
        "name": "Dispatch Compensation Email"
    })

if "Log Outage Event in DB" not in node_names:
    nodes.append({
        "parameters": {
            "operation": "executeQuery",
            "query": """INSERT INTO wan_outage_events (
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
    email_subject,
    email_body
)
VALUES (
    $1, $2, $3, $4, $5, $6, $7, $8, 'ISP_FAILURE', TRUE, NOW(), $9, $10, $11
);""",
            "options": {
                "queryReplacement": "={{ [\n  $('Process WAN Alerts').item.json.router_id,\n  $('Process WAN Alerts').item.json.interface,\n  $('Process WAN Alerts').item.json.provider_name,\n  $('Process WAN Alerts').item.json.landline_number,\n  $('Process WAN Alerts').item.json.account_holder,\n  $('Process WAN Alerts').item.json.started_at,\n  $('Process WAN Alerts').item.json.ended_at,\n  $('Process WAN Alerts').item.json.duration_minutes,\n  $('Process WAN Alerts').item.json.support_email,\n  $('Process WAN Alerts').item.json.email_subject,\n  $('Process WAN Alerts').item.json.email_html\n] }}"
            }
        },
        "type": "n8n-nodes-base.postgres",
        "typeVersion": 2.7,
        "position": [3600, 416],
        "id": "pg-log-outage-event",
        "name": "Log Outage Event in DB",
        "credentials": {
            "postgres": {
                "id": "XKwdrIadj1gSLirP",
                "name": "Postgres account"
            }
        }
    })

# Connect Process WAN Alerts -> Should Dispatch Compensation Email?
if "Process WAN Alerts" in connections:
    targets = connections["Process WAN Alerts"]["main"][0]
    target_names = [t["node"] for t in targets]
    if "Should Dispatch Compensation Email?" not in target_names:
        targets.append({
            "node": "Should Dispatch Compensation Email?",
            "type": "main",
            "index": 0
        })

# Connect Should Dispatch Compensation Email? -> Dispatch Compensation Email
connections["Should Dispatch Compensation Email?"] = {
    "main": [
        [
            {
                "node": "Dispatch Compensation Email",
                "type": "main",
                "index": 0
            }
        ],
        []
    ]
}

# Connect Dispatch Compensation Email -> Log Outage Event in DB
connections["Dispatch Compensation Email"] = {
    "main": [
        [
            {
                "node": "Log Outage Event in DB",
                "type": "main",
                "index": 0
            }
        ]
    ]
}

with open("MikroTik - Quota Threshold Monitor.json", "w", encoding="utf-8") as f:
    json.dump(wf, f, ensure_ascii=False, indent=2)

print("WORKFLOW_UPDATED_SUCCESSFULLY")
