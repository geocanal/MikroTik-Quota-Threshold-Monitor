# Production Ingestion Repair: Rollout & Acceptance

**Status:** READY FOR APPROVAL  
**Root Cause:** Docker network separation (verified 2026-10-02)  
**Fix:** Attach n8n to app_default network (minimal, non-breaking)  
**Expected Interruption:** ~30 seconds (container recreation)  
**Risk Level:** LOW (network-layer only, no schema/credential changes)

---

## Pre-Rollout Checklist

- [ ] Read all three runbooks: `INGESTION_REPAIR.md`, `ROLLBACK_PROCEDURE.md`, `QUOTA_ALERT_BEHAVIOR.md`
- [ ] Isolated test passed (9/9 checks): `test_persistent_simple.sh` ✓
- [ ] Schema verified: ingestion-write tables match production (8, 22, 11 columns) ✓
- [ ] Compose patch validated: only n8n service + app_default network added ✓
- [ ] No production data modified yet
- [ ] No router changes required
- [ ] No inactive workflows activated

---

## Phase 1: Apply Compose Patch (5 minutes)

**Operator:** Access to `/opt/n8n/docker-compose.yml` on deploy-server via SSH.

### 1a. Backup Original

```bash
cd /opt/n8n
cp docker-compose.yml docker-compose.yml.original.backup
echo "Backup saved: $(date -u +'%Y-%m-%dT%H:%M:%SZ')" >> docker-compose.yml.original.backup
```

### 1b. Apply Patch

Replace n8n service and networks block. **Exact change:**

**Line 74 (n8n service networks):** ADD one line:
```yaml
    networks:
      - n8n
      - app_default        # ← ADD THIS LINE ONLY
```

**Lines 92-93 (networks block):** ADD one network definition:
```yaml
networks:
  n8n:
    driver: bridge
  app_default:            # ← ADD THIS BLOCK
    external: true
    name: app_default
```

**Result:** Patched file `n8n_compose_patched.yml` provided in project.

```bash
# Option A: Use the provided patched file (fastest)
cp n8n_compose_patched.yml docker-compose.yml

# Option B: Manual edit (verify with: docker compose config)
# (edit as above, then verify)
docker compose config >/dev/null 2>&1 && echo "Compose valid" || echo "FAILED"
```

### 1c. Verify Patch

```bash
# Check that only n8n service now has two networks
docker compose config | grep -A 5 "services:" | grep -A 20 "n8n:"

# Expected in output:
#   networks:
#   - n8n
#   - app_default
```

---

## Phase 2: Recreate n8n Container (~30 seconds)

```bash
cd /opt/n8n

# Recreate n8n service only (postgres stays running)
docker compose up -d n8n --build

# Monitor startup (watch for 2-3 lines of logs, then Ctrl+C)
docker logs -f n8n --tail=20 &
sleep 5
kill %1 2>/dev/null || true
```

**Expected logs:**
```
n8n Running under port 5678
n8n Ready to receive requests
(no DNS errors, no ENOTFOUND, no network failures)
```

### Phase 2b: Verify Network Membership

```bash
# n8n should now be on BOTH networks
docker inspect n8n -f '{{json .NetworkSettings.Networks}}' | jq 'keys'

# Expected output:
# ["app_default", "n8n"]
```

**If output shows only `["n8n"]`, STOP and rollback immediately.**

---

## Phase 3: Observe Ingestion Recovery (10-15 minutes)

### 3a. DNS Verification (30 seconds)

```bash
# Confirm n8n can now resolve app-postgres-1
docker exec n8n node -e \
  "require('dns').lookup('app-postgres-1',(e,a)=>console.log(e?'FAIL '+e.code:'OK '+a))"

# Expected: OK <ip>
# If FAIL ENOTFOUND: network not attached properly, ROLLBACK
```

### 3b. Workflow Execution Status (1-2 minutes)

