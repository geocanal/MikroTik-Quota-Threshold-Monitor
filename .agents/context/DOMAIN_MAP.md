# Domain Map

Functional domains and their responsibilities, data stores, and risk classification.

## 1. WAN Telemetry Collection

**Responsibility**: Gather raw WAN interface byte counters from the router every 5 minutes.

| Property | Value |
|----------|-------|
| **Primary Files** | `hotspot_telemetry.rsc` (part of scheduled collection) |
| **Data Store** | `mikrotik_wan_readings`, `mikrotik_wan_usage` |
| **Upstream Input** | RouterOS WAN interface counters (via `/tool fetch`) |
| **Downstream Consumer** | PostgreSQL views, Grafana dashboards, quota engine |
| **Classification** | READ_ONLY (collection), DATABASE_WRITE (insertion) |
| **Operational Risk** | Low — read-only on router, append-only to DB |
| **Scheduling** | Router scheduler, 5m interval |

**Data Flow**: RouterOS → n8n webhook → PostgreSQL insert

**Safety Notes**: 
- Router script has no-op: returns early if no users
- Batching prevents buffer overflow
- Counter reset detection guards against router reboots

---

## 2. WAN Quality Monitoring

**Responsibility**: Probe each WAN interface for latency, packet loss, jitter every 1-5 minutes.

| Property | Value |
|----------|-------|
| **Primary Files** | `wan_quality.rsc` |
| **Data Store** | `mikrotik_wan_quality`, `view_mikrotik_wan_latest_quality` |
| **Upstream Input** | ICMP probes to 8.8.8.8 via specific routing tables |
| **Downstream Consumer** | n8n recovery workflows, Grafana dashboards |
| **Classification** | READ_ONLY (probes), DATABASE_WRITE (insertion) |
| **Operational Risk** | Low — ICMP probes only, no state changes |
| **Scheduling** | Router scheduler, 2m recommended interval |

**Data Flow**: RouterOS → n8n webhook → PostgreSQL insert → automated recovery trigger

**Safety Notes**:
- Low overhead: 3 packets per interface only
- Routed via `to_wan1`, `to_wan2` routing tables (does not affect client traffic)
- Fallback reasonable defaults if parse fails

---

## 3. Hotspot Telemetry & User Accounting

**Responsibility**: Collect active Hotspot user sessions, quotas, bytes consumed every 5 minutes.

| Property | Value |
|----------|-------|
| **Primary Files** | `hotspot_telemetry.rsc`, `MikroTik - Hotspot Ingestion.json` |
| **Data Store** | `hotspot_user_telemetry`, `view_hotspot_daily_user_usage` |
| **Upstream Input** | RouterOS Hotspot active users + user database |
| **Downstream Consumer** | Alert engine, Grafana dashboards, user quota tracking |
| **Classification** | READ_ONLY (collection), DATABASE_WRITE (insertion) |
| **Operational Risk** | Low — read-only on router |
| **Scheduling** | Router scheduler, 5m interval |

**Data Flow**: RouterOS → n8n webhook → PostgreSQL batch insert → alert evaluation

**Safety Notes**:
- Active-only filter mode (90% payload reduction)
- Chunked batching (30 users per request, prevents overflow)
- Special character escaping prevents SQL injection
- View includes reboot/reset resilience via LAG()

---

## 4. Quota Management & Billing Cycles

**Responsibility**: Calculate current quota status, burn rate, projected exhaustion, handle add-ons.

| Property | Value |
|----------|-------|
| **Primary Files** | `schema.sql` (functions + views), n8n quota engine |
| **Data Store** | `mikrotik_wan_quotas`, `billing_cycles`, `quota_allocations`, `quota_day_weights`, `view_mikrotik_wan_quota_status` |
| **Upstream Input** | WAN usage data, manual quota configuration |
| **Downstream Consumer** | Alert engine, Grafana quota gauges, state machine |
| **Classification** | DATABASE_WRITE (configuration), READ_ONLY (calculation) |
| **Operational Risk** | Medium — quota threshold triggers WAN isolation |
| **Functions** | `calculate_cycle_boundary_date()`, `calculate_adaptive_burn_rate()` |

