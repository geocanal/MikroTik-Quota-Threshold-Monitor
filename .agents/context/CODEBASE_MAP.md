# Codebase Map

Practical navigation for repository files and directories, organized by purpose and operational classification.

## Root-Level Files

| File | Purpose | Classification | Key Details |
|------|---------|-----------------|-------------|
| `DEPLOYMENT.md` | Production deployment guide (5 phases) | DEPLOYMENT_INFRASTRUCTURE | Covers schema migration, Grafana provisioning, router heartbeat, Hotspot ingestion, PBR, state machine, Telegram bot, WAN quality monitoring |
| `INGESTION_REPAIR.md` | **Active runbook**: Docker network root cause, fix options, rollout/rollback, gap-fill caution | DEPLOYMENT_INFRASTRUCTURE | Read before any ingestion or n8n network change |
| `schema_production_actual.sql` | Schema-only `pg_dump` of production `campaign_db` (72 public tables, no data, no secrets) | DATABASE_WRITE (as DDL source) | Reference for reconciling `schema.sql`; **not** to be applied to production |
| `test_network_isolation.yml` / `test_network_isolation.sh` | Isolated reproduction + verification of the network fix | LOCAL_ONLY | Run locally; uses throwaway containers, networks, credentials |
| `schema.sql` | PostgreSQL DDL and seed data | DATABASE_WRITE | All MikroTik tables/views/functions + seed data. **Reconciled with production**: includes `alerted_100` deduplication in `quota_alert_state`, `wan_outage_events` for legal claims, and the 6 co-hosted campaign tables (`quota_reservations`, `campaign_groups`, `campaign_metric_snapshots`, `campaign_rebalance_events`, `campaign_safety_settings`, `campaign_targets`). |
| `docker-compose.monitoring.yml` | Grafana service definition | DEPLOYMENT_INFRASTRUCTURE | Zero-touch provisioning stack on `campaign-network` |
| `docker-compose.server.yml` | Production server Grafana service definition | DEPLOYMENT_INFRASTRUCTURE | Server deployment connecting Grafana across `app_default` and `n8n_n8n` dual networks |

## RouterOS Configuration & Scripts

| File | Purpose | Classification | Interval | Safety Notes |
|------|---------|-----------------|----------|--------------|
| `hotspot_telemetry.rsc` | Collect Hotspot user sessions, limits, byte counters | READ_ONLY | 5m (scheduler) | Batches users, sends to n8n webhook. No router state changes. |
| `wan_quality.rsc` | Probe WAN interfaces (3 ICMP pings each) | READ_ONLY | 1-5m (scheduler) | Measures latency, packet loss, jitter. No router state changes. |
| `wan_control_pbr.rsc` | PCC policy-based routing + isolation/restore | ROUTER_WRITE | On-demand | **Critical**: Modifies firewall mangle, disables PCC rules, flushes marked connections. Includes safety contracts (INV-01 to INV-10) |
| `wccp_control.rsc` | Simplified isolation controller | ROUTER_WRITE | On-demand | **Critical**: Toggles WCCP-WAN2-ISOLATION-OVERRIDE rule. Performs survivor checks. |
| `router_config_clean.rsc` | **Full router configuration export — NOT unused.** Contains the live mangle rule set (`WCCP-WAN1/WAN2-ISOLATION-OVERRIDE`, PCC + legacy RULE-09..12), routing tables, the `send-wan-telemetry` script + `schedule-wan-telemetry` scheduler, and **four** isolation/restore scripts covering two competing designs | ROUTER_WRITE (if imported) | Treat as the authoritative reference for what is installed on the router. Verify against live router before acting. |

## Provisioning & Configuration

