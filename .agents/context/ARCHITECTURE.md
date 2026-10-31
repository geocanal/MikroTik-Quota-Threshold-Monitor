# System Architecture

This document captures the verified architecture of the MikroTik Quota Threshold Monitor system.

## High-Level Layers

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           MikroTik Router (RouterOS v7)                          │
│  ┌────────────────────┐  ┌────────────────────┐  ┌────────────────────────────┐ │
│  │ hotspot_telemetry  │  │ wan_quality        │  │ wan_control_pbr / wccp    │ │
│  │ (5min interval)    │  │ (1-5min interval)  │  │ (on-demand scripts)       │ │
│  └─────────┬──────────┘  └─────────┬──────────┘  └────────────┬─────────────┘ │
│            │                       │                          │                │
│            └───────────────────────┼──────────────────────────┘                │
│                                    ▼                                            │
│                     /tool fetch (HTTP POST webhooks)                           │
└─────────────────────────────────────────────────────────────────────────────────┘
                                    │
                    ┌───────────────┼───────────────┐
                    ▼               ▼               ▼
            ┌─────────────┐  ┌─────────────┐  ┌─────────────┐
            │    n8n      │  │ PostgreSQL  │  │  Grafana    │
            │ Workflows   │  │ campaign_db │  │  (Docker)   │
            └─────────────┘  └─────────────┘  └─────────────┘
                    │               │               │
                    ▼               │               ▼
            ┌─────────────┐         │       ┌─────────────┐
            │ Telegram    │◄────────┘       │ Dashboards  │
            │ Bot/Alerts  │                │ (5 panels)  │
            └─────────────┘                └─────────────┘
