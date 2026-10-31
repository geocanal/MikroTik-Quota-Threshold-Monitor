# Data Flow Map

End-to-end data flows from source to consumer, with transformations and side effects.

## 1. WAN Usage Telemetry Flow

```
SOURCE: MikroTik Router
  ↓
  WAN interface counters (wan1_rx/tx, wan2_rx/tx bytes)
  
COLLECTION:
  ↓ (5m interval, via /tool fetch)
  
TRANSMISSION: HTTP POST to n8n webhook
  ↓
  URL: /webhook/mikrotik/wan-usage  (n8n path: mikrotik/wan-usage)
  Body: router_id, wan1_rx/tx, wan2_rx/tx, timestamp
  Workflow: MikroTik - Quota Threshold Monitor.json
  
INGESTION: n8n workflow
  ↓
  Normalize Telemetry1 → Get Previous Reading1 → Calculate WAN Delta
  (reboot/reset detection via comparison to previous reading)
  
STORAGE: PostgreSQL
  ↓
  INSERT INTO mikrotik_wan_readings (router_id, uptime, wan1_rx, wan1_tx, wan2_rx, wan2_tx, received_at)
  INSERT INTO mikrotik_wan_usage (reading_id, wan1_rx_bytes, ..., counter_reset, usage_at)
  
  SIDE BRANCHES (same workflow):
    - Check WAN Inactivity1 → Is Reboot/Reset? → Send Reboot Alert (Telegram)
    - Check Quota Thresholds → Update Quota State (quota_alert_state) → Send Quota Alert Telegram
    - Process WAN Alerts → Update Incident State (wan_incident_state) → Send WAN Alert Telegram
  
SIDE EFFECTS: Telegram alerts only. No router mutation in this workflow.

CONSUMER: 
  ↓
  Grafana dashboards (time series, daily rollups)
  Quota engine (burn rate calculation)
  Alert engine (usage threshold evaluation)
  
RETENTION:
  ↓
  Roll up daily via view_mikrotik_wan_daily_usage
  Purge telemetry older than 90 days (via purge_expired_mikrotik_telemetry)
```

**Classification**: READ_ONLY (collection) → EXTERNAL_WRITE (webhook) → DATABASE_WRITE (insert)

**Safety**: Counter reset detection prevents false burn rate spikes after router reboot.

---

## 2. WAN Quality Telemetry Flow

```
SOURCE: MikroTik Router
  ↓
  ICMP probes to 8.8.8.8 (3 packets each)
  Routes: via to_wan1, to_wan2 routing tables
  
COLLECTION:
  ↓ (1-5m interval, via /tool fetch)
  
TRANSMISSION: HTTP POST to n8n webhook
  ↓
  URL: https://n8n.example.com/webhook/mikrotik/wan-quality
  Body: router_id, interface_name, latency_ms, packet_loss%, jitter_ms, status
  
INGESTION: n8n WAN Quality Ingestion workflow
  ↓
  Parse JSON payload
  Classify status: HEALTHY | DEGRADED | DOWN
  
STORAGE: PostgreSQL
  ↓
  INSERT INTO mikrotik_wan_quality (router_id, interface_name, latency_ms, ...)
  
SIDE EFFECTS: 
  ↓
  IF quality returned to HEALTHY AND quota available AND currently ISOLATED
    THEN trigger RESTORE via state machine
  
CONSUMER:
  ↓
  Grafana dashboard (latest quality gauge)
  Automated recovery engine (isolation reversal)
  
RETENTION:
  ↓
  Latest per interface via view_mikrotik_wan_latest_quality
  Historical: 90 days
```

**Classification**: READ_ONLY (probes) → EXTERNAL_WRITE (webhook) → DATABASE_WRITE (insert)

**Safety**: Probes route via specific tables, do not affect client traffic.

---

## 3. Hotspot User Telemetry Flow