Watch n8n dashboard at `https://n8n.example.com/` (or `http://192.168.88.10:5678`):
- Navigate to **Executions**
- Filter by workflow: "Quota Threshold Monitor", "Hotspot Ingestion", "WAN Quality Monitor"
- Status should transition from red (error) to green (success) within 2-3 collection cycles

**Expected pattern:**
```
Before patch:  🔴 Error: ENOTFOUND app-postgres-1
After patch:   🟢 Success (within ~2 minutes)
               🟢 Success
               🟢 Success
```

### 3c. Database Verification (3-5 minutes)

Check that new rows are being persisted (one row per 5-minute collection cycle):

```bash
# Latest timestamp in each telemetry table
docker exec app-postgres-1 psql -U campaign -d campaign_db -c "
  SELECT 
    'wan_readings' AS stream,
    MAX(received_at) AS last_timestamp,
    COUNT(*) AS total_rows,
    NOW() - MAX(received_at) AS age_seconds
  FROM mikrotik_wan_readings
  UNION ALL
  SELECT 
    'hotspot_telemetry',
    MAX(recorded_at),
    COUNT(*),
    NOW() - MAX(recorded_at)
  FROM hotspot_user_telemetry
  UNION ALL
  SELECT 
    'wan_quality',
    MAX(probed_at),
    COUNT(*),
    NOW() - MAX(probed_at)
  FROM mikrotik_wan_quality
  ORDER BY last_timestamp DESC;
"

# Expected (2-3 minutes after patch):
# stream          | last_timestamp           | total_rows | age_seconds
# wan_readings    | 2026-10-02 08:25:XX +00  | XXXX       | 00:00:15
# hotspot_telemetry | 2026-10-02 08:25:XX +00 | XXXX       | 00:00:18
# wan_quality     | 2026-10-02 08:25:XX +00  | XXXX       | 00:00:12

# If age_seconds > 5 minutes (300s): ingestion is still failing, ROLLBACK
```

### 3d. Quota Alert State Check (5-10 minutes)

```bash
# Check if quota alerts fired (expected if large gap delta exceeded thresholds)
docker exec app-postgres-1 psql -U campaign -d campaign_db -c "
  SELECT 
    cycle_start,
    alerted_80,
    alerted_95,
    last_alert_at
  FROM quota_alert_state
  WHERE cycle_start >= '2026-10-02'
  ORDER BY last_alert_at DESC NULLS LAST
  LIMIT 5;
"

# Expected (if quota > 80%):
# cycle_start | alerted_80 | alerted_95 | last_alert_at
# 2026-10-02  | t          | t          | 2026-10-02 08:25:XX +00
```

---

## Phase 4: Three Collection Cycles Confirmation (20-25 minutes total)

After patch deployment, observe **three consecutive successful 5-minute collections**:

| Collection # | Time | WAN Readings | Hotspot | WAN Quality | n8n Status |
|---|---|---|---|---|---|
| Cycle 1 | 07:25 UTC | ✓ new row | ✓ new row | ✓ new row | 🟢 success |
| Cycle 2 | 07:30 UTC | ✓ new row | ✓ new row | ✓ new row | 🟢 success |
| Cycle 3 | 07:35 UTC | ✓ new row | ✓ new row | ✓ new row | 🟢 success |

**Acceptance Criteria: ALL THREE cycles must succeed with visible row increments.**

