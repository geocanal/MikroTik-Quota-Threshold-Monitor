# أداة المحاكاة الجافة لتنبيهات الحصص (Quota Alert Dry-Run)

أداة معزولة وخالية من الآثار الجانبية (Pure Offline CLI & API) لاختبار ومحاكاة منطق تنبيهات استهلاك الحصص لراوترات MikroTik وفقاً لقواعد التصدير المحلي المستخرجة من `MikroTik - Quota Threshold Monitor.json / Check Quota Thresholds`.
ملاحظة: سياق الاختبار `/input/current_threshold_query.sql` ليس مثبتاً ولا مطلوباً في وقت التشغيل.

---

## 1. مثال إدخال تركيبي كامل وجاهز للنسخ (Synthetic Input Example)

فيما يلي مثال JSON تركيبي متكامل يوضح حالات الشرائح المختلفة والواجهات وحالة التنبيه السابقة:

```json
{
  "statuses": [
    {
      "router_id": "روتر-القاهرة-01",
      "interface_name": "ether1-wan",
      "cycle_start": "2026-10-01",
      "used_percentage": 50.0
    },
    {
      "router_id": "روتر-القاهرة-01",
      "interface_name": "ether2-wan",
      "cycle_start": "2026-10-01",
      "used_percentage": 85.5
    },
    {
      "router_id": "rt-alex-02",
      "interface_name": "ether1-wan",
      "cycle_start": "2026-10-01",
      "used_percentage": 96.0
    },
    {
      "router_id": "rt-giza-03",
      "interface_name": "ether1-wan",
      "cycle_start": "2026-10-01",
      "used_percentage": 99.2
    }
  ],
  "alert_state": [
    {
      "router_id": "rt-alex-02",
      "interface_name": "ether1-wan",
      "cycle_start": "2026-10-01",
      "alerted_80": true,
      "alerted_95": true,
      "alerted_100": false
    }
  ]
}
```

---

## 2. أوامر التشغيل (CLI Usage)

```bash
# قراءة الإدخال من ملف JSON محلي
python quota_alert_dry_run.py sample_payload.json

# قراءة الإدخال عبر الدخل القياسي (stdin)
cat sample_payload.json | python quota_alert_dry_run.py -

# عرض خيارات المساعدة
python quota_alert_dry_run.py --help
```

### المخرجات المتوقعة للأمر أعلاه (Expected Output JSON)
```json
{
  "dry_run": true,
  "side_effects": false,
  "would_send": 2,
  "results": [
    {
      "router_id": "روتر-القاهرة-01",
      "interface_name": "ether1-wan",
      "cycle_start": "2026-10-01",
      "triggered_tier": null,
      "reason": "below_threshold"
    },
    {
      "router_id": "روتر-القاهرة-01",
      "interface_name": "ether2-wan",
      "cycle_start": "2026-10-01",
      "triggered_tier": "80",
      "reason": "would_alert"
    },
    {
      "router_id": "rt-alex-02",
      "interface_name": "ether1-wan",
      "cycle_start": "2026-10-01",
      "triggered_tier": null,
      "reason": "already_alerted"
    },
    {
      "router_id": "rt-giza-03",
      "interface_name": "ether1-wan",
      "cycle_start": "2026-10-01",
      "triggered_tier": "100",
      "reason": "would_alert"
    }
  ]
}
```

### رموز الخروج (Exit Status Codes)
- **`0`**: نجاح العملية، وتُطبع مخرجات JSON الصالحة بترميز UTF-8 على `stdout`.
- **`2`**: خطأ في التحقق من صحة المدخلات (تنسيق غير صالح، مفاتيح غير مسموح بها، مفاتيح مكررة، ملف غير موجود، حجم > 1 MiB، أو ترميز خاطئ). في هذه الحالة يكون `stdout` فارغاً تماماً وتُطبع رسالة خطأ آمنة لا تسرب المسارات أو المدخلات على `stderr`.

---

## 3. مخطط البيانات (Schema)

### المدخلات (Input JSON)
- كائن JSON بترميز UTF-8 لا يتجاوز 1 ميجابايت (1 MiB).
- المفتاح `statuses` (مطلوب): مصفوفة لا تتعدى 1000 عنصر، كل عنصر يحتوي على:
  - `router_id` (نص غير فارغ وبدون فراغات زائدة <= 64 حرف).
  - `interface_name` (نص غير فارغ وبدون فراغات زائدة <= 32 حرف).
  - `cycle_start` (تاريخ ميلادي صحيح بصيغة `YYYY-MM-DD`).
  - `used_percentage` (رقم عشري موجب أو صفري، غير تقريبي).
- المفتاح `alert_state` (اختياري، الافتراضي `[]`): مصفوفة لا تتعدى 1000 عنصر، تحتوي على المفاتيح الثلاثة للتعريف بالإضافة إلى الأعلام الاختيارية (`alerted_80`, `alerted_95`, `alerted_100` وقيمها الافتراضية `false`).

---

## 4. سلوك الشرائح وحد 99% مقابل 100% (Threshold & Cycle Behavior)

1. **النسبة < 80%**:
   - `triggered_tier`: `null`
   - `reason`: `"below_threshold"`
2. **النسبة 80% <= used_percentage < 95%**:
   - فحص راية `alerted_80` فقط: إذا كانت `true` فالسبب `"already_alerted"`، وإذا كانت `false` يتم إطلاق الشريحة `"80"` والسبب `"would_alert"`.
3. **النسبة 95% <= used_percentage < 99%**:
   - فحص راية `alerted_95` فقط: إذا كانت `true` فالسبب `"already_alerted"`، وإذا كانت `false` يتم إطلاق الشريحة `"95"` والسبب `"would_alert"`.
4. **النسبة >= 99% (الشريحة '100')**:
   - تبدأ شريحة '100' فعلياً عند وصول النسبة إلى **99%**.
   - يتم فحص راية `alerted_100` فقط.
   - **هام جداً**: في حال كان التنبيه `alerted_100` قد أُرسل مسبقاً (`true`)، **لا يتم التراجع** (Fallback) لفحص أو إطلاق التنبيهات للشريحتين الأدنى (95 أو 80) حتى وإن كانت راياتهما `false`.
5. **عزل الدورات (Cycle Isolation)**:
   - حالة التنبيهات خاصة بالثلاثية `(router_id, interface_name, cycle_start)`. أي حالة تنبيه لدورة سابقة أو لواجهة أخرى لا تؤثر إطلاقاً على تنبيهات الدورة الحالية.

---

## 5. قيود التصدير المحلي (Local-Export Limitations)

- المنطق مبني ومطابق لقواعد التصدير المحلي من `MikroTik - Quota Threshold Monitor.json / Check Quota Thresholds`.
- هذا تصدير محلي للاختبار والتقييم المعزول وليس تمثيلاً موثوقاً أو مباشراً للبيئة الإنتاجية الحية (local export, not live production state).
- الأداة تعمل دون أي اتصال بالشبكة أو قواعد البيانات الحية أو بيانات الاعتماد، ولا تُحدث أي تغيير على الأنظمة الإنتاجية.