```
SOURCE: MikroTik Hotspot Database
  ↓
  Active users, sessions, byte counters, quota limits
  
COLLECTION:
  ↓ (5m interval via hotspot_telemetry.rsc)
  
FILTERING:
  ↓
  activeOnly mode: Only users with current sessions (90% payload reduction)
  
BATCHING:
  ↓
  30 users per HTTP request (prevents buffer overflow)
  
TRANSMISSION: HTTP POST (chunked batches) to n8n webhook
  ↓
  URL: http://192.168.88.10:5678/webhook/mikrotik/hotspot-telemetry
  Body: router_id, batch_num, total_batches, users[], sessions[]
  
INGESTION: n8n Hotspot Ingestion workflow
  ↓
  For each user:
    - Normalize bytes to MB/GB
    - Calculate used_percentage
    - Determine alert_tier: NORMAL | ALERT_80 | ALERT_100
  Batch insert
  
STORAGE: PostgreSQL
  ↓
  INSERT INTO hotspot_user_telemetry (router_id, user_name, bytes_in/out, limit_gb, used_percentage, alert_tier, recorded_at)
  
SIDE EFFECTS:
  ↓
  IF alert_tier >= 80% OR alert_tier >= 100%
    THEN send Telegram alert to admin (Arabic HTML)
  
CONSUMER:
  ↓
  Hotspot overview dashboard
  User quota tracking
  Alert engine
  
RETENTION:
  ↓
  Historical daily view: view_hotspot_daily_user_usage (LAG() for reboot resilience)
  Purge older than 90 days
```

**Classification**: READ_ONLY (collection) → EXTERNAL_WRITE (webhook) → DATABASE_WRITE (insert, batch)

**Safety**: Active-only filter, batching, character escaping prevent issues.

---

## 4. Quota Status & Alert Flow

```
SOURCE: PostgreSQL
  ↓
  mikrotik_wan_usage (WAN byte counters)
  mikrotik_wan_quotas (quota config)
  billing_cycles (cycle boundaries)
  quota_allocations (BASE + ADDON)
  
CALCULATION:
  ↓
  View: view_mikrotik_wan_quota_status
    - Deterministic cycle boundary (handles leap years)
    - Sum allocation: BASE + active ADDONs
    - Calculate usage within cycle
    - Compute burn rate (adaptive 7d WMA [60%] + cycle avg [40%])
    - Project exhaustion date
    - Fetch operational_state
  
DATA:
  ↓
  router_id, interface_name, provider_name
  cycle_start, renewal_date, days_left
  base_quota_gb, addon_quota_gb, total_quota_gb
  used_gb, remaining_gb, used_percentage
  daily_burn_rate_gb
  projected_exhaustion_date, days_until_exhaustion
  will_exhaust_before_renewal
  operational_state (NORMAL | ISOLATED | ISOLATED_FAILED | etc)
  
ALERT EVALUATION: n8n Quota Threshold Monitor workflow
  ↓
  IF used_percentage >= 80% AND NOT alerted_80 in current cycle
    THEN:
      - INSERT INTO quota_alert_state (alerted_80 = true)
      - Send Telegram alert (Arabic): "⚠️ 80% quota reached"
  
  IF used_percentage >= 95% AND NOT alerted_95
    THEN:
      - INSERT INTO quota_alert_state (alerted_95 = true)
      - Send Telegram alert (Arabic): "⚠️⚠️ 95% quota reached"
  
  IF used_percentage >= 100% AND NOT alerted_100
    THEN:
      - INSERT INTO quota_alert_state (alerted_100 = true)
      - Send Telegram alert (Arabic): "🚨 100% quota exhausted — isolation recommended"
      - (Optional) AUTO-TRIGGER ISOLATION via state machine
  
ISOLATION DECISION: (manual via Telegram button or automatic threshold)
  ↓ [See WAN Isolation Flow below]

CONSUMER:
  ↓
  Grafana quota gauge panel (live used_percentage)
  Grafana burn rate projection
  Admin Telegram notifications
  Automated isolation engine
  
RETENTION:
  ↓
  Alert state deduplicates per cycle (prevents spam)
  Historical: indefinite (quota_alert_state is lightweight)
```

**Classification**: READ_ONLY (calculation from views) → EXTERNAL_WRITE (Telegram) → DATABASE_WRITE (alert state)

**Side Effects**: May trigger WAN isolation if quota exhausted and auto-trigger enabled.

**Safety**: Idempotent per-cycle alert state prevents alert storms.

