# Complete Rollback Procedure for Network Fix

## Rollback Trigger

Rollback if:
1. Ingestion workflows remain in continuous failure after 15 minutes post-deployment
2. Manual SQL from app-postgres-1 shows no new rows in any telemetry table after 10 minutes
3. n8n container crashes or reports network errors after deployment
4. Webhook delivery timeouts or connection refused errors appear in n8n logs
5. User requests rollback

## Step 1: Restore Compose to Original Configuration

**On deploy-server:**

```bash
# Backup the current patched version (for forensics)
cd /opt/n8n
cp docker-compose.yml docker-compose.yml.patched.backup

# Restore original Compose (revert the two changes)
cat > docker-compose.yml << 'EOF'
services:

  postgres:
    image: postgres:16-alpine
    container_name: n8n-postgres
    restart: unless-stopped

    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}

    volumes:
      - ./postgres:/var/lib/postgresql/data

    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER}"]
      interval: 10s
      timeout: 5s
      retries: 5

    networks:
      - n8n

  n8n:
    build:
      context: .
      dockerfile: Dockerfile

    container_name: n8n
    restart: unless-stopped

    ports:
      - "127.0.0.1:5678:5678"

    depends_on:
      postgres:
        condition: service_healthy

    environment:
      NODES_EXCLUDE: "[]"

      DB_TYPE: postgresdb
      DB_POSTGRESDB_HOST: postgres
      DB_POSTGRESDB_PORT: 5432
      DB_POSTGRESDB_DATABASE: ${POSTGRES_DB}
      DB_POSTGRESDB_USER: ${POSTGRES_USER}
      DB_POSTGRESDB_PASSWORD: ${POSTGRES_PASSWORD}

      N8N_HOST: ${N8N_HOST}
      N8N_PORT: ${N8N_PORT}
      N8N_PROTOCOL: ${N8N_PROTOCOL}
      N8N_SKIP_AUTH_ON_OAUTH_CALLBACK: "true"
      N8N_BLOCK_ENV_ACCESS_IN_NODE: "false"
      FACEBOOK_PAGE_ID: ${FACEBOOK_PAGE_ID}
      FACEBOOK_PAGE_ACCESS_TOKEN: ${FACEBOOK_PAGE_ACCESS_TOKEN}
      WAVESPEED_API_KEY: ${WAVESPEED_API_KEY}
      WEBHOOK_URL: ${WEBHOOK_URL}

      GENERIC_TIMEZONE: ${GENERIC_TIMEZONE}
      TZ: ${TZ}

      N8N_ENCRYPTION_KEY: ${N8N_ENCRYPTION_KEY}

      N8N_BASIC_AUTH_ACTIVE: ${N8N_BASIC_AUTH_ACTIVE}
      N8N_BASIC_AUTH_USER: ${N8N_BASIC_AUTH_USER}
      N8N_BASIC_AUTH_PASSWORD: ${N8N_BASIC_AUTH_PASSWORD}
      N8N_SECURE_COOKIE: ${N8N_SECURE_COOKIE}

    volumes:
      - ./n8n:/home/node/.n8n
      - /opt/knowledge-pipeline:/knowledge-pipeline

    networks:
      - n8n

  text-overlay:
    build:
      context: ./text-overlay
      dockerfile: Dockerfile

    container_name: n8n-text-overlay
    restart: unless-stopped

    expose:
      - "8000"

    networks:
      - n8n

networks:
  n8n:
    driver: bridge
EOF
```

## Step 2: Graceful Container Reconciliation

**Do NOT restart n8n immediately.** Instead, gracefully disconnect it from app_default first (if already deployed with the patch), then recreate:

```bash
# If patch is already active, gracefully disconnect
sudo docker network disconnect app_default n8n 2>/dev/null || true

# Wait 5 seconds for any in-flight SQL to complete
sleep 5

# Recreate n8n container with original Compose
cd /opt/n8n
sudo docker compose up -d n8n --build

# Monitor logs for startup
sudo docker logs -f n8n --tail=20
```

**Expected logs:**
- `n8n Running under port 5678`
- `n8n Ready to receive requests` (within 30 seconds)
- NO `ENOTFOUND` or DNS errors

Press `Ctrl+C` to exit logs once ready.

## Step 3: Verify Original Network Membership

```bash
# Check n8n is back on n8n network only
sudo docker inspect n8n -f '{{json .NetworkSettings.Networks}}' | jq 'keys'

# Expected output: ["n8n"]
# If you see ["app_default", "n8n"], the patch is still active — STOP and troubleshoot
```

## Step 4: Validate Rollback Side Effects

### Expected: Ingestion Workflows Fail (Network Disconnected)

```bash
# Inside n8n, observe workflow status transitions from success to error
# Expected: Quota Threshold Monitor, Hotspot Ingestion, WAN Quality Monitor
#           all begin reporting ENOTFOUND app-postgres-1 again

# Monitor execution errors via REST:
curl -s -H "Authorization: Bearer ${N8N_API_KEY}" \
  https://n8n.example.com/api/v1/executions \
  | jq '.data[0:5] | .[] | {workflow_id, status, startedAt}' \
  | grep -A1 "error"
```

### Expected: No New Rows in Telemetry

```bash
# Wait 10 seconds (one collection cycle), then query:
sudo docker exec app-postgres-1 psql -U campaign -d campaign_db \
  -c "SELECT MAX(received_at) FROM mikrotik_wan_readings;"

# Should show no change from pre-rollback time (or the gap period)
```

## Step 5: Confirm DNS Resolution Fails (as Before)

```bash
# n8n can no longer resolve app-postgres-1
sudo docker exec n8n node -e \
  "require('dns').lookup('app-postgres-1',(e,a)=>console.log(e?'FAIL '+e.code:'OK '+a))"

# Expected: "FAIL ENOTFOUND" (same as pre-patch state)
```

## Step 6: Re-Enable Monitoring Dashboards

If you disabled alerting during the test, re-enable it. The workflows will be failing again,
which is expected. Do not re-patch until the root cause is addressed.

## Complete Rollback Command Sequence

**Run this if you need to rollback immediately:**

```bash
cd /opt/n8n

# 1. Restore original Compose
git checkout docker-compose.yml 2>/dev/null || \
cat > docker-compose.yml << 'EOF'
[original config above]
EOF

# 2. Disconnect from app_default (if connected)
sudo docker network disconnect app_default n8n 2>/dev/null || true
sleep 2

# 3. Recreate n8n
sudo docker compose up -d n8n --build

# 4. Wait for startup
sleep 20

# 5. Verify
sudo docker inspect n8n -f '{{json .NetworkSettings.Networks}}' | jq 'keys'
```

## Forensics After Rollback

If rollback was triggered by a failure, preserve:

```bash
# Logs from the failed deployment
sudo docker logs n8n > n8n-failed-logs.txt 2>&1
sudo docker logs app-postgres-1 > pg-failed-logs.txt 2>&1

# Execution records
sudo docker exec app-postgres-1 psql -U campaign -d campaign_db \
  -c "SELECT workflow_id, status, COUNT(*) FROM execution_entity \
      WHERE created_at > NOW() - INTERVAL '30 minutes' \
      GROUP BY workflow_id, status ORDER BY workflow_id, status;" \
  > executions-at-failure.txt

# Keep these for investigation
```

## No Secrets Exposed

This procedure uses only environment variable references (`${N8N_API_KEY}`)
and does not embed credentials or connection strings.
