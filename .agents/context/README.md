# Navigation Layer Entry Point

This directory contains the Living Codebase Navigation Layer for the MikroTik Quota Threshold Monitor project.

## What Each Document Contains

| Document | Purpose |
|----------|---------|
| `README.md` | This file — entry point and task routing |
| `ARCHITECTURE.md` | System architecture, layers, control vs observability plane |
| `CODEBASE_MAP.md` | Practical file-to-purpose mapping with classifications |
| `DOMAIN_MAP.md` | Functional domains (WAN telemetry, quota management, etc.) |
| `DATA_FLOW.md` | End-to-end data flows with source-to-consumer paths |

## Quick Task Routing

| Task Type | Start Here |
|-----------|------------|
| RouterOS script investigation | `DOMAIN_MAP.md` → RouterOS section → relevant `.rsc` file |
| Database schema review | `DATA_FLOW.md` + `DOMAIN_MAP.md` → PostgreSQL section → `schema.sql` |
| Grafana dashboard work | `DOMAIN_MAP.md` → Grafana section → `provisioning/dashboards/` |
| n8n workflow analysis | `DATA_FLOW.md` → relevant flow → corresponding workflow JSON |
| Operational investigation | `CODEBASE_MAP.md` → start with READ_ONLY utilities |
| New integration development | `ARCHITECTURE.md` → understand layers → identify entry points |

## How to Navigate Efficiently

1. **Start at the top**: Read `AGENTS.md` at repository root first
2. **Consult maps before code**: Use context documents to locate relevant files
3. **Follow the domain**: Use `DOMAIN_MAP.md` to find all files for a feature
4. **Trace the flow**: Use `DATA_FLOW.md` to understand data movement
5. **Verify with source**: Cross-check maps against actual code when uncertain

## Safety Classifications

All components are classified by operational risk:

| Classification | Meaning |
|----------------|---------|
| `READ_ONLY` | Queries only, no side effects |
| `LOCAL_ONLY` | Runs locally, no external calls |
| `EXTERNAL_WRITE` | Sends webhooks, emails, Telegram messages |
| `DATABASE_WRITE` | Modifies PostgreSQL data or schema |
| `ROUTER_WRITE` | Modifies RouterOS configuration, firewall rules, PBR |
| `DEPLOYMENT_INFRASTRUCTURE` | Docker, Grafana provisioning, service management |

**Navigation does not grant execution permission.** Classified components require explicit task approval before execution.

## Map Trust Model

Navigation maps are aids, not absolute truth. If source code contradicts documentation:
- Source code wins
- Note the discrepancy for future maintenance
- Update documentation only when relevant to your task

## Navigation Order for New Tasks

```
AGENTS.md (root)
  ↓
.agents/context/README.md (this file)
  ↓
Relevant context map (ARCHITECTURE / CODEBASE_MAP / DOMAIN_MAP / DATA_FLOW)
  ↓
Targeted source files
  ↓
Adjacent dependencies
  ↓
Tests/validation (if applicable)
```

## When to Broaden Exploration

Broaden beyond maintained maps when:
- Current maps are insufficient for the task
- Source code contradicts the maps
- Exploring a new domain not yet mapped
- Map entries are stale or missing

## Related Documents

- `.agents/rules/codebase_navigation.md` — Navigation rules and guidelines
- `DEPLOYMENT.md` — Production deployment instructions (not navigation)