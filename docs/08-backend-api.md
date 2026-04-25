---
name: 08-backend-api
description: REST API contracts — endpoints, JSON schemas, auth, idempotency, error taxonomy
owner: Backend
status: ready
depends-on: [01-architecture, 03-token-protocol, 09-data-model]
last-updated: 2026-04-25
---

# Backend API

All public endpoints are served from **Alibaba API Gateway → Function Compute**.
A subset (settlement bridge ingest + dispute) reaches AWS Lambda asynchronously.

- **Base URL (demo):** `https://api-finhack.example.com`
- **API version prefix:** `/v1`
- **Auth:** Cognito-issued JWT, `Authorization: Bearer <token>`. JWKS at
  `https://cognito-idp.<region>.amazonaws.com/<pool>/.well-known/jwks.json`.
- **Content-Type:** `application/json; charset=utf-8`.
- **OpenAPI spec:** `backend/openapi.yaml` (to be generated from this doc).
- **Idempotency:** every state-mutating endpoint accepts `Idempotency-Key` header
  (UUIDv4 recommended). Server stores `(key, hash(body))` for 24h.
- **Tracing:** `X-Request-Id` echoed; auto-generated if absent.

## 1. Endpoint inventory

| Method | Path | Auth | Purpose |
|---|---|---|---|
| POST | `/v1/devices/register` | JWT | Register device pubkey + attestation |
| POST | `/v1/devices/attest` | JWT | Submit fresh attestation |
| GET  | `/v1/wallet/balance` | JWT | Authoritative balance + version |
| POST | `/v1/wallet/sync` | JWT | Apply queued reloads, return latest balance |
| POST | `/v1/tokens/settle` | JWT | Submit batch of JWS for settlement |
| POST | `/v1/tokens/dispute` | JWT | Open dispute on a settled token |
| POST | `/v1/score/refresh` | JWT | Get fresh safe-offline-balance |
| GET  | `/v1/score/policy` | JWT | Latest active policy + signed model URL |
| GET  | `/v1/publickeys/{kid}` | JWT | Resolve a device's public key |
| POST | `/v1/merchants/onboard` | JWT (admin) | Stub merchant onboarding |
| POST | `/v1/_internal/eb/aws-bridge` | mTLS | AWS → Alibaba cross-cloud webhook |

## 2. Common error envelope

```json
{
  "error": {
    "code": "NONCE_REUSED",
    "message": "This nonce has already been settled",
    "request_id": "req_01HW3..."
  }
}
```

Codes: `BAD_REQUEST`, `UNAUTHENTICATED`, `FORBIDDEN`, `NOT_FOUND`, `CONFLICT`,
`NONCE_REUSED`, `EXPIRED_TOKEN`, `BAD_SIGNATURE`, `RECEIVER_MISMATCH`,
`UNKNOWN_KID`, `RATE_LIMITED`, `INTERNAL`.

HTTP status mapping: 400 / 401 / 403 / 404 / 409 / 422 / 429 / 500.

## 3. Endpoint specs

### 3.1 `POST /v1/devices/register`

Register a new device public key. Idempotent on `Idempotency-Key`.

Request:
```json
{
  "user_id": "u_8412",
  "device_label": "Pixel 8",
  "public_key": "BASE64URL(32 bytes Ed25519 pub)",
  "attestation_chain": [
    "BASE64(cert0)", "BASE64(cert1)", "BASE64(cert2)"
  ],
  "alg": "EdDSA",
  "android_id_hash": "sha256(...)"
}
```

Response 200:
```json
{
  "device_id": "did:tng:device:01HW3YKQ8X2A5FR7JM6T1EE9NP",
  "kid": "01HW3YKQ8X2A5FR7JM6T1EE9NP",
  "policy_version": "v3.2026-04-22",
  "initial_safe_offline_balance_myr": "50.00",
  "registered_at": "2026-04-25T10:14:32Z"
}
```

Errors: `ATTESTATION_INVALID` (422), `DEVICE_LIMIT_REACHED` (409 — max 3 devices/user).