---

## 5. WAN Isolation Flow (Control Plane)

```
SOURCE: Trigger Event
  ↓
  Option A: Quota reaches 100% (automatic threshold)
  Option B: Admin clicks [ 🔴 عزل خط WE ] button in Telegram
  
INITIATION: n8n Quota Engine or Telegram Bot
  ↓
  Generate idempotency_key: "iso-wan2-cycle-YYYY-MM-DD-HHmm"
  
STATE MACHINE ENTRY: PostgreSQL transition_wan_state()
  ↓
  INPUT:
    - idempotency_key (prevents duplicate execution)
    - router_id, interface_name (wan1 or wan2)
    - action_type: ISOLATE
    - requested_by: system | n8n_quota_engine | telegram_admin
    - reason: "Quota 100% exhausted" | "Admin request"
  
  LOGIC:
    1. Check if idempotency_key already exists
       IF yes: Return existing action status, NO-OP
    2. Fetch current_state from wan_operational_state
       IF not found: Initialize as NORMAL
    3. Calculate desired_state = ISOLATED
    4. IF current_state == desired_state AND NOT forced: Return SKIPPED
    5. ELSE:
       - UPDATE wan_operational_state: NORMAL → ISOLATED
       - INSERT INTO wan_control_actions (status=EXECUTED, idempotency_key, ...)
       - RETURN success
  
  OUTPUT: JSON result with:
    - status: EXECUTED | SKIPPED | ALREADY_ISOLATED | FAILED
    - current_state, target_state
    - state_changed: true | false
  
ROUTER EXECUTION: n8n fetches result, triggers router script (via SSH or n8n RouterOS node)
  ↓
  Execute: /system script run isolate_wan2
  
  RouterOS Logic (wccp_control.rsc):
    1. INV-08 Ambiguity Check: Find exactly 1 rule with comment="WCCP-WAN2-ISOLATION-OVERRIDE"
    2. INV-05 Idempotency Check: IF rule already enabled (disabled=no) → return "ALREADY_ISOLATED"
    3. INV-09 Survivor Check: Ping 8.8.8.8 via to_wan1 routing table
       IF WAN1 unreachable: return error "ABORT_SURVIVOR_DOWN"
    4. Mutation: Set rule disabled=no
    5. INV-07 Post-Mutation Verification: Re-read rule, confirm disabled=no
    6. Return "ISOLATED_OK"
  
  SIDE EFFECT: WCCP-WAN2-ISOLATION-OVERRIDE rule enabled → new client traffic steers to WAN1 (100%)
  
CONFIRMATION: n8n receives router response
  ↓
  Call PostgreSQL confirm_router_execution(idempotency_key, "CONFIRMED", receipt)
  ↓
  IF "CONFIRMED":
    - UPDATE wan_control_actions: status=EXECUTED
    - UPDATE wan_operational_state: current_state=ISOLATED
  ELSE IF "FAILED":
    - UPDATE wan_control_actions: status=FAILED
    - UPDATE wan_operational_state: current_state=ISOLATION_FAILED
    - Send Telegram alert: "❌ Isolation failed: <error>"
  
NOTIFICATION: Telegram Alert
  ↓
  Send HTML message (Arabic):
    "🔴 خط WE معزول"
    "WAN2 isolated due to quota exhaustion"
    "New connections routed to WAN1"
    "Active connections will drain naturally"
  
CONSUMER:
  ↓
  Grafana dashboard: operational_state now shows ISOLATED
  Telegram status button updated
  Router firewall: PCC disabled for WAN2, new traffic → WAN1 only
  
METRICS:
  ↓
  wan_control_actions ledger: immutable audit trail
  wan_operational_state: current state
```

**Classification**: DATABASE_WRITE → ROUTER_WRITE → EXTERNAL_WRITE

**Operational Risk**: CRITICAL — modifies router firewall state.

**Safety Guarantees**:
- Idempotent per idempotency_key
- Survivor check prevents cutting all WAN
- No global connection flushes (drain naturally)
- Post-mutation verification
- Audit trail immutable
- Two-phase confirmation

---

## 6. WAN Restoration Flow (Control Plane)

