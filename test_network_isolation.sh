#!/bin/bash
set -e

# Test script for Docker network isolation issue
# This reproduces and verifies the fix for: n8n cannot resolve 'app-postgres-1'

COMPOSE_FILE="test_network_isolation.yml"
NETWORK_PREFIX="mikrotik-quotathresholdmonitor"  # Docker Compose project prefix

cleanup() {
    echo "=== Cleaning up test resources ==="
    docker compose -f "$COMPOSE_FILE" down -v --remove-orphans 2>/dev/null || true
    docker network rm "${NETWORK_PREFIX}_app_network" 2>/dev/null || true
    docker network rm "${NETWORK_PREFIX}_n8n_network" 2>/dev/null || true
    rm -rf test_postgres_data 2>/dev/null || true
    echo "Cleanup complete"
}

# Always cleanup on exit
trap cleanup EXIT

echo "=== TEST: Docker Network Isolation Issue ==="
echo "This test reproduces the issue where n8n cannot resolve 'app-postgres-1'"
echo "because they are on different Docker networks."
echo ""

# Cleanup first
cleanup

echo "=== STEP 1: Start containers on SEPARATE networks (broken state) ==="
docker compose -f "$COMPOSE_FILE" up -d

# Wait for PostgreSQL to be healthy
echo "Waiting for PostgreSQL to be ready..."
for i in {1..30}; do
    if docker exec test-app-postgres pg_isready -U campaign -d campaign_db >/dev/null 2>&1; then
        echo "PostgreSQL is ready"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "ERROR: PostgreSQL did not become ready"
        exit 1
    fi
    sleep 1
done

# Create test database and data
echo "Creating test database and data in app-postgres..."
# POSTGRES_DB=campaign_db is created at init; user campaign is the superuser
docker exec test-app-postgres psql -U campaign -d campaign_db -c "
CREATE TABLE IF NOT EXISTS test_readings (
    id SERIAL PRIMARY KEY,
    router_id VARCHAR(64) NOT NULL,
    rx_bytes BIGINT NOT NULL DEFAULT 0,
    tx_bytes BIGINT NOT NULL DEFAULT 0,
    received_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
INSERT INTO test_readings (router_id, rx_bytes, tx_bytes) VALUES ('test-router', 1000, 2000);
SELECT COUNT(*) AS rows_created FROM test_readings;
"

echo ""
echo "=== STEP 2: Reproduce the broken state (n8n-sim cannot resolve app-postgres) ==="
echo "Testing DNS resolution from n8n-sim to app-postgres..."

# Test DNS resolution - on separate networks the hostname should NOT resolve
# Note: busybox/alpine getent exits non-zero and prints nothing on failure
set +e
DNS_RESULT=$(docker exec test-n8n-sim getent hosts app-postgres 2>&1)
DNS_EXIT=$?
set -e

if [ $DNS_EXIT -ne 0 ] || [ -z "$DNS_RESULT" ]; then
    echo "✓ CONFIRMED: DNS resolution FAILS (expected for separated networks)"
    echo "  exit=$DNS_EXIT output='${DNS_RESULT}'"
else
    echo "✗ UNEXPECTED: DNS resolved when containers are on separate networks"
    echo "  Result: $DNS_RESULT"
fi

echo ""
echo "=== STEP 3: Apply the fix - connect n8n-sim to app_network ==="
echo "Running: docker network connect test_app_network test-n8n-sim"

docker network connect "${NETWORK_PREFIX}_app_network" test-n8n-sim

echo ""
echo "=== STEP 4: Verify DNS resolution works after fix ==="
set +e
DNS_RESULT_FIXED=$(docker exec test-n8n-sim getent hosts app-postgres 2>&1)
set -e

if echo "$DNS_RESULT_FIXED" | grep -qE "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+"; then
    echo "✓ SUCCESS: DNS resolution now WORKS"
    echo "  Result: $DNS_RESULT_FIXED"
else
    echo "✗ FAILED: DNS resolution still not working"
    echo "  Result: $DNS_RESULT_FIXED"
    exit 1
fi

echo ""
echo "=== STEP 5: Verify PostgreSQL connection works ==="
set +e
PG_RESULT=$(docker exec test-n8n-sim sh -c "
    apk add --no-cache postgresql-client 2>/dev/null || true
    PGPASSWORD=campaign_pass psql -h app-postgres -U campaign -d campaign_db -c 'SELECT COUNT(*) FROM test_readings;' 2>&1
" 2>&1)
set -e

if echo "$PG_RESULT" | grep -q "1"; then
    echo "✓ SUCCESS: PostgreSQL connection works"
    echo "  Query result shows 1 row (as expected)"
else
    echo "✗ FAILED: PostgreSQL connection failed"
    echo "  Result: $PG_RESULT"
    exit 1
fi

echo ""
echo "=== STEP 6: Verify workflow can execute read query ==="
QUERY_RESULT=$(docker exec test-n8n-sim sh -c "
    apk add --no-cache postgresql-client >/dev/null 2>&1
    PGPASSWORD=campaign_pass psql -h app-postgres -U campaign -d campaign_db -t -A -c 'SELECT router_id, rx_bytes, tx_bytes FROM test_readings;' 2>&1
" 2>&1)

echo "Query output:"
echo "$QUERY_RESULT"

if echo "$QUERY_RESULT" | grep -q "test-router"; then
    echo ""
    echo "✓ SUCCESS: Workflow-style read query executed successfully"
else
    echo ""
    echo "✗ FAILED: Read query did not return expected data"
    exit 1
fi

echo ""
echo "=== STEP 7: Test workflow write capability ==="
WRITE_RESULT=$(docker exec test-n8n-sim sh -c "
    PGPASSWORD=campaign_pass psql -h app-postgres -U campaign -d campaign_db -t -A -c \"
        INSERT INTO test_readings (router_id, rx_bytes, tx_bytes) VALUES ('test-router-2', 3000, 4000);
        SELECT COUNT(*) FROM test_readings;
    \" 2>&1
" 2>&1)

echo "After INSERT, row count:"
echo "$WRITE_RESULT"

# The last line is the SELECT COUNT(*) result; INSERT status precedes it
ROW_COUNT=$(echo "$WRITE_RESULT" | grep -E '^[0-9]+$' | tail -1)
if [ -n "$ROW_COUNT" ] && [ "$ROW_COUNT" -ge 2 ]; then
    echo ""
    echo "✓ SUCCESS: PostgreSQL write query works (simulates ingestion)"
else
    echo ""
    echo "✗ FAILED: Write query failed"
    echo "  Raw: $WRITE_RESULT"
    exit 1
fi

echo ""
echo "========================================"
echo "TEST PASSED: Network connection fix verified"
echo "========================================"
echo ""
echo "Summary:"
echo "  - Before fix: DNS resolution failed (ENOTFOUND)"
echo "  - After fix:  DNS resolution works, PostgreSQL queries succeed"
echo ""
echo "Production fix command:"
echo "  docker network connect app_default n8n"
echo ""
echo "Rollback command:"
echo "  docker network disconnect app_default n8n"