**Data Model**:
- **Base Quota**: 150 GB (Vodafone), 140 GB (WE Egypt), renewal day 19/7
- **Billing Cycles**: Immutable `cycle_start` to `cycle_end` (renewal date)
- **Allocations**: BASE + ADDON quotas (append-only ledger)
- **Day Weights**: Egyptian weekend pattern (Fri/Sat 1.30x, weekdays 0.88x)
- **Burn Rate**: Adaptive 7-day WMA [60%] + cycle average [40%]

**Safety Notes**:
- Deterministic cycle boundary function handles 28/29/30/31-day months
- Cold-start guard (< 3 days elapsed) uses conservative baseline
- Projected exhaustion calculation prevents over-consumption

---

## 5. WAN Isolation & Restoration (Control Plane)

**Responsibility**: Isolate depleted WAN from client traffic, restore when quota renewed or add-on purchased.

| Property | Value |
|----------|-------|
| **Primary Files** | `wan_control_pbr.rsc` (v1.0), `wccp_control.rsc` (v1.1) |
| **Data Store** | `wan_operational_state`, `wan_control_actions` |
| **Upstream Input** | n8n quota engine, Telegram bot commands |
| **Downstream Consumer** | Router firewall mangle rules, Telegram status alerts |
| **Classification** | **ROUTER_WRITE** |
| **Operational Risk** | **Critical** — modifies firewall, can sever WAN connectivity |
| **Scheduling** | On-demand (quota threshold or admin command) |

**Installed design conflict (VERIFIED from `router_config_clean.rsc`, 2026-10-02)**

| Script | Lines | Mechanism |
|---|---|---|
| `isolate_wan2` | 528-546 | Disables `RULE-10` + `RULE-12`, flushes `cm_wan2` connections |
| `restore_wan2` | 547-559 | **Disables** `WCCP-WAN2-ISOLATION-OVERRIDE` |
| `ISOLATE_WAN2` | 582+ | **Enables** `WCCP-WAN2-ISOLATION-OVERRIDE` |
| `RESTORE_WAN2` | 560-581 | Disables `WCCP-WAN2-ISOLATION-OVERRIDE` |

`restore_wan2` and `RESTORE_WAN2` are near-duplicates, while `isolate_wan2` and
`ISOLATE_WAN2` implement **different mechanisms for the same intent**. The override rule
exists and is enabled (`router_config_clean.rsc:174-177`), so the v1.1 design
(`ISOLATE_WAN2`) is the one whose prerequisite is satisfied. Choosing between them
requires live router confirmation — see ARCHITECTURE.md gap #6.

**State Machine**:
```
NORMAL → ISOLATION_REQUESTED → ISOLATED → (renewal) → RESTORATION_REQUESTED → NORMAL
        (or direct via WAN quality recovery)
```

**Data Flow**: n8n workflow → PostgreSQL `transition_wan_state()` → Router script → `confirm_router_execution()`

**Safety Guarantees** (WCCP v1.1, from `wccp_control.rsc`):
- INV-01: No isolation disables monitoring
- INV-02: Router-originated traffic never isolated
- INV-03: Only new LAN client traffic steered
- INV-04: Existing TCP connections drain naturally (not forcibly flushed)
- INV-05/06: ISOLATE/RESTORE are strictly idempotent
- INV-07: Post-mutation state verification before confirming
- INV-08: Rule ambiguity check (must find exactly 1 rule)
- INV-09: Survivor WAN health check before isolation
- INV-10: Legacy rules (RULE-10/12) untouched

