#!/bin/bash
# Seed demo users (Faiz + Aida) for the hackathon demo
# Per docs/11-demo-and-test-plan.md §2

set -e

API_BASE="${API_BASE_URL:-http://localhost:3000/v1}"

echo "=== Seeding Demo Users ==="

# Faiz (sender) — Grab rider on prepaid data
echo "Creating Faiz (sender)..."
curl -s -X POST "$API_BASE/devices/register" \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "u_faiz",
    "device_label": "Pixel 8 - Faiz",
    "public_key": "DEMO_FAIZ_PUB_KEY_PLACEHOLDER",
    "attestation_chain": [],
    "alg": "EdDSA",
    "android_id_hash": "sha256:faiz_device"
  }' | jq .

# Aida (receiver) — Hawker stall owner
echo "Creating Aida (receiver)..."
curl -s -X POST "$API_BASE/devices/register" \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "u_aida",
    "device_label": "Pixel 8 - Aida",
    "public_key": "DEMO_AIDA_PUB_KEY_PLACEHOLDER",
    "attestation_chain": [],
    "alg": "EdDSA",
    "android_id_hash": "sha256:aida_device"
  }' | jq .

echo "=== Demo users seeded ==="
