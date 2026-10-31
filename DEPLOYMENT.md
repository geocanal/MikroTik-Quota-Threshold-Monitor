# 🚀 MikroTik Quota Threshold Monitor - Deployment & Operations Guide

This guide covers deployment instructions for the 3 production enhancements:
1. **PostgreSQL DDL & Disaster Recovery (`schema.sql`)**
2. **Zero-Touch Grafana Provisioning Stack (`docker-compose.monitoring.yml`)**
3. **Router Heartbeat & Dead Man's Switch Workflow (`MikroTik - Router Offline Monitor.json`)**

---

## 📋 Phase 1: Database Migration & DDL

Apply the schema to your PostgreSQL database (`campaign_db`):

```bash
# Direct psql execution
psql -h campaign-postgres -U postgres -d campaign_db -f database/schema.sql

# Or if running PostgreSQL in Docker:
docker exec -i campaign-postgres psql -U postgres -d campaign_db < database/schema.sql
```

### Key Components Provisioned:
- **`mikrotik_wan_readings`**: Raw counters ingested from MikroTik webhook.
- **`mikrotik_wan_usage`**: Byte deltas calculated per reading interval with reboot/reset safeguards.
- **`mikrotik_wan_quotas`**: Billing cycles and quota capacities (Seed: WE Egypt 150 GB, Vodafone 150 GB, Renewal Day: 1).
- **`wan_incident_state`**: Per-interface outage tracking.
- **`quota_alert_state`**: Billing cycle deduplication for 80% and 95% alerts.
- **`router_heartbeat_state`**: Router dead man's switch state tracking.
- **Views**:
  - `view_mikrotik_wan_quota_status`: Dynamic cycle boundary calculation using `Africa/Cairo` timezone.
  - `view_mikrotik_wan_daily_usage`: Aggregated daily rollups per interface and grand total.

---

## 📊 Phase 2: Zero-Touch Grafana Provisioning Stack

The Grafana stack is configured for zero-touch provisioning. It automatically connects to the PostgreSQL database and loads the dashboards upon startup.

### 1. Verification of Files:
- `docker-compose.monitoring.yml`: Grafana service definition on `campaign-network`.
- `provisioning/datasources/datasource.yml`: Automated PostgreSQL datasource configuration.
- `provisioning/dashboards/dashboards.yml`: Automated dashboard provider pointing to `/var/lib/grafana/dashboards`.
- `provisioning/dashboards/mikrotik-overview.json`: Complete dashboard with 5 production panels:
  1. **Gauge**: WAN1 & WAN2 Quota Usage (%) with thresholds (<80% green, 80% amber, 95% red).
  2. **Pie Chart**: Traffic distribution and load balancing ratio (WAN1 vs WAN2).
  3. **Time Series**: Throughput and bandwidth consumption (MB per 5-min sample).
  4. **Stacked Bar Chart**: Daily consumption (GB) over the last 30 days.
  5. **Table**: ISP Quota cycle summary (Quota, Used, Remaining, Burn Rate, Renewal Date).

### 2. Spin Up Grafana:
```bash
docker compose -f docker-compose.monitoring.yml up -d
```

### 3. Access Grafana:
- **URL**: `http://<HOST_IP>:3000`
- **Default Credentials**: `admin` / `admin`
- The dashboard **"MikroTik WAN Quota & Traffic Overview"** will be immediately available in the **MikroTik Network** folder.

---

## 🛡️ Phase 3: Router Heartbeat & Dead Man's Switch Workflow

The file `MikroTik - Router Offline Monitor.json` contains a dedicated n8n workflow designed to catch complete router power loss or upstream blackouts where webhooks stop arriving.

### Workflow Pipeline:
1. **Schedule Trigger**: Executes every 5 minutes.
2. **PostgreSQL Check (`Check Router Heartbeat`)**:
   - Calculates silence duration (`minutes_since_last_seen = NOW() - MAX(received_at)`).
   - If silence exceeds 15 minutes and the router was previously marked `ONLINE`, it flags an `OFFLINE` event.
   - If readings resume after an outage, it flags an `ONLINE` event.
   - State transition condition prevents alert spam.