**Critical Operations**:
- `isolate_wan2`: Enables `WCCP-WAN2-ISOLATION-OVERRIDE` → steers new traffic to WAN1
- `restore_wan2`: Disables override → restores PCC 50/50 load balancing
- Similar for WAN1 with survivor check on WAN2

---

## 6. Router Heartbeat & Outage Detection

**Responsibility**: Detect complete router power loss or upstream blackout (silence > 15 min).

| Property | Value |
|----------|-------|
| **Primary Files** | `MikroTik - Router Offline Monitor.json` (n8n workflow) |
| **Data Store** | `router_heartbeat_state` |
| **Upstream Input** | Telemetry webhook reception (last_seen timestamp) |
| **Downstream Consumer** | Telegram alerts, manual intervention triggers |
| **Classification** | DATABASE_WRITE, EXTERNAL_WRITE |
| **Operational Risk** | Medium — alerts only, no automatic remediation |
| **Scheduling** | 5m n8n schedule |

**Data Flow**: 
1. n8n checks `MAX(received_at)` from `mikrotik_wan_readings`
2. If `NOW() - MAX(received_at) > 15 min` and previously ONLINE → mark OFFLINE
3. Send Telegram alert with remediation tips

**State Transitions**:
- ONLINE → OFFLINE (silence > 15 min)
- OFFLINE → ONLINE (readings resume)
- Transition only on state change (prevent alert spam)

---

## 7. Telegram Alerting & Interactive Control

**Responsibility**: Send quota/outage alerts in Arabic; provide admin buttons for manual WAN control.

| Property | Value |
|----------|-------|
| **Primary Files** | `MikroTik - Telegram Interactive Bot.json` (n8n workflow) |
| **Data Store** | Session state only (no DB persistence for interactions) |
| **Upstream Input** | Quota thresholds (80/95/100%), outage events, admin commands |
| **Downstream Consumer** | Admin Telegram chat (ID: 123456789) |
| **Classification** | EXTERNAL_WRITE, DATABASE_WRITE (state transitions) |
| **Operational Risk** | Medium — user commands trigger WAN state changes |
| **Security** | Strict admin verification (only TELEGRAM_ADMIN_CHAT_ID allowed) |

**Button Actions** (Telegram inline keyboard):
- `[ 🔄 تحديث الحالة الآن ]` — Refresh current quota status
- `[ 📊 ملخص اليوم ]` — Daily summary
- `[ 🔴 عزل خط WE (WAN2) ]` — Isolate WAN2
- `[ 🟢 استعادة خط WE (WAN2) ]` — Restore WAN2
- `[ 🔴 عزل فودافون (WAN1) ]` — Isolate WAN1
- `[ 🟢 استعادة فودافون (WAN1) ]` — Restore WAN1

**Idempotency**: Each button click auto-generates idempotency key (e.g., `tg-isolate-wan2-<minute_window>`) to prevent double-clicks.

---

### Deployed State (read-only inspection 2026-10-02)

| Property | Observed |
|----------|----------|
| **Workflow ID** | `mikrotik-interactive-telegram-bot` |
| **Active** | **NO** — `workflow_entity.active = f` |
| **Executions** | 0 |
| **Webhook registered** | Yes (`mikrotik-telegram-bot-trigger/webhook`) |
| **Router execution node** | **Absent** — no SSH/RouterOS/API node in graph |
| **Confirmation call** | **Absent** — `confirm_router_execution()` never invoked |
| **Consequence** | `transition_wan_state()` would record *desired* state only; the reported result would not reflect router reality |

**Router reachability blocker:** the router (`192.168.88.1`) is LAN-only. From
`deploy-server` (172.40.40.x) both TCP 22 and 8728 time out. Any router execution node
would need a VPN tunnel or an execution host inside the LAN. `router_config_clean.rsc`
also shows `set api disabled=yes` and `set api-ssl disabled=yes`, with SSH restricted to
`192.168.88.0/24,192.168.195.0/24` — so the API is currently disabled by config.

