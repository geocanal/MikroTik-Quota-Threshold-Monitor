# Ingestion Repair — Network Connectivity Patch
#
# ROOT CAUSE (verified 2026-10-02):
#   n8n cannot resolve hostname 'app-postgres-1'.
#   n8n runs on Docker network 'n8n_n8n'.
#   app-postgres-1 runs on Docker network 'app_default'.
#   Docker DNS only resolves container names within the same network.
#   Error observed in n8n runtime: getaddrinfo ENOTFOUND app-postgres-1
#
# FIX: attach the n8n service to the external 'app_default' network.
#   - No PostgreSQL ports are published.
#   - No credentials change.
#   - No workflow definition change.
#
# ---------------------------------------------------------------------------
# TEMPORARY / RUNTIME FIX (does NOT survive container recreation)
# Apply on deploy-server:
#
#   sudo docker network connect app_default n8n
#
# Verify:
#   sudo docker exec n8n node -e "require('dns').lookup('app-postgres-1',(e,a)=>console.log(e?'FAIL '+e.code:'OK '+a))"
#   # expect: OK <ip>
#
# ROLLBACK (runtime membership only):
#   sudo docker network disconnect app_default n8n
#   # Do NOT restart n8n. Network membership changes apply to new connections only.
# ---------------------------------------------------------------------------
#
# PERSISTENT FIX — apply this to /opt/n8n/docker-compose.yml
# ---------------------------------------------------------------------------
# Add 'app_default' to the n8n service's networks list and declare the
# network as external at the bottom of the file.
#
# 1) Under services: n8n: -> networks:
#
#        networks:
#          - n8n
#          - app_default          # <-- ADD THIS LINE
#
# 2) At the bottom of the file, alongside the existing 'networks:' block:
#
#    networks:
#      n8n:
#        driver: bridge
#      app_default:               # <-- ADD THIS BLOCK
#        external: true
#        name: app_default
#
# 3) Recreate only the n8n container:
#
#        cd /opt/n8n && sudo docker compose up -d --no-deps n8n
#
#    This recreates n8n with both networks attached. It does NOT touch
#    n8n-postgres or any container on app_default.
#
# ROLLBACK (compose):
#        cd /opt/n8n && sudo docker compose up -d --no-deps n8n
#    after removing the two added blocks above.
# ---------------------------------------------------------------------------
#
# WHY THIS NETWORK (evaluation of alternatives)
#
#   Option A - attach n8n to app_default (SELECTED)
#     + Minimal: one service, one network reference.
#     + No new network, no port publication, no credential change.
#     + Matches the hostname the workflows already use.
#     - n8n gains reachability to other app_default services
#       (app-backend-1, app-redis-1, ...). Not currently needed by any
#       workflow node; acceptable for a single-host deployment.
#
#   Option B - dedicated shared network (NOT selected)
#     + Least privilege: only n8n and app-postgres-1 would join.
#     - Requires editing the app stack's compose too (it is owned by a
#       different project at /opt/<app>), plus network creation, plus
#       more moving parts to roll back. Not minimal.
#
#   Option C - network aliases only (NOT selected)
#     - INVALID. Aliases do not bridge separate Docker networks.
#       An alias on app_default cannot be resolved from n8n_n8n.
#
#   Option D - repoint workflows at n8n-postgres (NOT selected)
#     - Wrong database. n8n-postgres holds n8n's own workflow/execution
#       state, not the campaign telemetry tables.
#
# ---------------------------------------------------------------------------
# POST-ROLLOUT VERIFICATION (bounded, read-only)
#
#   1. DNS from the n8n runtime:
#      sudo docker exec n8n node -e "require('dns').lookup('app-postgres-1',(e,a)=>console.log(e?'FAIL '+e.code:'OK '+a))"
#
#   2. Authenticated read-only SQL through the same path n8n uses
#      (psql is NOT present in the n8n image; query from the DB container
#       and confirm reachability separately):
#      sudo docker exec app-postgres-1 psql -U campaign -d campaign_db -c \
#        "SELECT max(received_at) FROM mikrotik_wan_readings;"
#
#   3. Observe THREE collection intervals (5 min each = ~15 min) and confirm
#      for each stream that the persisted timestamp advances:
#        mikrotik_wan_readings.received_at
#        hotspot_user_telemetry.recorded_at
#        mikrotik_wan_quality.probed_at
#
#   4. Confirm workflow success counts start rising:
#      SELECT status, count(*) FROM execution_entity ... GROUP BY status;
#
# ---------------------------------------------------------------------------
# GAP-FILL CAUTION (do not skip this)
#
# The outage spans ~37.8 hours (2026-09-30 17:35 UTC -> 2026-10-02 07:22 UTC).
# On recovery the first delta is computed against a reading that is ~37.8 h
# old. Do NOT assume it is harmless:
#
#   - Calculate WAN Delta compares to the previous reading. A single large
#     delta over the whole gap will be recorded as one interval's usage,
#     inflating that bucket and distorting burn rate for the cycle.
#   - If the router counters did NOT reset, the 37.8 h total is real usage
#     and should be attributed deliberately (e.g. backdated hourly rows),
#     not silently collapsed into one 5-minute row.
#   - quota_alert_state is keyed by cycle_start and dedupes 80/95/100. A
#     spike may fire alerts that reflect gap-accumulated usage.
#
# RECOMMENDED: after connectivity is restored, inspect the first few new
# rows in mikrotik_wan_usage before enabling anything else. Decide on gap
# attribution explicitly rather than letting the first delta decide for you.