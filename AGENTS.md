# Agent Operating Guide

Root-level operating guide for coding and analysis agents working on the MikroTik Quota Threshold Monitor project.

## First Steps for New Agents

1. **Start here**: Read this file (AGENTS.md) first
2. **Navigate to context**: Read `.agents/context/README.md` for task routing
3. **Consult maps**: Use the relevant context map for your task:
   - `ARCHITECTURE.md` for system structure understanding
   - `CODEBASE_MAP.md` for file-to-purpose mapping
   - `DOMAIN_MAP.md` for functional domains
   - `DATA_FLOW.md` for end-to-end flow understanding
4. **Proceed to code**: Only then navigate to targeted source files

**DO NOT start with a broad repository scan.** Use the navigation layer first.

## Project Context

This is a distributed MikroTik network automation and monitoring system:

- **RouterOS v7** (MikroTik router) with scheduled telemetry collection
- **WAN usage & quota monitoring** with threshold alerts (80%/95%/100%)
- **Hotspot user telemetry** with per-user quota tracking
- **WAN quality monitoring** (latency, packet loss) with automated recovery
- **Policy-based routing** with WAN isolation/restore for quota exhaustion
- **n8n workflow orchestration** for ingestion, evaluation, alerts
- **PostgreSQL persistence** with structured state machine
- **Grafana visualization** with zero-touch provisioning
- **Telegram alerts & interactive control** (Arabic interface)
- **Python operational utilities** for ad-hoc management

## Safety Rules

**Navigation and analysis are allowed. Execution requires explicit approval.**

Agents must not, without task-specific approval and appropriate safeguards:

- Execute RouterOS configuration/control scripts (`wan_control_pbr.rsc`, `wccp_control.rsc`)
- Isolate or restore WAN interfaces (affects production traffic)
- Modify firewall/mangle/PBR rules
- Send production webhooks, emails, or Telegram messages
- Mutate production databases (except as directed by specific task)
- Restart production Docker containers
- Deploy infrastructure changes
- Run remote operational commands over SSH
- Expose credentials or secret values

### Operational Classification System

All components are classified:

| Classification | Meaning | Examples |
|----------------|---------|----------|
| `READ_ONLY` | Queries only, no side effects | Inspection scripts, dashboard queries |
| `LOCAL_ONLY` | Runs locally, no external calls | Most Python utilities |
| `EXTERNAL_WRITE` | Sends webhooks, emails, Telegram | `dispatch_email.py`, n8n webhook calls |
| `DATABASE_WRITE` | Modifies PostgreSQL data or schema | `schema.sql`, state transition functions |
| `ROUTER_WRITE` | Modifies RouterOS configuration | Isolation/restore scripts |
| `DEPLOYMENT_INFRASTRUCTURE` | Docker, provisioning, service management | Docker compose, Grafana provisioning |

**Check classification before execution.** Execution of ROUTER_WRITE components is especially critical.

## Secrets & Credentials

**What agents may document:**
- Environment variable names (`TELEGRAM_ADMIN_CHAT_ID`, `DB_HOST`, etc.)
- Configuration keys and expected locations
- Secret-loading mechanisms (`.env` files, RouterOS variables)
- Public/hardcoded values (Telegram chat ID `123456789`, webhook URLs)

**What agents must NOT do:**
- Copy secret values into navigation documentation
- Read `.env` files or credential files unless task requires
- Display passwords, tokens, API keys in chat or documentation
- Store secrets in any form other than the secure mechanisms already in use

If a file contains secrets and must be read for a task:
- Reference it by name only
- Do not echo secret values back
- Report existence but not content

## Progressive Exploration Strategy

```
AGENTS.md (this file)
  ↓
.agents/context/README.md (entry point, task routing)
  ↓
Relevant context map (ARCHITECTURE / CODEBASE_MAP / DOMAIN_MAP / DATA_FLOW)
  ↓
Targeted source files (from maps)
  ↓
Adjacent dependencies (only if needed)
  ↓
Tests/validation (if applicable)
```