## 8. n8n Workflow Orchestration

**Responsibility**: Coordinate telemetry ingestion, quota evaluation, alerting, state transitions, and control execution.

| Property | Value |
|----------|-------|
| **Primary Files** | `MikroTik - Router Offline Monitor.json`, `MikroTik - Hotspot Ingestion.json`, `MikroTik - Quota Threshold Monitor.json`, `MikroTik - Telegram Interactive Bot.json`, `MikroTik - WAN Quality Ingestion.json` |
| **Entry Points** | Webhook receivers, scheduled triggers |
| **Data Stores** | PostgreSQL (state, audit) |
| **Classification** | EXTERNAL_WRITE (webhooks, Telegram), DATABASE_WRITE (state transitions) |
| **Operational Risk** | Medium-High — orchestrates both telemetry and control |

**Workflow Inventory**:
| Workflow | Trigger | Responsibility |
|----------|---------|-----------------|
| Quota Threshold Monitor | Webhook `mikrotik/wan-usage`; cron `55 23 * * *`; hourly | **Primary pipeline** (24 nodes): normalize telemetry → store reading + usage delta → check inactivity → check quota thresholds → update alert/incident state → Telegram alerts → compensation email |
| Router Offline Monitor | 5m schedule | Heartbeat check, offline detection, Telegram alerts |
| Hotspot Ingestion | Webhook `/webhook/mikrotik/hotspot-telemetry` | Parse, normalize, insert to DB, evaluate quota tiers |
| WAN Quality Ingestion | Webhook `/webhook/mikrotik/wan-quality` | Parse latency/loss, insert, trigger recovery if healthy |
| Telegram Interactive Bot | Telegram callback | Process admin commands, execute state transitions |

**Verified non-wiring (important)**: The Quota Threshold Monitor workflow contains **no SSH, RouterOS, or API node**, and never calls `transition_wan_state()` or `confirm_router_execution()`. Quota exhaustion raises **Telegram alerts only** — WAN isolation is not automated from n8n.

### Known Schema Drift

The Quota Threshold Monitor workflow writes to structures **not present in `schema.sql`**:
- Table `wan_outage_events` (columns include `landline_number`, `account_holder`, `started_at`, `ended_at`, `duration_minutes`)
- Column `outage_started_at` on `wan_incident_state` (absent from the `schema.sql` definition)

These must exist in the live database (created out-of-band) or the workflow fails at runtime. Treat `schema.sql` as incomplete rather than authoritative.

---

## 9. PostgreSQL Persistence

**Responsibility**: Store all telemetry, state, configuration, and audit logs.

| Property | Value |
|----------|-------|
| **Primary Files** | `schema.sql` |
| **Database** | `campaign_db` on `campaign-postgres` (Docker) |
| **Timezone** | Africa/Cairo (all timestamps normalized) |
| **Classification** | DATABASE_WRITE, READ_ONLY (views) |
| **Operational Risk** | Medium — state mutations affect control plane |

**Core Tables by Domain**:

| Domain | Tables |
|--------|--------|
| Telemetry | `mikrotik_wan_readings`, `mikrotik_wan_usage`, `mikrotik_wan_quality`, `hotspot_user_telemetry` |
| Quotas | `mikrotik_wan_quotas`, `billing_cycles`, `quota_allocations`, `quota_day_weights` |
| State | `router_heartbeat_state`, `wan_incident_state`, `wan_operational_state` |
| Control | `wan_control_actions` |
| Alerts | `quota_alert_state` |

**Key Views**:
- `view_mikrotik_wan_quota_status` — Full quota status with burn rate, projected exhaustion
- `view_mikrotik_wan_daily_usage` — Daily aggregated usage
- `view_mikrotik_wan_latest_quality` — Current quality per interface
- `view_hotspot_daily_user_usage` — Daily Hotspot user consumption