Server side: writes to Tablestore `devices`, copies pubkey to Alibaba OSS
`tng-finhack-pubkeys/{kid}.pem`, fans out to AWS DynamoDB `tng_pubkey_cache` via
warmer.

### 3.2 `POST /v1/devices/attest`

Refresh attestation (e.g., after OS upgrade). Same shape, returns `kid` and
`attest_valid_until`.

### 3.3 `GET /v1/wallet/balance`

Response 200:
```json
{
  "user_id": "u_8412",
  "balance_myr": "248.50",
  "currency": "MYR",
  "version": 4321,
  "as_of": "2026-04-25T10:14:32Z",
  "safe_offline_balance_myr": "120.00",
  "policy_version": "v3.2026-04-22"
}
```

`safe_offline_balance_myr` here is the *server-side* number from PAI-EAS, returned for
convenience so a freshly-online client doesn't need a second call.

### 3.4 `POST /v1/wallet/sync`

Idempotent. Accepts pending reload references (e.g., bank top-up that just cleared)
and returns the post-sync balance.

Request:
```json
{
  "user_id": "u_8412",
  "since_version": 4319
}
```

Response 200: same shape as `GET /v1/wallet/balance` plus a `delta_events` array.

### 3.5 `POST /v1/tokens/settle`

The core settlement endpoint. Accepts up to **50 tokens** per call.

Request:
```json
{
  "device_id": "did:tng:device:01HW3...",
  "batch_id": "01HW4ABCD...",
  "tokens": [
    "<JWS string 1>",
    "<JWS string 2>",
    "..."
  ]
}
```

Response 200:
```json
{
  "batch_id": "01HW4ABCD...",
  "results": [
    {"tx_id": "01HW3...", "status": "SETTLED", "settled_at": "2026-04-25T10:18:01Z"},
    {"tx_id": "01HW3...", "status": "REJECTED", "reason": "NONCE_REUSED"}
  ]
}
```

Behavior:
1. FC validates JSON shape + JWT.
2. FC writes `pending_batches` row in Tablestore.
3. FC emits Alibaba EventBridge `tokens.settle.requested`.
4. Alibaba EB → cross-cloud webhook → AWS EB → Lambda `settle-batch`.
5. Lambda processes per [docs/05-aws-services.md §4.1](05-aws-services.md).
6. Lambda emits `settlement.completed` → cross-cloud → Alibaba FC → updates Tablestore
   wallet, RDS history, pushes user.
7. FC poll-or-wait pattern for the original HTTP response: function uses a 2-step:
   - Synchronous path waits up to 1500ms on the bridge for results.
   - If timeout, returns `202 Accepted` with batch_id; client polls
     `GET /v1/tokens/settle/{batch_id}` (added separately).

For the demo with low latency we keep the synchronous path; the polling path is in
the API but not used live.

### 3.6 `POST /v1/tokens/dispute`

Request:
```json
{
  "tx_id": "01HW3...",
  "reason_code": "WRONG_AMOUNT",
  "details": "Claimed RM 8.50, vendor charged me twice"
}
```

Response 201:
```json
{
  "dispute_id": "dsp_01HW...",
  "status": "RECEIVED"
}
```

`reason_code` ∈ {`UNAUTHORIZED`, `WRONG_AMOUNT`, `NOT_RECEIVED`, `OTHER`}.

Server writes to Alibaba RDS `disputes` and DynamoDB `token_ledger` (status →
DISPUTED) via cross-cloud event.

### 3.7 `POST /v1/score/refresh`

