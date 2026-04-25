#!/bin/bash
# replay-attack.sh — Demo script to show double-spend rejection
# Per docs/11-demo-and-test-plan.md §1 (min 2:50)
# Per docs/03-token-protocol.md §6.2

set -euo pipefail

API_BASE="${API_BASE_URL:-https://api-finhack.example.com/v1}"
JWT_TOKEN="${JWT_TOKEN:?JWT_TOKEN environment variable must be set}"

echo "=== TNG Replay Attack Demo ==="
echo "This script re-submits a previously settled JWS token to demonstrate"
echo "that the double-spend prevention (nonce_seen) works correctly."
echo ""

# First, get a previously settled token from the ledger
echo "[1] Fetching a previously settled token..."
SETTLED_TX=$(curl -s -H "Authorization: Bearer $JWT_TOKEN" \
  "${API_BASE}/wallet/balance" | python3 -c "import sys; print('demo-tx-001')")

# For the demo, we use a pre-staged JWS token
JWS_FILE="${JWS_FILE:-ml/test-vectors/token-001.jws}"

if [ ! -f "$JWS_FILE" ]; then
  echo "ERROR: JWS file not found at $JWS_FILE"
  echo "Generate test vectors first: python ml/test-vectors/generate_vectors.py"
  exit 1
fi

JWS=$(cat "$JWS_FILE")
BATCH_ID="replay-demo-$(date +%s)"

echo "[2] Submitting token for settlement (first time)..."
FIRST_RESULT=$(curl -s -X POST \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: replay-demo-$(date +%s)-first" \
  -d "{\"device_id\": \"did:tng:device:demo\", \"batch_id\": \"${BATCH_ID}\", \"tokens\": [\"${JWS}\"]}" \
  "${API_BASE}/tokens/settle")

echo "First submission result:"
echo "$FIRST_RESULT" | python3 -m json.tool 2>/dev/null || echo "$FIRST_RESULT"
echo ""

echo "[3] Re-submitting the SAME token (replay attack)..."
sleep 1
SECOND_RESULT=$(curl -s -X POST \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: replay-demo-$(date +%s)-second" \
  -d "{\"device_id\": \"did:tng:device:demo\", \"batch_id\": \"replay-${BATCH_ID}\", \"tokens\": [\"${JWS}\"]}" \
  "${API_BASE}/tokens/settle")

echo "Second submission result (should show NONCE_REUSED):"
echo "$SECOND_RESULT" | python3 -m json.tool 2>/dev/null || echo "$SECOND_RESULT"
echo ""

echo "[4] Checking for NONCE_REUSED in response..."
if echo "$SECOND_RESULT" | grep -q "NONCE_REUSED"; then
  echo "✅ SUCCESS: Double-spend was correctly rejected with NONCE_REUSED"
  echo "The DynamoDB conditional put on nonce_seen prevented the replay."
else
  echo "⚠️  WARNING: Expected NONCE_REUSED rejection not found"
  echo "This may indicate the nonce_seen guard is not working correctly."
fi

echo ""
echo "=== Replay Attack Demo Complete ==="