```

## Control Plane vs Observability Plane

### Observability Plane (Read-Only Telemetry)

| Component | Purpose | Classification |
|-----------|---------|----------------|
| `routeros/hotspot_telemetry.rsc` | Collects Hotspot user sessions, limits, bytes | READ_ONLY (router) |
| `routeros/wan_quality.rsc` | Probes latency/packet loss via ICMP | READ_ONLY (router) |
| n8n webhook receivers | Receive telemetry, insert to DB | EXTERNAL_WRITE |
| PostgreSQL tables | Store raw and calculated metrics | DATABASE_WRITE (append) |
| Grafana dashboards | Visualize metrics | READ_ONLY |

### Control Plane (State-Changing Operations)

| Component | Purpose | Classification |
|-----------|---------|----------------|
| `routeros/wan_control_pbr.rsc` | PCC/PBR rules, isolate/restore scripts | ROUTER_WRITE |
| `routeros/wccp_control.rsc` | Simplified isolation controller (ISOLATE_WAN2, RESTORE_WAN2) | ROUTER_WRITE |
| n8n quota engine workflow | Evaluates quota thresholds, triggers isolation | EXTERNAL_WRITE + DATABASE_WRITE |
| n8n Telegram bot workflow | Receives admin commands, executes state transitions | EXTERNAL_WRITE + DATABASE_WRITE |
| PostgreSQL state functions | `transition_wan_state()`, `confirm_router_execution()` | DATABASE_WRITE |
| Python utilities (some) | Register webhooks, modify DB state | DATABASE_WRITE |

## Scheduling/Ochestration

| Source | Target | Interval | Evidence |
|--------|--------|----------|----------|
| Router scheduler | `routeros/hotspot_telemetry.rsc` | 5m | DEPLOYMENT.md line 96 |
| Router scheduler | `routeros/wan_quality.rsc` | 2m (recommended) | DEPLOYMENT.md line 327 |
| n8n Schedule trigger | Router Offline Monitor workflow | 5m | DEPLOYMENT.md line 67 |
| n8n webhook | Hotspot Ingestion workflow | On webhook receipt | Passive |
| n8n webhook | Telegram Bot workflow | On Telegram callback | Passive |
| pg_cron / cron (external) | `purge_expired_mikrotik_telemetry()` | Weekly (recommended) | DEPLOYMENT.md line 138 |
| Manual | `isolate_wan1/2`, `restore_wan1/2` | On-demand | RouterOS scripts |

## Data Stores

| Store | Purpose | Primary Writer | Primary Reader |
|-------|---------|----------------|----------------|
| PostgreSQL `campaign_db` | All telemetry, state, configuration | n8n workflows, Python utilities | n8n, Grafana, Python utilities |
| Grafana dashboards | Visualization | Provisioning files (static) | Browser/UI |
| n8n workflows | Orchestration logic | JSON import | n8n engine |

## External Integrations

| System | Direction | Purpose |
|--------|-----------|---------|
| MikroTik Router | Incoming webhooks, outgoing scripts | Telemetry source, control target |
| PostgreSQL | Read/Write | Persistence |
| Grafana | Read | Visualization |
| Telegram Bot API | Outgoing | Alerts, interactive control |
| SSH `deploy-server` | Outbound | Remote Docker/DB commands (Python scripts only) |

## Verified Runtime State (observed 2026-10-02, read-only inspection)

Deployed n8n at `n8n.example.com` / container `n8n` (bind `127.0.0.1:5678`, not publicly bound).
Inspected via `workflow_entity`, `webhook_entity`, `execution_entity` on `n8n-postgres`.

| Workflow | ID | Active | Published versions | Executions (success/error) |
|---|---|---|---|---|
| MikroTik - Quota Threshold Monitor | `PPAQLTX0UUv4OnZl` | yes | 0 | 3341 / 2356 |
| MikroTik - Hotspot Ingestion | `jmKSudrEOTTyKT5Y` | yes | 0 | 1 / 1261 |
| MikroTik - WAN Quality Monitor | `mikrotik-wan-quality-monitor` | yes | 0 | 1276 / 1170 |
| **MikroTik - Telegram Interactive Bot** | `mikrotik-interactive-telegram-bot` | **NO** | – | 0 |
| **MikroTik - Router Offline Monitor** | `gJXWRMETNTegOggN` | **NO** | – | 0 |
| MikroTik - Quota Threshold Monitor (dup, stale) | `LgEUar2y0Jc5Bpz5` | no | – | 0 |

Registered webhooks: `mikrotik/wan-usage`, `mikrotik/hotspot-telemetry`,
`mikrotik/wan-quality`, `mikrotik-telegram-bot-trigger/webhook`.

**All three telemetry streams are stale** — last `received_at` / `recorded_at` / `probed_at`
all land at `2026-09-30 17:35–17:37 UTC`, while the webhook endpoint continues to receive
POSTs as recently as `2026-10-02 05:55 UTC`. Ingestion is failing downstream of receipt.
Failure names `app-postgres-1` and the failing node is `Get Previous Reading1`.

## Root Cause: Ingestion Failure (VERIFIED 2026-10-02)

**Confirmed cause:** Docker network separation. `getaddrinfo ENOTFOUND app-postgres-1`.

| Component | Container | Network |
|---|---|---|
| n8n | `n8n` | `n8n_n8n` |
| n8n's own DB | `n8n-postgres` | `n8n_n8n` |
| text overlay | `n8n-text-overlay` | `n8n_n8n` |
| Grafana | `mikrotik-grafana` | `n8n_n8n` |
| **campaign DB** | **`app-postgres-1`** | **`app_default`** |
| app backend/worker/scheduler/redis | `app-*` | `app_default` |

Docker's embedded DNS resolves container names **only within the same network**.
Every PostgreSQL node in the three ingestion workflows points at `app-postgres-1`,
which n8n cannot resolve.

Reproduced inside the real n8n runtime (read-only):
```
docker exec n8n node -e "require('dns').lookup('app-postgres-1',(e,a)=>console.log(e?'DNS_FAIL: '+e.code:'DNS_OK: '+a))"
→ DNS_FAIL: ENOTFOUND
```

### Stream freshness (inspected 2026-10-02 07:22 UTC)

| Stream | Last persisted | Age at inspection |
|---|---|---|
| `mikrotik_wan_readings` | 2026-09-30 17:35:23.278 UTC | 37.79 h |
| `hotspot_user_telemetry` | 2026-09-30 17:35:23.341 UTC | 37.79 h |
| `mikrotik_wan_quality` | 2026-09-30 17:37:27.382 UTC | 37.76 h |

Router POSTs are still arriving (webhook executions as recent as 2026-10-02 05:55 UTC);
they fail at the DB step. All timestamps stored as `timestamptz`; DB server timezone UTC.

### Execution error breakdown (explicit 24h filter, not cumulative)

| Workflow | errors | earliest | latest |
|---|---|---|---|
| Quota Threshold Monitor | 601 | 2026-10-01 07:25:23 UTC | 2026-10-02 07:20:44 UTC |
| Hotspot Ingestion | 288 | 2026-10-01 07:25:23 UTC | 2026-10-02 07:20:23 UTC |
| WAN Quality Monitor | 720 | 2026-10-01 07:23:28 UTC | 2026-10-02 07:21:27 UTC |

Cumulative totals (3341 ok / 2342 err etc.) are lifetime counts and **must not** be
read as a 24-hour rate. Note Hotspot has **1 success lifetime vs 1271 errors**.

### Second blocking defect: `alerted_100` missing (VERIFIED 2026-10-02 12:56 UTC)

The deployed quota workflow (`PPAQLTX0UUv4OnZl`, active) reads **and writes**
`quota_alert_state.alerted_100` in both `Check Quota Thresholds` and `Update Quota State`.
The production table has only `alerted_80`, `alerted_95`, `last_alert_at`.

Reproduced read-only against production:
```
ERROR:  column s.alerted_100 does not exist
```

**Consequence: fixing the network alone will NOT restore the quota workflow.** It will fail
at a later node with a different error. This requires a schema migration (DATABASE_WRITE,
separately authorized).

Also verified in deployed quota logic:
- `Get Previous Reading1` has **no staleness guard** — post-gap delta will span the whole outage
- `Calculate WAN Delta` treats a counter decrease as a reset → zeroes all four counters
- No backfill loop; the accumulated delta lands in a single `mikrotik_wan_usage` row
- wan2 is **already at 100%** (150.12/150 GB, cycle 2026-09-07 → 2026-10-07)

### Repair

Attach `n8n` to `app_default`. Full analysis, alternatives, rollout, rollback and
gap-fill caution: `docs/INGESTION_REPAIR.md`. Local isolated reproduction:
`test_network_isolation.sh` + `test_network_isolation.yml` (7/7 checks pass).

## Verified Gaps Between Design and Implementation

These are **VERIFIED** from reading the actual n8n workflow and RouterOS files. They matter
because the design documents (DEPLOYMENT.md, code comments) describe an automated control
plane that is not fully wired.

| # | Gap | Evidence | Impact |
|---|-----|----------|--------|
| 1 | **No router execution path in any deployed workflow.** No workflow contains an SSH / RouterOS / API node. | Zero matches for `ssh`, `routeros`, `api.mikrotik`, `/system script` across all 5 local exports; deployed `PPAQLTX0UUv4OnZl` has 24 nodes matching the local export | Quota exhaustion alerts only. **Scope limit:** this establishes absence *within the inspected workflows and their nodes*, not across all n8n features (e.g. a disabled credential or an external service invoked via `httpRequest` to a non-obvious host) |
| 2 | **`transition_wan_state()` HAS a caller** — the Telegram bot (`Execute State Transition`). `confirm_router_execution()` has none. | `workflows/MikroTik - Telegram Interactive Bot.json` node `Execute State Transition` calls `transition_wan_state($1..$6)`; keyword scan: `transition_wan_state` ×1, `confirm_router_execution` ×0 | **PARTIALLY CONTRADICTED** — an earlier audit wrongly said "never called". Because there is no execution node, the transition records *desired* state only and no router confirmation ever follows |
| 3 | **`wan_outage_events` table and `wan_incident_state.outage_started_at` are missing from `database/schema.sql`.** | String search: both absent from `database/schema.sql`, present in workflow SQL | `database/schema.sql` is not a complete/authoritative DDL; drift is real |
| 4 | **The isolation override rule DOES exist — in `routeros/router_config_clean.rsc`.** An earlier audit wrongly classified that file as "archived, unused". | `router_config_clean.rsc:174-177` creates `WCCP-WAN2-ISOLATION-OVERRIDE` (mark-connection → `cm_wan1`, `hotspot=from-client`, `in-interface=bridge`, **enabled**), positioned *before* the PCC rules | **CONTRADICTED** — prerequisite is present in the config export |
| 5 | **The WAN usage collector DOES exist — in `routeros/router_config_clean.rsc`.** An earlier audit wrongly reported no `.rsc` posts to `mikrotik/wan-usage`. | `router_config_clean.rsc:446-448` scheduler `schedule-wan-telemetry` (5m, `start-time=startup`) → script `send-wan-telemetry` (`:507-527`) POSTs `https://n8n.example.com/webhook/mikrotik/wan-usage` with `{router_id, uptime, wan1:{rx,tx}, wan2:{rx,tx}}` | **CONTRADICTED** — sender identified |
| 6 | **BOTH isolation designs are installed on the router and they are mutually contradictory.** `isolate_wan2` disables `RULE-10`/`RULE-12` (`:528-546`) while `ISOLATE_WAN2` enables the override (`:582+`); `restore_wan2` disables the override while `RESTORE_WAN2` also disables it. | `router_config_clean.rsc:528-597` — four scripts, two designs | **VERIFIED — highest operational risk** |
| 7 | **Mixed webhook destinations resolved:** `192.168.88.10:5678` vs `n8n.example.com` are not necessarily the same instance. | Deployed n8n has `WEBHOOK_URL=https://n8n.example.com/`; `send-wan-telemetry` and `routeros/wan_quality.rsc` use the public URL, while `routeros/hotspot_telemetry.rsc` still uses `192.168.88.10:5678` (LAN address) | **VERIFIED** — split configuration, LAN address may be stale |
| 8 | **Live ingestion is failing, not merely stale.** Webhooks still arrive (2026-10-02 05:55 UTC) but no rows are written since 2026-09-30 17:35 UTC. Root cause is Docker network separation — see "Root Cause" section above. | `execution_entity` error counts; n8n log `ENOTFOUND app-postgres-1`; Node DNS check inside n8n | **VERIFIED** — monitoring has been blind ~37.8 h |
| 9 | **Manual control is non-functional.** The Telegram bot calls `transition_wan_state()` but is **inactive** and has **no router execution node** and **no `confirm_router_execution()` call**. | `webhook_entity` shows the bot webhook; `workflow_entity.active = f`; zero executions; node graph ends at `Notify Action Result` | **VERIFIED** |
| 10 | **Router at `192.168.88.1` is unreachable from `deploy-server`** (172.40.40.x). Ports 8728/22 both time out. | TCP probe from deploy-server | **VERIFIED BLOCKER** — router is LAN-only, needs VPN or in-network host |
| 11 | **`routeros/router_config_clean.rsc` shows `set api disabled=yes`.** This is what a **configuration export** records, not what the live router is running. | `router_config_clean.rsc:285,287` | **UNVERIFIED as to live state** — the export may predate/postdate the live config. Live API status cannot be asserted without router access. Do not enable the API or expose management ports to resolve this. |