| Path | Purpose | Classification |
|------|---------|-----------------|
| `provisioning/datasources/datasource.yml` | Grafana PostgreSQL datasource config | DEPLOYMENT_INFRASTRUCTURE |
| `provisioning/dashboards/dashboards.yml` | Grafana dashboard provider | DEPLOYMENT_INFRASTRUCTURE |
| `provisioning/dashboards/hotspot-overview.json` | Hotspot user/quota dashboard | READ_ONLY |
| `provisioning/dashboards/mikrotik-overview.json` | Main WAN quota & traffic overview (5 panels) | READ_ONLY |

## n8n Workflow JSON Files

| File | Purpose | Classification | Triggered By |
|------|---------|-----------------|--------------|
| `MikroTik - Router Offline Monitor.json` | Dead man's switch heartbeat check | EXTERNAL_WRITE + DATABASE_WRITE | 5m schedule |
| `MikroTik - Hotspot Ingestion.json` | Webhook receiver → DB insert + quota alerts | EXTERNAL_WRITE + DATABASE_WRITE | n8n webhook `/webhook/mikrotik/hotspot-telemetry` |
| `MikroTik - WAN Quality Ingestion.json` | Quality telemetry receiver | EXTERNAL_WRITE + DATABASE_WRITE | n8n webhook `/webhook/mikrotik/wan-quality` |
| `MikroTik - Telegram Interactive Bot.json` | Telegram bot command receiver | EXTERNAL_WRITE + DATABASE_WRITE | Telegram callback queries |
| `MikroTik - Quota Threshold Monitor.json` | **Primary WAN usage ingestion + quota/incident alerting (24 nodes)** | EXTERNAL_WRITE + DATABASE_WRITE | Webhook `mikrotik/wan-usage`, cron `55 23 * * *`, hourly trigger |

## Python Operational Utilities

Group: **Offline Quota Preview** (LOCAL_ONLY)
- `quota_alert_dry_run.py` — Preview quota alert decisions from local JSON only; no DB, router, or notification calls.
- `DRY_RUN.md` — Arabic usage, synthetic input/output, and local-export limitations.
- `test_quota_alert_dry_run.py` — Standard-library offline unit tests.

Group: **Telemetry Retention & Housekeeping** (DATABASE_WRITE)
- `prune_telemetry.py` — Bounded chunked pruning of expired telemetry records with `--dry-run` and configurable day windows.
- `test_prune_telemetry.py` — Unit tests for retention date arithmetic, chunking logic, and mock database operations.

Group: **Database Inspection** (READ_ONLY)
- `check_quality_table.py` — Inspect `mikrotik_wan_quality` schema
- `check_hourly_usage.py` — Query hourly WAN usage for a date
- `inspect_incident_table.py` — Inspect `wan_incident_state` schema
- `inspect_dashboards.py` — Query dashboard definitions
- `inspect_outage_table.py` — Query outage state
- `inspect_webhook_entity.py` — Query n8n webhook table
- `inspect_webhook_rows.py` — Query webhook records
- `inspect_workflow_rows.py` — Query n8n workflow execution logs
- `list_bot_nodes.py` — List n8n bot nodes
- `list_n8n_workflows.py` — List n8n workflows

Group: **Database/Schema Modification** (DATABASE_WRITE)
- `add_bot_debug.py` — Add debugging to bot
- `add_incident_cols.py` — Add columns to incident table
- `add_owner.py` — Add owner field
- `insert_quality_wf.sql` — Insert quality workflow record
- `run_fix_sql.py` — Execute SQL fixes
- `fix_quality_version.py` — Fix quality workflow version
- `fix_workflow_history.py` — Fix workflow history

Group: **n8n Workflow Management** (DEPLOYMENT_INFRASTRUCTURE)
- `activate_quality_wf.py` — Enable quality monitoring workflow
- `deactivate_n8n_bot.py` — Disable Telegram bot
- `deploy_quality_workflow.py` — Deploy quality workflow
- `register_quality_webhook.py` — Register quality webhook in n8n
- `update_workflow_clean.py` — Update workflow definition
- `compare_workflows.py` — Compare two workflow versions

