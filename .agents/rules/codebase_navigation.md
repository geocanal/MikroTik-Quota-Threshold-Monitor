# Codebase Navigation Rules

Guidelines for agents navigating and modifying this MikroTik operations project.

## Progressive Exploration

**Do not repeatedly rediscover the whole repository.**

Navigation order:
1. Start with `AGENTS.md` at repository root
2. Read `.agents/context/README.md` for task routing
3. Open the relevant context map:
   - `ARCHITECTURE.md` for system structure
   - `CODEBASE_MAP.md` for file-to-purpose mapping
   - `DOMAIN_MAP.md` for functional domains
   - `DATA_FLOW.md` for end-to-end flows
4. Navigate to targeted source files
5. Expand to adjacent dependencies only when necessary

Broad repository scanning should NOT be the default approach.

## Map Trust Model

Navigation maps are aids, not absolute truth.

**Source code always wins over documentation.**

If source code contradicts a map:
1. Trust the source code
2. Note the discrepancy
3. Update the map only when:
   - The update is relevant to your current task
   - The discrepancy would mislead future agents
   - The update does not require excessive churn

Do NOT update maps for every minor source change.

## Mapping-Impact Awareness

Changes that may require navigation-map review:

| Change Type | Map Update Likely Needed |
|-------------|--------------------------|
| Moved/renamed mapped paths | Yes — update all references |
| Deleted mapped paths | Yes — remove stale entries |
| New subsystem/domain | Yes — add new domain entry |
| New major entry point | Yes — update CODEBASE_MAP |
| Architecture/data-flow changes | Yes — update ARCHITECTURE, DATA_FLOW |
| New operational side-effect surface | Yes — update classification |
| Changed scheduling/orchestration | Yes — update ARCHITECTURE, DOMAIN_MAP |
| Changed external integration | Yes — update DATA_FLOW, DOMAIN_MAP |
| Ordinary internal implementation changes | No — implementation details don't require map updates |

When in doubt, ask: "Would a future agent be misled without this update?"

## Safety Rules

**Navigation does not grant execution permission.**

Operational scripts must be classified before execution.

### Actions Requiring Explicit Task-Specific Approval

| Action | Classification | Why Approval Required |
|--------|----------------|----------------------|
| Execute RouterOS configuration/control scripts | ROUTER_WRITE | Can sever WAN connectivity, affect production traffic |
| Isolate or restore WAN interfaces | ROUTER_WRITE | Modifies firewall rules, changes traffic routing |
| Modify firewall/mangle/PBR rules | ROUTER_WRITE | Directly affects network traffic flow |
| Send production webhooks | EXTERNAL_WRITE | May trigger n8n workflows, cause state changes |
| Send Telegram messages | EXTERNAL_WRITE | Alerts admin users, may cause operational response |
| Send emails | EXTERNAL_WRITE | External communication, may trigger actions |
| Mutate production databases | DATABASE_WRITE | Changes state, may affect control plane |
| Restart production Docker containers | DEPLOYMENT_INFRASTRUCTURE | Service disruption, affects monitoring/alerting |
| Deploy infrastructure | DEPLOYMENT_INFRASTRUCTURE | Production changes, may affect availability |
| Run remote operational commands over SSH | EXTERNAL_WRITE / ROUTER_WRITE | Executes on remote production systems |
| Expose credentials or secret values | N/A | Security violation |

### Actions Permitted During Navigation

| Action | Permitted? | Notes |
|--------|------------|-------|
| Read RouterOS scripts | Yes | Understand logic without executing |
| Read n8n workflow JSON | Yes | Understand orchestration |
| Read PostgreSQL schema | Yes | Understand data model |
| Inspect Python utilities | Yes | Understand tooling |
| Query database (SELECT only) | Yes | Verify data, understand state |
| Check file existence | Yes | Validate paths |
| Run `ls`, `find`, `grep` equivalents | Yes | Discover files |
| Run syntax validators | Yes | Check code without executing |
| Run `git status`, `git log` | Yes | Understand history (if Git present) |

## Secrets Handling

Agents may document:
- Environment variable names (e.g., `TELEGRAM_ADMIN_CHAT_ID`, `DB_HOST`)
- Configuration keys (e.g., `webhookUrl`, `routerId`)
- Secret-loading mechanisms (e.g., `.env` file, RouterOS variables)
- Locations where configuration is expected

Agents must NOT:
- Copy secret values into navigation documentation
- Read `.env` files or credential files unless task requires
- Display passwords, tokens, API keys in chat or documentation

If a file contains secrets and must be read for a task:
- Reference it by name, not by value
- Never echo secret values back

## Operational Classification Quick Reference

| Classification | Meaning | Examples |
|----------------|---------|----------|
| READ_ONLY | Queries only, no side effects | `check_quality_table.py`, Grafana queries |
| LOCAL_ONLY | Runs locally, no external calls | Most inspection scripts |
| EXTERNAL_WRITE | Sends webhooks, emails, Telegram | `dispatch_email.py`, n8n webhook calls |
| DATABASE_WRITE | Modifies PostgreSQL data or schema | `schema.sql`, `transition_wan_state()` |
| ROUTER_WRITE | Modifies RouterOS configuration | `wan_control_pbr.rsc`, `wccp_control.rsc` |
| DEPLOYMENT_INFRASTRUCTURE | Docker, Grafana provisioning, service management | `docker-compose.monitoring.yml`, provisioning files |

## File Reading Order for New Tasks

```
1. AGENTS.md (root operating guide)
      ↓
2. .agents/context/README.md (entry point, task routing)
      ↓
3. Relevant context map:
   - ARCHITECTURE.md (system layers, control plane)
   - CODEBASE_MAP.md (file purposes, classifications)
   - DOMAIN_MAP.md (functional domains, data stores)
   - DATA_FLOW.md (source → consumer paths)
      ↓
4. Targeted source files (from map)
      ↓
5. Adjacent dependencies (only if needed)
      ↓
6. Tests/validation (if applicable)
```

## When to Broaden Exploration

Broaden beyond maintained maps when:
- Current maps are insufficient for the task
- Source code contradicts the maps significantly
- Exploring a new domain not yet mapped
- Map entries are stale, missing, or misleading

Report map deficiencies so they can be addressed.

## Validator Usage

Run `.agents/scripts/validate_codebase_map.py` to detect drift:
- Mapped paths that no longer exist
- Potentially new architectural paths
- Documentation churn issues

The validator does NOT automatically rewrite documentation.

Interpret results and update maps manually when appropriate.

## Summary

- Use maps first, broaden only when necessary
- Trust source code over documentation
- Navigation is analysis, not execution
- Classify before executing operational scripts
- Never expose secrets
- Update maps judiciously, not for every change