3. **Telegram HTML Alerts**:
   - Formatted in Arabic with status details, last seen timestamp, and remediation tips sent to Chat ID `123456789`.
4. **State Storage (`router_heartbeat_state`)**: Updates the current state and alert timestamps idempotently.

### How to Import into n8n:
1. Open your n8n web interface.
2. Go to **Workflows** -> click **Add Workflow** (or the `...` menu on top right) -> **Import from File**.
3. Select `MikroTik - Router Offline Monitor.json`.
4. Verify the Postgres credential (`Postgres account`) and Telegram credential (`Telegram account`).
5. Toggle the workflow to **Active**.

---

## 📶 Phase 4: MikroTik Hotspot Telemetry & Ingestion Pipeline

This component streams Hotspot user accounting, active sessions, and remaining quota metrics every 5 minutes from RouterOS to n8n.

### 1. MikroTik RouterOS Setup:
- Upload or copy [routeros/hotspot_telemetry.rsc](file:///D:/Work/MikroTik%20-%20Quota%20Threshold%20Monitor/routeros/hotspot_telemetry.rsc) to your MikroTik router.
- Verify the `:local webhookUrl` matches your n8n instance IP (e.g. `http://192.168.88.10:5678/webhook/mikrotik/hotspot-telemetry`).
- Install script and scheduler:
  ```routeros
  /system script add name="push_hotspot_telemetry" source=[/file get hotspot_telemetry.rsc contents] policy=read,write,test
  /system scheduler add name="sched_hotspot_telemetry" interval=5m on-event="push_hotspot_telemetry" start-time=startup
  ```

### 2. n8n Hotspot Workflow Import:
- In n8n, import [MikroTik - Hotspot Ingestion.json](file:///D:/Work/MikroTik%20-%20Quota%20Threshold%20Monitor/MikroTik%20-%20Hotspot%20Ingestion.json).
- The workflow includes:
  1. **Hotspot Webhook**: Listens on `/webhook/mikrotik/hotspot-telemetry`.
  2. **Normalize & Calculate Quota**: Normalizes byte counts to MB/GB, matches active sessions, and flags 80%/100% quota tiers.
  3. **Store Hotspot Snapshots**: Batch inserts into `hotspot_user_telemetry` in PostgreSQL.
  4. **Exceeded 80% or 100%?**: Filter gate to notify admins via Telegram if user quota is near or fully exhausted.
  5. **Send Hotspot Alert Telegram**: HTML-formatted notification sent to Chat ID `123456789`.

---

## 🔒 Security & Environment Variables

The project uses `.env` to store secrets and network configuration.
```bash
# Create local .env from template
cp .env.example .env
```

Key Variables:
- `TELEGRAM_ADMIN_CHAT_ID`: Target Telegram ID for outage and quota alerts.
- `GRAFANA_ADMIN_USER` / `GRAFANA_ADMIN_PASSWORD`: Credentials for Grafana UI.
- `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`: PostgreSQL database credentials.

---

## 🧹 Phase 5: Automated Data Retention & Housekeeping

To prevent database disk bloat from 5-minute telemetry intervals, run the built-in PostgreSQL stored procedure:

```sql
-- Purge telemetry older than 90 days (default)
CALL purge_expired_mikrotik_telemetry(90);

-- Or purge telemetry older than 30 days
CALL purge_expired_mikrotik_telemetry(30);
```

### Optional: Automate with pg_cron or Linux Cron
```bash
# Run weekly on Sunday at 02:00 AM via crontab
0 2 * * 0 docker exec -i campaign-postgres psql -U postgres -d campaign_db -c "CALL purge_expired_mikrotik_telemetry(90);"
```

---

## ⏪ Phase 1 Exact Rollback Procedure

If you ever need to rollback the Phase 1 schema changes without touching any historical usage data in `mikrotik_wan_usage`, execute the following exact SQL:

```sql
-- 1. Restore Legacy view definition
CREATE OR REPLACE VIEW view_mikrotik_wan_quota_status AS
WITH current_cairo_time AS (
    SELECT 
        (CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Cairo')::timestamp AS cairo_now,
        (CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Cairo')::date AS today_date,
        EXTRACT(DAY FROM (CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Cairo'))::int AS current_day
),
quota_cycles AS (
    SELECT 
        q.router_id,
        q.interface_name,
        q.provider_name,
        q.quota_gb,
        q.renewal_day,
        q.alert_threshold_percent,
        t.today_date,
        CASE 
            WHEN t.current_day >= q.renewal_day THEN 
                make_date(EXTRACT(YEAR FROM t.today_date)::int, EXTRACT(MONTH FROM t.today_date)::int, q.renewal_day)
            ELSE 
                (make_date(EXTRACT(YEAR FROM t.today_date)::int, EXTRACT(MONTH FROM t.today_date)::int, 1) - INTERVAL '1 month')::date 
                + (q.renewal_day - 1) * INTERVAL '1 day'
        END::date AS cycle_start,
        CASE 
            WHEN t.current_day >= q.renewal_day THEN 
                (make_date(EXTRACT(YEAR FROM t.today_date)::int, EXTRACT(MONTH FROM t.today_date)::int, 1) + INTERVAL '1 month')::date 
                + (q.renewal_day - 1) * INTERVAL '1 day'
            ELSE 
                make_date(EXTRACT(YEAR FROM t.today_date)::int, EXTRACT(MONTH FROM t.today_date)::int, q.renewal_day)
        END::date AS renewal_date
    FROM mikrotik_wan_quotas q
    CROSS JOIN current_cairo_time t
    WHERE q.is_active = TRUE
),
usage_per_cycle AS (
    SELECT 
        qc.router_id,
        qc.interface_name,
        qc.provider_name,
        qc.quota_gb,
        qc.renewal_day,
        qc.alert_threshold_percent,
        qc.cycle_start,
        qc.renewal_date,
        (qc.renewal_date - qc.today_date)::int AS days_left,
        COALESCE(
            SUM(
                CASE 
                    WHEN LOWER(qc.interface_name) = 'wan1' THEN (u.wan1_rx_bytes + u.wan1_tx_bytes)
                    WHEN LOWER(qc.interface_name) = 'wan2' THEN (u.wan2_rx_bytes + u.wan2_tx_bytes)
                    ELSE 0
                END
            ), 0
        ) AS total_used_bytes
    FROM quota_cycles qc
    LEFT JOIN mikrotik_wan_usage u 
        ON u.router_id = qc.router_id 
       AND (u.usage_at AT TIME ZONE 'Africa/Cairo') >= qc.cycle_start::timestamp
       AND (u.usage_at AT TIME ZONE 'Africa/Cairo') < (qc.renewal_date::timestamp)
       AND u.counter_reset = FALSE
    GROUP BY 
        qc.router_id, qc.interface_name, qc.provider_name, qc.quota_gb, 
        qc.renewal_day, qc.alert_threshold_percent, qc.cycle_start, qc.renewal_date, qc.today_date
)
SELECT 
    router_id,
    interface_name,
    provider_name,
    quota_gb,
    renewal_day,
    cycle_start,
    renewal_date,
    days_left,
    ROUND((total_used_bytes / (1024.0 * 1024.0 * 1024.0))::numeric, 2) AS used_gb,
    ROUND(GREATEST(0, quota_gb - (total_used_bytes / (1024.0 * 1024.0 * 1024.0)))::numeric, 2) AS remaining_gb,
    ROUND(
        LEAST(100.0, ((total_used_bytes / (1024.0 * 1024.0 * 1024.0)) / NULLIF(quota_gb, 0)) * 100.0)::numeric, 
        1
    ) AS used_percentage,
    alert_threshold_percent
FROM usage_per_cycle;

-- 2. Drop additive Phase 1 structures
DROP TABLE IF EXISTS quota_allocations CASCADE;
DROP TABLE IF EXISTS billing_cycles CASCADE;
DROP FUNCTION IF EXISTS calculate_cycle_boundary_date CASCADE;
```
*(All historical usage in `mikrotik_wan_usage` and readings in `mikrotik_wan_readings` remain untouched).*

---

## 🌐 Phase 3: RouterOS 7.x Safe Policy-Based Routing (PBR) & Isolation

The file [`routeros/wan_control_pbr.rsc`](file:///d:/Work/MikroTik%20-%20Quota%20Threshold%20Monitor/routeros/wan_control_pbr.rsc) implements production-hardened policy-based routing (PBR) and automated quota isolation for MikroTik RouterOS v7.

### 🛡️ Safety & Architecture Guarantees
1. **RouterOS v7 Native FIB Tables**: Replaces deprecated v6 routing marks with explicit `/routing table add name=to_wan1 fib` and `/routing table add name=to_wan2 fib`.
2. **Zero Router Severance**: Router-local traffic (`chain=output` / `dst-address-type=local`: DNS, NTP, Webhooks to n8n, Netwatch probes, remote SSH/Winbox) uses the main table with check-gateway failover and is **never** isolated or dropped.
3. **Client-Forwarded Isolation Only**: Only LAN client forwarded traffic (`chain=prerouting in-interface-list=LAN`) is steered away from depleted WANs.
4. **Scoped Connection Flushing**: Never executes `/ip firewall connection remove [find]`. Isolating scripts target strictly `connection-mark="cm_wan2"` (or `cm_wan1`), preventing interruptions to existing healthy connections and router telemetry.

### 🚀 Deployment Instructions:
1. **Always enable Safe Mode** before applying routing changes in Winbox / CLI (`[Ctrl] + [X]`).
2. Verify interface names match your router (`wan1`, `wan2`, and interface list `LAN`).
3. Import the configuration script:
   ```routeros
   /import file-name=wan_control_pbr.rsc
   ```
4. Test isolation & recovery on demand:
   ```routeros
   # Isolate WAN2 (e.g. When WE quota is exhausted)
   /system script run isolate_wan2

   # Restore WAN2 (e.g. When WE quota is renewed or add-on is purchased)
   /system script run restore_wan2
   ```
---

## 🔀 Phase 4: State Machine & Idempotent Control Plane

Phase 4 introduces formal state management (`wan_operational_state`) and an append-only control action ledger (`wan_control_actions`) with strict idempotency keys.

### 🛡️ Core Guarantees:
1. **Deterministic State Transitions**: State transitions (`NORMAL` -> `ISOLATED` -> `RECOVERED` / `NORMAL`) are executed via PostgreSQL function `transition_wan_state(...)`.
2. **Duplicate Action Rejection**: Repeating an action with the same `idempotency_key` returns the existing execution receipt with `"state_changed": false` and prevents duplicate router executions.
3. **No-Op Protection**: Attempting to isolate an interface that is already `ISOLATED` marks the action as `SKIPPED` without issuing redundant commands.
4. **Audit Trail**: Every automated or manual intervention (from n8n or Telegram) is immutably logged with `requested_by`, `reason`, and `executed_at`.

### 🧪 Executing a Safe Transition via SQL:
```sql
-- Safely request WAN2 isolation with idempotency key
SELECT transition_wan_state(
    'iso-wan2-cycle-2026-10-07', -- Unique idempotency key
    'home-router-01',           -- Router ID
    'wan2',                     -- Interface Name
    'ISOLATE',                  -- Action: ISOLATE | RESTORE | THROTTLE | UNTHROTTLE
    'n8n_quota_engine',         -- Caller identity
    'Quota reached 100% exhaustion before renewal'
);
```
---

## 🤖 Phase 5: Secure Interactive Telegram Control Bot

The file [`MikroTik - Telegram Interactive Bot.json`](file:///d:/Work/MikroTik%20-%20Quota%20Threshold%20Monitor/MikroTik%20-%20Telegram%20Interactive%20Bot.json) provides a dedicated n8n workflow turning Telegram into an interactive command center.

### 🛡️ Security & Idempotency Features:
1. **Strict Admin Verification**: Only requests originating from `TELEGRAM_ADMIN_CHAT_ID` (`123456789`) are processed; unauthorized attempts receive an explicit 403-style denial and are rejected immediately.
2. **Interactive Inline Keyboard**: Real-time buttons for instant status query, isolating a depleted WAN, or restoring it after renewal:
   - `[ 🔄 تحديث الحالة الآن ]` `[ 📊 ملخص اليوم ]`
   - `[ 🔴 عزل خط WE (WAN2) ]` `[ 🟢 استعادة خط WE (WAN2) ]`
   - `[ 🔴 عزل فودافون (WAN1) ]` `[ 🟢 استعادة فودافون (WAN1) ]`
3. **Automatic Idempotency Key Injection**: Every button click automatically calculates an idempotency key (e.g. `tg-isolate-wan2-<minute_window>`), preventing accidental double-clicks or bot callback storms.

### 🚀 Import & Activation:
1. Open n8n -> Workflows -> Import from File.
2. Select [`MikroTik - Telegram Interactive Bot.json`](file:///d:/Work/MikroTik%20-%20Quota%20Threshold%20Monitor/MikroTik%20-%20Telegram%20Interactive%20Bot.json).
3. Verify the **Telegram account** and **Postgres account** credentials.
4. Toggle workflow to **Active**.
5. Test by sending `/status` or `/start` to your Telegram Bot.
---

## 📈 Phase 6: Automated Recovery & Quality Monitoring (WAN Latency & Packet Loss)

Phase 6 provisions real-time health checks, RTT latency, and packet loss telemetry per WAN interface without generating intrusive network overhead.

### 🛡️ Features:
1. **Low Overhead Probes**: Script [`routeros/wan_quality.rsc`](file:///d:/Work/MikroTik%20-%20Quota%20Threshold%20Monitor/routeros/wan_quality.rsc) sends only 3 ICMP ping packets per interface every 1 to 5 minutes using RouterOS v7 routing tables (`to_wan1`, `to_wan2`).
2. **Quality Analytics Table**: Telemetry is persisted in PostgreSQL table `mikrotik_wan_quality` and aggregated in `view_mikrotik_wan_latest_quality`.
3. **Automated Recovery**: When an isolated or degraded interface returns to `HEALTHY` (loss < 10% and RTT < 100ms) and billing cycle is renewed or has available quota, the state machine automatically triggers `RESTORE`.

### 🚀 RouterOS Deployment:
1. Upload [`routeros/wan_quality.rsc`](file:///d:/Work/MikroTik%20-%20Quota%20Threshold%20Monitor/routeros/wan_quality.rsc) to MikroTik.
2. Install script and periodic scheduler:
   ```routeros
   /system script add name="probe_wan_quality" source=[/file get wan_quality.rsc contents] policy=read,write,test
   /system scheduler add name="sched_wan_quality" interval=2m on-event="probe_wan_quality" start-time=startup
   ```
---

## 🔒 WCCP v1.1 Validated Production Control Path (`routeros/wccp_control.rsc`)

Based on physical conntrack verification and empirical testing with Hotspot client `192.168.88.49`:
- **Root Cause Resolution**: Authenticated Hotspot clients previously bypassed PCC marks because `hotspot=from-client action=accept` was positioned ahead of PCC. Placing WCCP rules before the Hotspot bypass ensures all client Internet traffic is properly classified.
- **Dedicated Override Control**: Isolation does **not** mutate legacy `RULE-10` / `RULE-12`. Instead, it toggles the dedicated upstream rule:
  `WCCP-WAN2-ISOLATION-OVERRIDE` (positioned immediately before PCC rules).
- **Graceful Connection Drainage**: Existing TCP connections are not forcibly terminated. New connections steer 100% to WAN1 (`cm_wan1`), while active sessions close naturally.
- **Router Management Sanctity**: Router-originated traffic on WAN2 (`192.168.2.2`) continues functioning unimpeded.

### Production Scripts:
1. Upload and install [`routeros/wccp_control.rsc`](file:///d:/Work/MikroTik%20-%20Quota%20Threshold%20Monitor/routeros/wccp_control.rsc) on MikroTik.
2. Execute transitions safely:
   ```routeros
   # Transition to ISOLATED (Enables override with survivor check & idempotency guard)
   /system script run ISOLATE_WAN2

   # Transition to NORMAL (Disables override restoring PCC 50/50)
   /system script run RESTORE_WAN2
   ```
3. Verification Command:
   ```routeros
   /ip firewall mangle print detail where comment="WCCP-WAN2-ISOLATION-OVERRIDE"
   # ISOLATED: disabled=no
   # NORMAL:   disabled=yes
   ```