**Maintenance**: `purge_expired_mikrotik_telemetry(90)` — retention policy, weekly recommended

---

## 10. Grafana Visualization

**Responsibility**: Dashboard visualization of quota usage, traffic, quality metrics, and ISP summary.

| Property | Value |
|----------|-------|
| **Primary Files** | `docker-compose.monitoring.yml`, `provisioning/dashboards/*.json`, `provisioning/datasources/datasource.yml` |
| **Service** | Grafana container (port 3000) |
| **Datasource** | PostgreSQL `campaign_db` |
| **Classification** | DEPLOYMENT_INFRASTRUCTURE (provisioning), READ_ONLY (dashboards) |
| **Operational Risk** | Low — read-only visualization |

**Dashboard**: "MikroTik WAN Quota & Traffic Overview" (5 panels)
1. **Gauge**: WAN1/2 quota usage (%) — thresholds: <80% green, 80% amber, 95% red
2. **Pie Chart**: Traffic distribution & load balancing ratio
3. **Time Series**: Throughput & bandwidth (MB per 5-min sample)
4. **Stacked Bar**: Daily consumption (GB) over last 30 days
5. **Table**: ISP quota cycle summary (Quota, Used, Remaining, Burn Rate, Renewal Date)

**Provisioning**:
- Zero-touch: Auto-connect to PostgreSQL on startup
- Dashboard provider scans `/var/lib/grafana/dashboards`
- Auto-loads `mikrotik-overview.json` on container start

---

## 11. Python Operational Utilities

**Responsibility**: Ad-hoc database inspection, workflow management, and deployment support.

| Category | Examples | Classification |
|----------|----------|-----------------|
| **Inspection** | `check_quality_table.py`, `inspect_incident_table.py`, `list_n8n_workflows.py` | READ_ONLY |
| **Schema Modification** | `add_incident_cols.py`, `insert_quality_wf.sql`, `run_fix_sql.py` | DATABASE_WRITE |
| **Workflow Mgmt** | `activate_quality_wf.py`, `deploy_quality_workflow.py`, `register_quality_webhook.py` | DEPLOYMENT_INFRASTRUCTURE |
| **Alerting** | `dispatch_email.py`, `send_test_email.py` | EXTERNAL_WRITE |
| **Bot Management** | `install_bot_service.py`, `setup_remote_bot.py`, `update_bot_quality.py` | DEPLOYMENT_INFRASTRUCTURE |
| **Remote Ops** | `remote_cmd.py`, `verify_db_nodes.py` | SSH-mediated (LOCAL_ONLY execution, but remote effects) |

**Execution Model**: All use SSH to `deploy-server` host, execute Docker commands on remote machine.

**Risk**: Varies by utility. Inspection = low, workflow management = medium, remote commands = medium-high.

---

## 12. Deployment & Infrastructure

**Responsibility**: Service lifecycle, database migrations, provisioning automation.

| Component | Purpose | Classification |
|-----------|---------|-----------------|
| `docker-compose.monitoring.yml` | Grafana service definition | DEPLOYMENT_INFRASTRUCTURE |
| `schema.sql` Phase 1 | Database migration | DATABASE_WRITE |
| `provisioning/` | Zero-touch Grafana setup | DEPLOYMENT_INFRASTRUCTURE |
| DEPLOYMENT.md phases | Orchestrated deployment steps | DEPLOYMENT_INFRASTRUCTURE |

**Phase Breakdown** (from DEPLOYMENT.md):
1. **Phase 1**: Schema migration (DDL)
2. **Phase 2**: Grafana provisioning
3. **Phase 3**: Router heartbeat workflow
4. **Phase 4**: Hotspot telemetry ingestion
5. **Phase 5**: PBR/isolation configuration
6. **Phase 6**: State machine & control plane
7. **Phase 7**: Telegram interactive bot
8. **Phase 8**: WAN quality monitoring