**Broaden exploration only when:**
- Current maps are insufficient for the task
- Source code contradicts the maps significantly
- Exploring a new domain not yet mapped
- Map entries are stale, missing, or misleading

## Common Task Routing

| Task Type | Recommended Approach |
|-----------|----------------------|
| **RouterOS script investigation** | `DOMAIN_MAP.md` → RouterOS section → relevant `.rsc` file |
| **Database schema review** | `DATA_FLOW.md` + `DOMAIN_MAP.md` → PostgreSQL section → `schema.sql` |
| **Grafana dashboard work** | `DOMAIN_MAP.md` → Grafana section → `provisioning/dashboards/` |
| **n8n workflow analysis** | `DATA_FLOW.md` → relevant flow → corresponding workflow JSON |
| **Operational investigation** | `CODEBASE_MAP.md` → start with READ_ONLY utilities first |
| **New integration development** | `ARCHITECTURE.md` → understand layers → identify entry points |
| **Quota management changes** | `DOMAIN_MAP.md` → Quota Management → `view_mikrotik_wan_quota_status` → alert thresholds |

## Validation

Before making changes, run the navigation validator:
```bash
python .agents/scripts/validate_codebase_map.py
```

The validator will:
1. Check if mapped paths still exist
2. Flag critical missing components
3. Suggest potential new architectural paths to review
4. Report Git status (if available)

**Interpret validator results:**
- `PASS`: Maps consistent with repository
- `REVIEW_REQUIRED`: Some paths missing, check if renamed/deleted
- Critical missing paths indicate potential system breakage

## Map Maintenance

Navigation maps are **aids, not absolute truth**.

**Source code always wins over documentation.**

If you discover a discrepancy:
1. Trust the source code
2. Note the discrepancy for future reference
3. Update maps only when:
   - The update is relevant to your current task
   - The discrepancy would mislead future agents
   - The update doesn't create excessive churn

**Update maps for:**
- Moved/renamed/deleted mapped paths
- New subsystems/domains
- Architecture/data-flow changes
- New operational surfaces
- Changed external integrations

**Do NOT update maps for:**
- Ordinary internal implementation changes
- Minor refactoring
- Documentation formatting
- Test changes

## File Structure Quick Reference

```
.
├── AGENTS.md                          ← You are here
├── DEPLOYMENT.md                      # Production deployment guide (5 phases)
├── schema.sql                         # PostgreSQL DDL + seed data
├── docker-compose.monitoring.yml      # Grafana provisioning stack
├── *.rsc                              # RouterOS scripts (see CODEBASE_MAP.md)
├── provisioning/                      # Grafana zero-touch provisioning
├── MikroTik - *.json                  # n8n workflow definitions
├── *.py                               # Python operational utilities
└── .agents/                           # Navigation layer
    ├── context/                       # Navigation documentation
    │   ├── README.md                  # Entry point + task routing
    │   ├── ARCHITECTURE.md            # System layers, control vs observability
    │   ├── CODEBASE_MAP.md            # File-to-purpose mapping + classifications
    │   ├── DOMAIN_MAP.md              # Functional domains + data stores
    │   └── DATA_FLOW.md               # End-to-end flows with side effects
    ├── rules/
    │   └── codebase_navigation.md     # Navigation guidelines + safety rules
    └── scripts/
        └── validate_codebase_map.py   # Drift detection validator
```

## External Systems Integration

| System | Connection Method | Purpose |
|--------|-------------------|---------|
| MikroTik Router | HTTP webhooks, RouterOS scripts | Telemetry source, control target |
| PostgreSQL | Docker container, TCP 5432 | Persistence |
| n8n | Docker container, HTTP webhooks | Workflow orchestration |
| Grafana | Docker container, port 3000 | Visualization |
| Telegram Bot | Bot API, HTTPS | Alerts, interactive control |
| SSH deploy-server | SSH with config file | Remote Docker/DB commands |

## Next Steps

1. Read `.agents/context/README.md` for detailed task routing
2. Use maps to locate files relevant to your task
3. Classify components before considering execution
4. Validate maps with validator script
5. Proceed with your specific task

**Remember:** This is a production system with live infrastructure impact. Proceed with appropriate caution.