Request (features inline so PAI-EAS doesn't need to fetch):
```json
{
  "user_id": "u_8412",
  "policy_version": "v3.2026-04-22",
  "features": {
    "tx_count_30d": 38,
    "tx_count_90d": 92,
    "avg_tx_amount_30d": 7.40,
    "median_tx_amount_30d": 5.00,
    "tx_amount_p95_30d": 30.00,
    "unique_payees_30d": 17,
    "unique_payees_90d": 36,
    "payee_diversity_idx": 2.91,
    "reload_freq_30d": 4,
    "reload_amount_avg": 50.00,
    "days_since_last_reload": 3,
    "time_of_day_primary": 12,
    "weekday_share": 0.78,
    "geo_dispersion_km": 6.2,
    "prior_offline_count": 11,
    "prior_offline_settle_rate": 1.0,
    "account_age_days": 421,
    "kyc_tier": 1,
    "last_sync_age_min": 0,
    "device_attest_ok": 1
  }
}
```

Response 200:
```json
{
  "safe_offline_balance_myr": "120.00",
  "confidence": 0.87,
  "policy_version": "v3.2026-04-22",
  "computed_at": "2026-04-25T10:14:32Z"
}
```

Timeout policy: 800 ms. On 5xx/timeout, client falls back to on-device estimate.

### 3.8 `GET /v1/score/policy`

Response 200:
```json
{
  "policy_version": "v3.2026-04-22",
  "released_at": "2026-04-22T08:00:00Z",
  "model": {
    "format": "tflite",
    "url": "https://oss-ap-southeast-3.aliyuncs.com/...?Signature=...",
    "sha256": "9f1c...",
    "sigstore_signature": "MEUCIQDx..."
  },
  "limits": {
    "hard_cap_per_tier": {"0": "20.00", "1": "150.00", "2": "500.00"},
    "global_cap_per_token_myr": "250.00",
    "max_token_validity_hours": 72
  }
}
```

### 3.9 `GET /v1/publickeys/{kid}`

Response 200:
```json
{
  "kid": "01HW3YKQ8X2A5FR7JM6T1EE9NP",
  "alg": "EdDSA",
  "public_key": "BASE64URL(32 bytes)",
  "status": "ACTIVE",
  "registered_at": "2026-04-10T11:00:00Z",
  "revoked_at": null
}
```

Used during NFC offline pay if the receiver doesn't yet have the sender's pubkey
cached — fetched on next online window. Optional during settlement (server has its
own cache).

### 3.10 `POST /v1/merchants/onboard`

Stub for the demo. Accepts `{merchant_name, business_id, contact}`. Returns
`{merchant_id}`.

### 3.11 `POST /v1/_internal/eb/aws-bridge`

Internal endpoint, mTLS-auth. Accepts EventBridge-formatted events from AWS Lambda
`eb-cross-cloud-bridge-out`. Body:
```json
{
  "version": "0",
  "id": "...",
  "detail-type": "settlement.completed",
  "source": "tng.aws.lambda.settle",
  "time": "2026-04-25T10:18:01Z",
  "detail": {
    "batch_id": "01HW4...",
    "results": [...]
  }
}
```

## 4. Versioning policy

- `/v1` is the demo version. Breaking changes go to `/v2`.
- Additive changes (new optional fields) within `/v1` are allowed.
- Each response includes `X-API-Version: v1` header.

## 5. Rate limits

- Per-user: 60 rpm overall, 10 rpm for `/score/refresh`.
- Per-IP: 600 rpm.
- Returns `429` with `Retry-After` seconds.

## 6. Pagination (history endpoints — future)

Not in MVP, but reserved query params: `?cursor=`, `?limit=` for `GET /v1/history`.

## 7. OpenAPI snippet (excerpt for `tokens/settle`)

```yaml
paths:
  /v1/tokens/settle:
    post:
      summary: Submit batch of signed JWS tokens for settlement
      parameters:
        - in: header
          name: Idempotency-Key
          required: true
          schema: { type: string, format: uuid }
      requestBody:
        required: true
        content:
          application/json:
            schema: { $ref: '#/components/schemas/SettleBatchRequest' }
      responses:
        '200':
          description: Settled or rejected per-token
          content:
            application/json:
              schema: { $ref: '#/components/schemas/SettleBatchResponse' }
        '202':
          description: Accepted — poll for results
        '400': { $ref: '#/components/responses/BadRequest' }
        '401': { $ref: '#/components/responses/Unauthenticated' }
        '429': { $ref: '#/components/responses/RateLimited' }
```

Full schema lives in `backend/openapi.yaml` to be authored by the Backend agent.