```
SOURCE: Trigger Event
  ↓
  Option A: Admin clicks [ 🟢 استعادة خط WE ] button in Telegram
  Option B: Automatic recovery if quality returns to HEALTHY and quota renewed
  
INITIATION: Telegram Bot or n8n Recovery Engine
  ↓
  Generate idempotency_key: "restore-wan2-cycle-YYYY-MM-DD-HHmm"
  
STATE MACHINE ENTRY: PostgreSQL transition_wan_state()
  ↓
  INPUT:
    - action_type: RESTORE
    - router_id, interface_name: wan2
    - reason: "Quota cycle renewed" | "Admin request"
  
  LOGIC: [Similar to ISOLATE but opposite direction]
    - current_state: ISOLATED
    - desired_state: NORMAL
    - IF current_state == NORMAL: return SKIPPED
    - ELSE: UPDATE wan_operational_state to NORMAL
  
ROUTER EXECUTION: /system script run restore_wan2
  ↓
  RouterOS Logic (wccp_control.rsc):
    1. INV-08 Ambiguity Check: Find exactly 1 rule
    2. INV-06 Idempotency Check: IF rule already disabled → return "ALREADY_NORMAL"
    3. Mutation: Set rule disabled=yes
    4. INV-07 Post-Mutation Verification
    5. Return "RESTORED_OK"
  
  SIDE EFFECT: WCCP-WAN2-ISOLATION-OVERRIDE rule disabled → PCC 50/50 load balancing restored
  
CONFIRMATION: PostgreSQL confirm_router_execution()
  ↓
  UPDATE wan_operational_state: NORMAL
  
NOTIFICATION: Telegram Alert
  ↓
  "🟢 خط WE مستعاد"
  "WAN2 restored to active load balancing (50/50)"
  
CONSUMER:
  ↓
  Grafana: operational_state = NORMAL
  Router: New traffic splits 50/50 again
  Admin: Status button refreshes
```

**Classification**: DATABASE_WRITE → ROUTER_WRITE → EXTERNAL_WRITE

**Safety**: Symmetric with isolation, same safety guarantees.

---

## 7. Router Heartbeat & Outage Detection Flow

```
SOURCE: Telemetry Reception
  ↓
  Timestamp of last webhook reception in mikrotik_wan_readings
  
HEARTBEAT CHECK: n8n Router Offline Monitor (5m schedule)
  ↓
  SELECT MAX(received_at) FROM mikrotik_wan_readings WHERE router_id = 'home-router-01'
  Calculate: minutes_since_last_seen = NOW() - MAX(received_at)
  
DETECTION:
  ↓
  IF minutes_since_last_seen > 15 AND currently_marked_ONLINE
    THEN: state_change = true, new_state = OFFLINE
  
  IF minutes_since_last_seen <= 15 AND currently_marked_OFFLINE
    THEN: state_change = true, new_state = ONLINE
  
STATE TRANSITION: PostgreSQL router_heartbeat_state
  ↓
  UPDATE router_heartbeat_state:
    - is_offline: (new state)
    - last_seen_at: (timestamp of last reading)
    - last_alert_at: NOW() (if state changed)
    - updated_at: NOW()
  
NOTIFICATION (only on state change):
  ↓
  IF transitioning to OFFLINE:
    - Send Telegram alert (Arabic, HTML):
      "🔴 الراوتر غير متصل"
      "Router offline for X minutes"
      "Last telemetry received: YYYY-MM-DD HH:MM:SS"
      "Troubleshooting:"
      "  - Check power supply"
      "  - Check upstream ISP connection"
      "  - SSH to router and verify connectivity"
  
  IF transitioning to ONLINE:
    - Send Telegram recovery message:
      "🟢 الراوتر متصل"
      "Router came back online"
      "Uptime reset"
  
CONSUMER:
  ↓
  Grafana heartbeat widget
  Admin dashboard
  Escalation workflows (optional)
  
RETENTION:
  ↓
  One record per router (upsert)
  Minimal: just last seen + state
```

**Classification**: READ_ONLY (telemetry query) → DATABASE_WRITE (state) → EXTERNAL_WRITE (Telegram)

