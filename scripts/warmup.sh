#!/bin/bash
# Pre-warm PAI-EAS endpoint and AWS Lambda for demo
# Per docs/11-demo-and-test-plan.md §2

set -e

API_BASE="${API_BASE_URL:-http://localhost:3000/v1}"

echo "=== Warming up services ==="

# Warm PAI-EAS score endpoint
echo "Warming PAI-EAS..."
curl -s -X POST "$API_BASE/score/refresh" \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "u_faiz",
    "policy_version": "v3.2026-04-22",
    "features": {
      "tx_count_30d": 38,
      "tx_count_90d": 92,
      "avg_tx_amount_30d": 7.40,
      "last_sync_age_min": 0,
      "kyc_tier": 1,
      "account_age_days": 421,
      "device_attest_ok": 1
    }
  }' > /dev/null 2>&1 && echo "  PAI-EAS warm" || echo "  PAI-EAS warm failed (expected if not deployed)"

# Warm Lambda settle with empty batch
echo "Warming Lambda settle..."
curl -s -X POST "$API_BASE/tokens/settle" \
  -H "Content-Type: application/json" \
  -d '{
    "device_id": "warmup",
    "batch_id": "warmup-batch",
    "tokens": []
  }' > /dev/null 2>&1 && echo "  Lambda warm" || echo "  Lambda warm failed (expected if not deployed)"

echo "=== Warmup complete ==="