```bash
# Run this script after ~25 minutes post-patch to generate final report
docker exec app-postgres-1 psql -U campaign -d campaign_db -c "
  SELECT 
    'Cycle 1' AS cycle,
    (SELECT MAX(received_at) FROM mikrotik_wan_readings 
     WHERE received_at > NOW() - INTERVAL '25 minutes' 
     AND received_at < NOW() - INTERVAL '20 minutes') AS timestamp,
    (SELECT COUNT(*) FROM mikrotik_wan_readings 
     WHERE received_at > NOW() - INTERVAL '25 minutes' 
     AND received_at < NOW() - INTERVAL '20 minutes') AS rows
  UNION ALL
  SELECT 'Cycle 2', 
    (SELECT MAX(received_at) FROM mikrotik_wan_readings 
     WHERE received_at > NOW() - INTERVAL '20 minutes' 
     AND received_at < NOW() - INTERVAL '15 minutes'),
    (SELECT COUNT(*) FROM mikrotik_wan_readings 
     WHERE received_at > NOW() - INTERVAL '20 minutes' 
     AND received_at < NOW() - INTERVAL '15 minutes')
  UNION ALL
  SELECT 'Cycle 3',
    (SELECT MAX(received_at) FROM mikrotik_wan_readings 
     WHERE received_at > NOW() - INTERVAL '15 minutes' 
     AND received_at < NOW() - INTERVAL '10 minutes'),
    (SELECT COUNT(*) FROM mikrotik_wan_readings 
     WHERE received_at > NOW() - INTERVAL '15 minutes' 
     AND received_at < NOW() - INTERVAL '10 minutes');
"
```

---

## Phase 5: Post-Deployment Verification (Ongoing)

### Dashboard Recovery
- [ ] Grafana dashboard shows telemetry data (no gaps after 07:25 UTC)
- [ ] Historical data before gap remains intact
- [ ] New ingestion continues smoothly

### Expected Quota Alert Notifications
- [ ] If quota exceeded 80%: Telegram alert sent to `TELEGRAM_ADMIN_CHAT_ID`
- [ ] Alert timestamp matches first collection cycle (07:25 UTC area)
- [ ] Alert magnitude reflects gap-accumulated usage (large delta is expected and correct)

### Alert State Reconciliation
- [ ] No manual quota resets required
- [ ] No counter truncation or replay
- [ ] Large first delta is the correct representation of 37.8-hour accumulated usage

---

## Acceptance Sign-Off

**Patch is ACCEPTED when all of the following are true:**

1. ✓ Compose patch applied without errors
2. ✓ n8n container recreated successfully
3. ✓ n8n is on both networks (confirmed via docker inspect)
4. ✓ DNS resolution works (app-postgres-1 is resolvable from n8n)
5. ✓ First collection cycle succeeded with new telemetry rows
6. ✓ Second collection cycle succeeded
7. ✓ Third collection cycle succeeded
8. ✓ Grafana dashboard shows data recovery
9. ✓ No workflows remain in error state
10. ✓ Quota alerts (if any) are legitimate (gap-accumulated usage)

**Acceptance Timestamp:** __________ UTC  
**Verified By:** __________  
**Notes:** __________

---

## Rollback Triggers

**STOP and ROLLBACK immediately if:**

1. DNS resolution fails after 1 minute post-patch
2. After 5 minutes, no new rows appear in telemetry tables
3. Workflows remain in continuous error state after 10 minutes
4. n8n container crashes or restarts repeatedly
5. Network connectivity errors appear in n8n logs
6. app-postgres-1 becomes unreachable from outside n8n

**Rollback command:**
```bash
cd /opt/n8n
cp docker-compose.yml.original.backup docker-compose.yml
docker compose up -d n8n --build
sleep 30
docker inspect n8n -f '{{json .NetworkSettings.Networks}}' | jq 'keys'
# Should show ["n8n"] only
```

---

## Post-Rollout Monitoring (Next 24 Hours)

- [ ] Telemetry continues flowing uninterrupted
- [ ] No gaps in collection timestamps
- [ ] Quota usage calculated correctly (no spikes or drops)
- [ ] Alerts fire at appropriate thresholds (not artificially suppressed)
- [ ] n8n logs show no repeated errors or connection failures
- [ ] Router continues posting webhooks successfully
- [ ] Dashboard remains responsive and up-to-date

---

## No Additional Changes Required

This patch:
- ❌ Does NOT change router configuration
- ❌ Does NOT modify webhook destinations
- ❌ Does NOT alter database schema
- ❌ Does NOT update credentials or secrets
- ❌ Does NOT activate inactive workflows
- ❌ Does NOT enable router control or isolation

**Only the n8n→app-postgres network attachment changes.**