**Operational Risk**: Low — alerts only, no automatic remediation.

**Safety**: Prevents alert spam by only notifying on state transition.

---

## 8. Telegram Interactive Control Flow

```
SOURCE: Telegram User (Admin)
  ↓
  Clicks button in Telegram inline keyboard
  Examples:
    - [ 🔄 تحديث الحالة الآن ]
    - [ 🔴 عزل خط WE (WAN2) ]
    - [ 🟢 استعادة خط WE (WAN2) ]
  
AUTHENTICATION: n8n Telegram Bot webhook
  ↓
  Extract sender chat_id from Telegram callback
  IF chat_id != TELEGRAM_ADMIN_CHAT_ID (123456789)
    THEN: Send 403 denial message, abort
  
IDEMPOTENCY KEY GENERATION:
  ↓
  button_action = "isolate_wan2"
  minute_window = FLOOR(NOW() / 60 seconds)
  idempotency_key = "tg-" + button_action + "-" + minute_window
  
COMMAND ROUTING:
  ↓
  IF button == "status":
    → Query view_mikrotik_wan_quota_status
    → Format Arabic response
    → Send via Telegram editMessageText
  
  IF button == "isolate_wan2":
    → Call PostgreSQL transition_wan_state(..., "ISOLATE", ...)
    → [See WAN Isolation Flow]
    → Update Telegram button states
  
  IF button == "restore_wan2":
    → Call PostgreSQL transition_wan_state(..., "RESTORE", ...)
    → [See WAN Restoration Flow]
    → Update Telegram button states
  
RESPONSE FORMATTING: Arabic HTML
  ↓
  dir="rtl" styling
  Emoji status indicators
  Table: Quota, Used, Remaining, Burn Rate, Renewal
  Button states updated based on new operational_state
  
CONSUMER:
  ↓
  Admin Telegram chat
  State reflected in router config
  Grafana updated on next refresh
```

**Classification**: EXTERNAL_WRITE (Telegram) → DATABASE_WRITE (state transition) → ROUTER_WRITE (if isolate/restore)

**Safety**: Strict admin verification, automatic idempotency key prevents duplicate execution.

---

## 9. Grafana Dashboard Refresh Flow

```
SOURCE: Browser Refresh / Time-based Auto-Refresh
  ↓
  Panel queries execute
  
QUERIES:
  ↓
  Panel 1 (Quota Gauge):
    SELECT used_percentage, quota_gb, used_gb FROM view_mikrotik_wan_quota_status
  
  Panel 2 (Traffic Distribution):
    SELECT (wan1_total_gb) / (wan1_total_gb + wan2_total_gb) FROM view_mikrotik_wan_daily_usage
  
  Panel 3 (Time Series):
    SELECT (usage_at AT TIME ZONE 'Africa/Cairo'), (wan1_rx_bytes + wan1_tx_bytes) FROM mikrotik_wan_usage
  
  Panel 4 (Daily Rollup):
    SELECT usage_date, wan1_total_gb, wan2_total_gb FROM view_mikrotik_wan_daily_usage ORDER BY usage_date DESC LIMIT 30
  
  Panel 5 (ISP Summary Table):
    SELECT provider_name, total_quota_gb, used_gb, remaining_gb, daily_burn_rate_gb, renewal_date FROM view_mikrotik_wan_quota_status
  
RENDERING:
  ↓
  Grafana renders on browser
  Color thresholds applied:
    - <80% green
    - 80-95% amber
    - >95% red
  
  Tooltips show full precision
  Links to drill-down (if configured)
```

**Classification**: READ_ONLY (query views, no mutations)

**Safety**: Zero side effects, pure visualization.

---

## Control Path Trace — Verified Against Deployed n8n (2026-10-02)

Inspected object: `workflow_entity`, `webhook_entity`, `execution_entity`, `execution_data`
on container `n8n-postgres`. Observed 2026-10-02 ~05:55 UTC. Read-only.