### Scope limits on earlier claims (corrected 2026-10-02)

- **Matching node counts do not prove equivalence.** The deployed workflow has 24 nodes
  and the local export has 24, which is suggestive but not conclusive — node *parameters*,
  credential bindings, and `connections` could still differ. Treat as UNVERIFIED until a
  normalized definition diff (node id/name/type + sorted parameters + connection graph)
  is compared. Not performed.
- **Cumulative execution counts are lifetime, not windowed.** "3341 ok / 2342 err" spans
  all history. Only the explicitly filtered 24h window (601 / 288 / 720 errors) is a rate.
- **Empty `wan_control_actions` does not prove no action ever occurred** — only that this
  table holds no rows today. Rows could have been deleted, or actions could have run
  outside the SQL ledger (e.g. a human running `/system script` in Winbox).
- **An active webhook does not identify its sender.** `mikrotik/wan-usage` being registered
  and receiving traffic does not by itself prove the MikroTik router is the source; the
  payload shape (`router_config_clean.rsc:517-520`) is what identifies it.

## Control Flow: WAN Isolation

> **Note:** The steps below describe the *designed* control plane. Per gap #1 and #2, the
> repository contains no automated n8n → router execution link. Today this flow is
> **operator-initiated** (Telegram button or manual `/system script run`), with the SQL
> state machine available but not invoked by the workflows in this repository.

