#!/bin/bash
set -euo pipefail

PROJECT="mikrotik-compose-lifecycle-test"
COMPOSE_FILE="test_compose_parsing.yml"
SERVICE="n8n-sim"

echo "=== Compose Lifecycle Test (Verifies Network Persistence) ==="
echo "Testing: n8n service definition with dual networks survives recreation"
echo ""

# Cleanup function
cleanup() {
    echo "Cleaning up..."
    docker compose -p "$PROJECT" -f "$COMPOSE_FILE" down -v --remove-orphans 2>/dev/null || true
}
trap cleanup EXIT

# Start fresh
cleanup 2>/dev/null || true

echo "1. Starting services with Compose..."
docker compose -p "$PROJECT" -f "$COMPOSE_FILE" up -d --quiet-pull
sleep 5

echo "   ✓ Services started"
echo ""

# Verify networks from Compose definition
echo "2. Inspecting network membership from Compose definition..."
RUNTIME_NETS=$(docker inspect test-n8n-compose-sim -f '{{range $k, $v := .NetworkSettings.Networks}}{{$k}}{{"\n"}}{{end}}' 2>/dev/null | sort | tr -d '\r')
echo "   Runtime networks:"
echo "$RUNTIME_NETS" | sed 's/^/     /'

if echo "$RUNTIME_NETS" | grep -q "app_default" && echo "$RUNTIME_NETS" | grep -q "_n8n"; then
    echo "   ✓ Both networks attached at runtime"
else
    echo "   ✗ Expected both networks, got: $RUNTIME_NETS"
    exit 1
fi
echo ""

# Record container ID before recreation
ID_BEFORE=$(docker ps -q -f "name=test-n8n-compose-sim")
echo "3. Container ID before: ${ID_BEFORE:0:12}"
echo ""

# Recreate ONLY n8n-sim service (simulates production: docker compose up -d n8n)
echo "4. Recreating n8n-sim service via Compose..."
docker compose -p "$PROJECT" -f "$COMPOSE_FILE" up -d "$SERVICE" --force-recreate --no-build
sleep 3

ID_AFTER=$(docker ps -q -f "name=test-n8n-compose-sim")
echo "   Container ID after: ${ID_AFTER:0:12}"

if [ "$ID_BEFORE" != "$ID_AFTER" ]; then
    echo "   ✓ Container was recreated (new ID)"
else
    echo "   ✗ Container was NOT recreated"
    exit 1
fi
echo ""

# Verify networks persist after recreation
echo "5. Verifying network membership AFTER recreation..."
RUNTIME_NETS_AFTER=$(docker inspect test-n8n-compose-sim -f '{{range $k, $v := .NetworkSettings.Networks}}{{$k}}{{"\n"}}{{end}}' 2>/dev/null | sort | tr -d '\r')
echo "   Runtime networks after recreation:"
echo "$RUNTIME_NETS_AFTER" | sed 's/^/     /'

if echo "$RUNTIME_NETS_AFTER" | grep -q "app_default" && echo "$RUNTIME_NETS_AFTER" | grep -q "_n8n"; then
    echo "   ✓ Both networks persist after recreation"
else
    echo "   ✗ Networks lost after recreation"
    exit 1
fi
echo ""

# Test cross-network connectivity
echo "6. Testing cross-network DNS resolution (n8n-sim → app-postgres-compose)..."
set +e
DNS_RESULT=$(docker exec test-n8n-compose-sim sh -c "
    node -e \"require('dns').lookup('test-app-postgres-compose',(e,a)=>console.log(e?'FAIL '+e.code:'OK '+a))\"
" 2>&1)
set -e

if echo "$DNS_RESULT" | grep -q "OK"; then
    echo "   ✓ DNS resolves: $DNS_RESULT"
else
    echo "   ✗ DNS failed: $DNS_RESULT"
    exit 1
fi
echo ""

echo "7. Final network configuration verification..."
docker inspect test-n8n-compose-sim -f '{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}' 2>/dev/null
echo ""

echo "=== SUMMARY ==="
echo "✓ Compose file defines dual-network n8n-sim service"
echo "✓ Container recreation via 'docker compose up -d n8n-sim' preserves network membership"
echo "✓ Network configuration is read from Compose file, not stored in container state"
echo ""
echo "TESTED: Compose definition → runtime → recreate → verify persistence"
echo "CONCLUSION: Network membership survives 'docker compose up -d <service>' recreation"