| Step | Expected node | Deployed state | Evidence | Status |
|------|---------------|-----------------|----------|--------|
| 1. Telegram callback arrives | `Webhook` (`mikrotik-telegram-bot-trigger/webhook`) | Registered, but **workflow inactive** | `webhook_entity` row present; `workflow_entity.active = f` | **BROKEN HERE** |
| 2. Authorization | `Auth & Dispatcher` → `Is Authorized Admin?` | Never executes (workflow inactive) | 0 executions for `mikrotik-interactive-telegram-bot` | **NOT REACHED** |
| 3. Input validation | `Is Control Command?` → `Prepare Control Action` | Present in graph; validates `cmd_isolate_wan1/2`, `cmd_restore_wan1/2`; builds `tg-<action>-<iface>-<60s window>` idempotency key | Local export inspection | **CONFIGURED, NOT EXERCISED** |
| 4. State transition | `Execute State Transition` → `SELECT transition_wan_state($1..$6)` | Present in graph | Local export inspection | **CONFIGURED, NOT EXERCISED** |
| 5. Router execution request | *(no node)* | **MISSING** | 0 occurrences of `ssh` / RouterOS / API nodes | **MISSING LINK** |
| 6. Router action | *(external)* | **UNREACHABLE from deploy-server** | TCP 8728/22 to `192.168.88.1` time out | **BLOCKED** |
| 7. Confirmation | *(no node)* | **MISSING** — `confirm_router_execution()` has no caller in any workflow | Keyword scan ×0 | **MISSING LINK** |
| 8. Final state | `Notify Action Result` | Present, but only reports the SQL return value | Local export inspection | **COSMETIC ONLY** |

**Consequence:** even if the Telegram workflow were activated today, step 4 would write
*desired* state to `wan_operational_state` and step 8 would report success, while the
router was never touched. Activation alone does **not** restore manual control.

### Authorization / abuse handling (from configured graph, unexercised)
- Admin check exists: `Is Authorized Admin?` with a `TELEGRAM_ADMIN_CHAT_ID` env reference.
- Unauthorized branch routes to `Unauthorized Reply`. No HTTP 403 semantics — it replies in-chat.
- Duplicate suppression: deterministic 60-second idempotency window. Consequence: a
  legitimate retry inside the same minute is silently absorbed as a duplicate.
- No bounded retry, no timeout policy, and no concurrency guard beyond the SQL unique key.

### Quota path (exercised)
| Step | Node | State |
|------|------|-------|
| Receive | `Webhook1` (`mikrotik/wan-usage`) | **Receiving traffic** as of 2026-10-02 05:55 UTC |
| Normalize | `Normalize Telemetry1` | Failing run |
| Previous reading | `Get Previous Reading1` | **Failing node** (`app-postgres-1` named in error) |
| Store | `Store Raw Reading`, `Store Usage Delta` | Not reached — no rows since 2026-09-30 17:35 UTC |

**Staleness is not the root cause:** the router keeps POSTing; the pipeline breaks at the DB read.

## Flow Summary Table

| Flow | Source → Consumer | Classification | Risk | Frequency |
|------|-------------------|-----------------|------|-----------|
| WAN Usage | Router → n8n → DB → Grafana | READ_ONLY → EXT_WRITE → DB_WRITE | Low | 5m |
| WAN Quality | Router → n8n → DB → Auto-Recovery | READ_ONLY → EXT_WRITE → DB_WRITE | Low | 2m |
| Hotspot Telemetry | Router → n8n → DB | READ_ONLY → EXT_WRITE → DB_WRITE | Low | 5m |
| Quota Alerts | DB → n8n → Telegram | DB_READ → EXT_WRITE | Medium | On threshold |
| WAN Isolation | n8n → DB → Router → Telegram | DB_WRITE → ROUTER_WRITE → EXT_WRITE | **Critical** | On-demand |
| WAN Restoration | n8n → DB → Router → Telegram | DB_WRITE → ROUTER_WRITE → EXT_WRITE | **Critical** | On-demand |
| Heartbeat | DB → n8n → Telegram | DB_READ → DB_WRITE → EXT_WRITE | Low | 5m |
| Telegram Control | Telegram → n8n → DB / Router | EXT_WRITE → DB_WRITE / ROUTER_WRITE | Medium-High | On-demand |
| Dashboard Refresh | DB → Grafana → Browser | DB_READ | Low | Auto |