```
Quota threshold reached (80%/100%)
        ↓
n8n quota engine workflow
        ↓
PostgreSQL: transition_wan_state(idempotency_key, ...)
        ↓ (if state changes)
n8n executes router script (via SSH or n8n node)
        ↓
RouterOS: isolate_wan1/2 OR restore_wan1/2
        ↓
RouterOS: WCCP-PCC/WAN2-ISOLATION-OVERRIDE rule toggled
        ↓
PostgreSQL: confirm_router_execution(...)
        ↓
Telegram: Alert sent to admin
```

## Key Architectural Properties

1. **Idempotent control plane**: All state transitions use idempotency keys to prevent duplicate operations
2. **Two-phase router confirmation**: Router execution must be confirmed before state is marked final
3. **Survivor verification**: Isolation requires the other WAN to be healthy before cutting traffic
4. **Egypt/Cairo timezone**: All timestamps normalized to Africa/Cairo
5. **Production hardening**: RouterOS scripts include ambiguity checks, error handling, and logging

## Files Not Part of This System

Dashboard backups and superseded dashboard exports only:
- `hotspot_dashboard_backup.json` — backup dashboard
- `wan_dashboard_backup.json` — backup dashboard
- `updated_wan_dashboard.json` — older dashboard version
- `verify_dash.json` — verification dashboard

**Correction (2026-10-02):** `routeros/router_config_clean.rsc` was previously listed here as
"archived / not part of active architecture". That was **wrong**. It contains the
installed mangle rules, routing tables, schedulers, and the WAN telemetry sender.
It is now mapped under RouterOS Configuration above.