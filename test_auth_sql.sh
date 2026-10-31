#!/bin/bash
set -euo pipefail

PROJECT="mikrotik-auth-sql-test"
COMPOSE_FILE="test_auth_sql.yml"

echo "=== Authenticated DB Connectivity FROM Client Container ==="
echo ""
echo "Proves: a non-PostgreSQL client, on a DIFFERENT network than the DB,"
echo "        can resolve + authenticate + read + write over the shared network."
echo ""

cleanup() { docker compose -p "$PROJECT" -f "$COMPOSE_FILE" down -v --remove-orphans 2>/dev/null || true; }
trap cleanup EXIT
cleanup 2>/dev/null || true

echo "1. Starting DB (app_default only) + client (n8n + app_default)..."
docker compose -p "$PROJECT" -f "$COMPOSE_FILE" up -d --quiet-pull >/dev/null 2>&1
sleep 6
echo "   ✓ Started"
echo ""

# Seed the table the test writes to
echo "1b. Seeding test table on the DB side..."
docker exec test-auth-pg psql -U campaign -d campaign_db -c "
    CREATE TABLE IF NOT EXISTS test_readings (
        id SERIAL PRIMARY KEY,
        router_id VARCHAR(64) NOT NULL,
        rx_bytes BIGINT NOT NULL DEFAULT 0,
        tx_bytes BIGINT NOT NULL DEFAULT 0,
        received_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
    TRUNCATE test_readings;
" >/dev/null 2>&1
echo "   ✓ Table ready and empty"
echo ""

# Install psql client INSIDE the client container (n8n-alpine-like)
echo "2. Installing PostgreSQL client in the CLIENT container (not the DB)..."
docker exec test-auth-client sh -c "apk add --no-cache postgresql-client >/dev/null 2>&1 && echo INSTALLED"
echo ""

echo "3. Verifying the client is NOT sharing a network-only shortcut with the DB..."
echo "   Client networks:"
docker inspect test-auth-client -f '{{range $k, $v := .NetworkSettings.Networks}}{{$k}}{{"\n"}}{{end}}' | sed 's/^/     /'
echo "   DB networks:"
docker inspect test-auth-pg -f '{{range $k, $v := .NetworkSettings.Networks}}{{$k}}{{"\n"}}{{end}}' | sed 's/^/     /'
echo ""

echo "4. DNS resolution FROM CLIENT container..."
RESOLVE=$(docker exec test-auth-client node -e \
  "require('dns').lookup('test-auth-pg',(e,a)=>console.log(e?'FAIL '+e.code:'OK '+a))" 2>&1)
echo "   $RESOLVE"
if ! echo "$RESOLVE" | grep -q "OK"; then echo "   ✗ DNS FAILED"; exit 1; fi
echo "   ✓ DNS resolves from client"
echo ""

echo "5. Authenticated SELECT executed FROM CLIENT container..."
SEL=$(docker exec -e PGPASSWORD=campaign_pass test-auth-client \
  psql -h test-auth-pg -U campaign -d campaign_db -t -A \
  -c "SELECT current_user || '@' || current_database();" 2>&1)
echo "   $SEL"
if ! echo "$SEL" | grep -q "campaign@campaign_db"; then echo "   ✗ SELECT failed"; exit 1; fi
echo "   ✓ Authenticated read works over TCP from client container"
echo ""

echo "6. NEGATIVE CONTROL - wrong password must FAIL (proves auth is real)..."
BAD=$(docker exec -e PGPASSWORD=wrong_pass test-auth-client \
  psql -h test-auth-pg -U campaign -d campaign_db -t -A \
  -c "SELECT 1;" 2>&1 || true)
if echo "$BAD" | grep -qi "password authentication failed"; then
  echo "   ✓ Correctly rejected: $(echo "$BAD" | head -1 | head -c 60)"
  echo "   ✓ Auth is genuinely enforced (not open trust)"
else
  echo "   ✗ Expected auth failure, got: $BAD"
  exit 1
fi
echo ""

echo "7. Authenticated INSERT executed FROM CLIENT container..."
INS=$(docker exec -e PGPASSWORD=campaign_pass test-auth-client \
  psql -h test-auth-pg -U campaign -d campaign_db -t -A \
  -c "INSERT INTO test_readings (router_id, rx_bytes, tx_bytes) VALUES ('client-write-test', 111, 222);" 2>&1)
echo "   $INS"
if ! echo "$INS" | grep -q "INSERT 0 1"; then echo "   ✗ INSERT failed"; exit 1; fi
echo "   ✓ Authenticated write works from client container"
echo ""

echo "8. Verifying the row is visible to a fresh client connection..."
CNT=$(docker exec -e PGPASSWORD=campaign_pass test-auth-client \
  psql -h test-auth-pg -U campaign -d campaign_db -t -A \
  -c "SELECT COUNT(*) FROM test_readings WHERE router_id='client-write-test';" 2>&1 | tr -d ' ')
echo "   Rows found: $CNT"
if [ "$CNT" != "1" ]; then echo "   ✗ Write not visible"; exit 1; fi
echo "   ✓ Client write confirmed by client read"
echo ""

echo "=== SUMMARY ==="
echo "✓ DNS resolves from a non-DB container across the shared network"
echo "✓ TCP + password authentication works from the CLIENT container"
echo "✓ Negative control: wrong password is rejected (auth genuinely enforced)"
echo "✓ Authenticated INSERT works from the CLIENT container"
echo "✓ Client-side read confirms the write landed"
echo ""
echo "TESTED: full client-originated DB path (DNS + TCP + auth + read + write)"
echo "NOT TESTED: an actual n8n PostgreSQL NODE inside a real workflow."
echo "           That requires the production n8n image + deployed credentials,"
echo "           which cannot be exercised without deploying the network patch."