Group: **Email/Notification Dispatch** (EXTERNAL_WRITE)
- `dispatch_email.py` — Send test email via n8n
- `dispatch_correct_email.py` — Dispatch corrected email
- `dispatch_correct_vf.py` — Dispatch corrected Vodafone alert
- `dispatch_customized_email.py` — Send customized email
- `dispatch_live_vf.py` — Dispatch live Vodafone alert
- `send_test_email.py` — Send test email

Group: **Telegram Bot Operations** (EXTERNAL_WRITE + DATABASE_WRITE)
- `telegram_bot_daemon.py` — Standalone Telegram bot daemon (alternative to n8n)
- `install_bot_service.py` — Install bot as service
- `setup_remote_bot.py` — Setup remote bot deployment
- `test_deploy_bot.py` — Test bot deployment
- `update_bot_quality.py` — Update bot quality checks
- `update_bot_script.py` — Update bot script

Group: **Remote Operations** (SSH-based, LOCAL_ONLY from this host, but executes on remote)
- `remote_cmd.py` — Execute arbitrary remote commands
- `verify_db_nodes.py` — Verify database nodes
- `log_accurate_event.py` — Log event to database
- `log_live_claim.py` — Log claim to database

Group: **WAN/Router Control** (ROUTER_WRITE intent, mediated by SSH)
- `do_convert_bot.py` — Convert bot operations
- `patch_email_service.py` — Patch email service
- `prep_email_test.py` — Prepare email test
- `test_email_n8n.js` — Test email via n8n
- `test_webhook.py` — Test webhook connectivity
- `test_quality_webhook.py` — Test quality webhook

## Configuration & Miscellaneous

| File | Purpose |
|------|---------|
| `mikrotik.example.com.conf` | Nginx config (external system reference) |
| `.env` | **Present in working directory** (untracked; holds DB/Grafana/Telegram settings). Do not read or copy values. |
| `*.json` (dashboard backups) | Hotspot/WAN dashboard backups (unused) |

## Special Paths: Secrets & Credentials

| Item | Location | Type |
|------|----------|------|
| SSH config | `C:\Users\Ahmed Mohamed\.ssh\config` | Local file (not in repo) |
| `.env` variables | Present at repo root (untracked) | Not committed; values never copied into docs |
| Telegram chat ID | Hardcoded in workflows + scripts (`123456789`) | Known value, non-secret |
| Webhook URLs | Hardcoded in `hotspot_telemetry.rsc`, `wan_quality.rsc` | Known, environment-dependent |
| PostgreSQL credentials | Expected in `.env` | Not stored in repository |
| Router credentials | Assumed in RouterOS scripts | Not stored in repository |

## Navigation by Task

### "I need to understand WAN isolation"
Start: `DOMAIN_MAP.md` → WAN Control section
Then: `wan_control_pbr.rsc` (v1.0) or `wccp_control.rsc` (v1.1)
Then: `schema.sql` → `wan_operational_state`, `wan_control_actions` tables
Then: n8n quota engine workflow

### "I need to understand quota alerting"
Start: `DOMAIN_MAP.md` → Quota Management section
Then: `schema.sql` → `view_mikrotik_wan_quota_status` view
Then: `MikroTik - Quota Threshold Monitor.json` → `Check Quota Thresholds` / `Update Quota State` nodes
Then: `MikroTik - Telegram Interactive Bot.json`

### "I need to fix the Hotspot ingestion"
Start: `DATA_FLOW.md` → Hotspot Telemetry flow
Then: `hotspot_telemetry.rsc` (router script)
Then: `MikroTik - Hotspot Ingestion.json` (n8n workflow)
Then: `schema.sql` → `hotspot_user_telemetry` table

### "I need to add a new dashboard panel"
Start: `provisioning/dashboards/mikrotik-overview.json`
Then: `schema.sql` → relevant views (`view_mikrotik_wan_quota_status`, etc.)
Then: `DEPLOYMENT.md` → Phase 2 (Grafana provisioning)