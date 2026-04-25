---
name: 09-data-model
description: All datastore schemas — Tablestore, DynamoDB, ApsaraDB RDS, S3, OSS — with key designs, GSIs, TTLs
owner: Data
status: ready
depends-on: [01-architecture, 03-token-protocol, 05-aws-services, 06-alibaba-services]
last-updated: 2026-04-25
---

# Data Model

A single source of truth for every persistent store. **Each piece of state lives in
exactly one authoritative store**; caches are explicit.

| Authoritative store | Lives in | Owns |
|---|---|---|
| Wallet balance | Alibaba Tablestore `wallets` | live balance |
| Token ledger | AWS DynamoDB `tng_token_ledger` | settled & rejected tokens |
| Settled history | Alibaba RDS `settled_transactions` | OLTP-friendly view of settled |
| Public keys | Alibaba OSS + Tablestore `devices` | source of truth for device keys |
| User profile | Alibaba Tablestore `users` | identity + KYC |
| Synthetic data | AWS S3 | training corpus |
| Model artifacts | AWS S3 (origin) + Alibaba OSS (mirror) | TF Lite + XGBoost binaries |

## 1. Alibaba Tablestore tables

Instance: `tng-finhack-ots`. CapacityMode: reserved for demo (200 R/W).

### 1.1 `users`
| Column | Type | PK | Notes |
|---|---|---|---|
| `user_id` | STRING | PK | `u_8412` |
| `phone_e164` | STRING | | `+60123456789` |
| `display_name` | STRING | | |
| `kyc_tier` | INTEGER | | `0`/`1`/`2` |
| `signup_at` | INTEGER (unix s) | | |
| `home_region` | STRING | | `MY-WP` |
| `lifetime_tx_count` | INTEGER | | drives 600-tx segment |

### 1.2 `devices`
| Column | Type | PK | Notes |
|---|---|---|---|
| `device_id` (kid) | STRING | PK | UUIDv7 |
| `user_id` | STRING | | indexed |
| `pub_key_b64` | STRING | | Ed25519 32-byte raw, base64url |
| `alg` | STRING | | `EdDSA`/`ES256` |
| `attestation_sha256` | STRING | | sha256 of cert chain |
| `status` | STRING | | `ACTIVE`/`REVOKED`/`PENDING` |
| `registered_at` | INTEGER | | |
| `revoked_at` | INTEGER | nullable | |
| `last_seen_at` | INTEGER | | |

Secondary index: `devices_by_user` → `(user_id, registered_at desc)`.

### 1.3 `wallets`
| Column | Type | PK | Notes |
|---|---|---|---|
| `user_id` | STRING | PK | |
| `balance_cents` | INTEGER | | atomic via OTS conditional update |
| `currency` | STRING | | `MYR` |
| `version` | INTEGER | | optimistic CAS |
| `updated_at` | INTEGER | | |

Updates always conditional on `version == @expected`.

### 1.4 `offline_balance_cache`
| Column | Type | PK | Notes |
|---|---|---|---|
| `user_id` | STRING | PK1 | |
| `device_id` | STRING | PK2 | |
| `safe_offline_cents` | INTEGER | | server-side cached estimate |
| `policy_version` | STRING | | |
| `confidence` | DOUBLE | | |
| `computed_at` | INTEGER | | |
| TTL | | | 30 minutes |

### 1.5 `pending_tokens_inbox`
Optimistic view of unsettled tokens pulled from the AWS ledger via cross-cloud
event. Used for fast "pending notifications" UX.
| Column | Type | PK | Notes |
|---|---|---|---|
| `user_id` | STRING | PK1 | |
| `received_at` | INTEGER | PK2 | desc-sorted with timestamp |
| `tx_id` | STRING | | |
| `amount_cents` | INTEGER | | |
| `counterparty_kid` | STRING | | |
| `direction` | STRING | | `IN` / `OUT` |
| `status` | STRING | | `PENDING`/`SETTLED`/`REJECTED` |

### 1.6 `policy_versions`
| Column | Type | PK | Notes |
|---|---|---|---|
| `policy_id` | STRING | PK | `v3.2026-04-22` |
| `model_url` | STRING | | OSS path |
| `model_sha256` | STRING | | |
| `released_at` | INTEGER | | |
| `active` | BOOLEAN | | |
| `hard_caps_json` | STRING | | per-tier caps |

## 2. AWS DynamoDB tables

All on-demand billing; PITR on `tng_token_ledger`.

### 2.1 `tng_token_ledger`
| Attr | Type | Key | Notes |
|---|---|---|---|
| `tx_id` | S | PK | UUIDv7 |
| `kid` | S | | sender's kid |
| `iat` | N | | unix s |
| `nonce` | S | | dup-detection |
| `amount_cents` | N | | |
| `currency` | S | | `MYR` |
| `sender_user_id` | S | | |
| `receiver_user_id` | S | | |
| `status` | S | | `SETTLED`/`REJECTED`/`DISPUTED` |
| `reject_reason` | S | nullable | |
| `settled_at` | N | nullable | |
| `policy_version` | S | | |
| `jws` | B | | full token bytes (audit) |

GSI: `kid-iat-index` (PK `kid`, SK `iat`) for per-device queries.
GSI: `sender-iat-index` (PK `sender_user_id`, SK `iat`) for per-user history.

### 2.2 `tng_nonce_seen`
| Attr | Type | Key | Notes |
|---|---|---|---|
| `nonce` | S | PK | |
| `tx_id` | S | | |
| `ttl` | N | | `iat + 90d` |

Conditional put on `attribute_not_exists(nonce)` is the heart of double-spend
prevention. TTL purges old nonces (90d > max validity by 30x).

### 2.3 `tng_idempotency`
| Attr | Type | Key | Notes |
|---|---|---|---|
| `key` | S | PK | client-provided UUIDv4 |
| `body_hash` | S | | sha256 of request body |
| `response_json` | S | | full response cached |
| `ttl` | N | | `now + 24h` |

### 2.4 `tng_pubkey_cache`
| Attr | Type | Key | Notes |
|---|---|---|---|
| `kid` | S | PK | |
| `alg` | S | | |
| `pub_b64` | S | | |
| `status` | S | | `ACTIVE`/`REVOKED` |
| `ttl` | N | | refreshed by warmer Lambda every 7d |

## 3. Alibaba ApsaraDB RDS — MySQL 8.0

Database: `tng_history`. Charset `utf8mb4`. InnoDB.

### 3.1 `settled_transactions`
```sql
CREATE TABLE settled_transactions (
  tx_id           CHAR(26) PRIMARY KEY,        -- UUIDv7
  sender_user_id  VARCHAR(64) NOT NULL,
  receiver_user_id VARCHAR(64) NOT NULL,
  amount_cents    BIGINT NOT NULL,
  currency        CHAR(3) NOT NULL DEFAULT 'MYR',
  iat             INT UNSIGNED NOT NULL,
  settled_at      DATETIME NOT NULL,
  policy_version  VARCHAR(32) NOT NULL,
  status          ENUM('SETTLED','DISPUTED','REVERSED') NOT NULL DEFAULT 'SETTLED',
  INDEX idx_sender (sender_user_id, settled_at),
  INDEX idx_receiver (receiver_user_id, settled_at),
  INDEX idx_settled (settled_at)
) ENGINE=InnoDB;
```

### 3.2 `merchants`
```sql
CREATE TABLE merchants (
  merchant_id     CHAR(26) PRIMARY KEY,
  business_name   VARCHAR(200) NOT NULL,
  business_id     VARCHAR(64),
  user_id         VARCHAR(64) NOT NULL,
  onboarded_at    DATETIME NOT NULL,
  status          ENUM('ACTIVE','SUSPENDED') DEFAULT 'ACTIVE',
  UNIQUE KEY uniq_user (user_id)
) ENGINE=InnoDB;
```

### 3.3 `kyc_records`
```sql
CREATE TABLE kyc_records (
  user_id         VARCHAR(64) PRIMARY KEY,
  tier            TINYINT NOT NULL DEFAULT 0,
  full_name       VARCHAR(200),
  ic_last4        CHAR(4),
  doc_ref         VARCHAR(64),
  verified_at     DATETIME
) ENGINE=InnoDB;
```

### 3.4 `disputes`
```sql
CREATE TABLE disputes (
  dispute_id      CHAR(26) PRIMARY KEY,
  tx_id           CHAR(26) NOT NULL,
  reason_code     ENUM('UNAUTHORIZED','WRONG_AMOUNT','NOT_RECEIVED','OTHER') NOT NULL,
  details         TEXT,
  status          ENUM('RECEIVED','UNDER_REVIEW','RESOLVED','REJECTED') NOT NULL DEFAULT 'RECEIVED',
  raised_by       VARCHAR(64) NOT NULL,
  raised_at       DATETIME NOT NULL,
  resolved_at     DATETIME,
  INDEX idx_tx (tx_id)
) ENGINE=InnoDB;
```

## 4. S3 bucket layouts (AWS)

### `tng-finhack-aws-data`
```
synthetic/
  v1/
    users.parquet
    transactions.parquet
feature-store/
  v1/
    train/
    eval/
```

### `tng-finhack-aws-models`
```
models/
  credit/
    v1/
      model.tar.gz       # SageMaker output
      model.pkl          # raw XGBoost
      model.tflite       # converted
      model.json         # manifest (sha256, sigstore sig, schema_version)
    v2/...
```

### `tng-finhack-aws-logs`
```
settle/<yyyy>/<mm>/<dd>/<batch_id>.json
```

## 5. OSS bucket layouts (Alibaba)

### `tng-finhack-models`
```
credit/
  v1/
    model.tflite
    model.json
    score_card.json      # human-readable: features, calibration, RMSE
```

### `tng-finhack-pubkeys`
```
{kid}.pem
```
Each is a raw Ed25519 pubkey wrapped in PEM for compatibility. Read via signed URL
issued by FC `GET /v1/publickeys/{kid}`.

### `tng-finhack-static`
```
static/
  splash.webp
  terms.md
  privacy.md
```

## 6. Data residency & retention

| Data class | Region | Retention |
|---|---|---|
| User PII | Alibaba KL (RDS + Tablestore) | 7 years (regulatory placeholder) |
| Wallet balance | Alibaba KL (Tablestore) | live |
| Token ledger | AWS Singapore (DynamoDB) | live + 7y archive to S3 Glacier |
| Synthetic training data | AWS Singapore (S3) | demo only |
| Model artifacts | AWS S3 + OSS | last 5 versions |
| Logs | both clouds | 14d hot, 90d cold |
| Disputes | Alibaba RDS | 7y |

PII never leaves Alibaba's APAC residency. AWS sees only `user_id` + transaction
amounts + crypto blobs (no PII directly).

## 7. Migrations / DDL changes

Every schema change must:
1. Be additive within a major version.
2. Include a migration script under `infra/migrations/<yyyy-mm-dd>-<slug>.sql` (RDS)
   or `infra/migrations/<yyyy-mm-dd>-<slug>.ts` (Tablestore/DynamoDB).
3. Be reflected here.

## 8. Hot-path access patterns (for index design verification)

| Pattern | Store | Index used |
|---|---|---|
| "Get my balance now" | Tablestore `wallets` | PK `user_id` |
| "Settle this batch" | DynamoDB `tng_token_ledger` | PK `tx_id`; conditional via `tng_nonce_seen` |
| "List my pending tokens" | Tablestore `pending_tokens_inbox` | PK1 `user_id`, range `received_at` desc |
| "Verify signature" | DynamoDB `tng_pubkey_cache` | PK `kid` (warm); fall back to OSS via FC |
| "Get my history" | RDS `settled_transactions` | `idx_sender` / `idx_receiver` |
| "List my devices" | Tablestore `devices` (sec idx by user) | `(user_id, registered_at desc)` |
| "Open a dispute" | RDS `disputes` | PK `dispute_id`, `idx_tx` |
| "Find duplicate nonce" | DynamoDB `tng_nonce_seen` | PK `nonce` (conditional put) |

## 9. Backups

- Tablestore: continuous backup; on-demand snapshots before policy bumps.
- DynamoDB: PITR + on-demand snapshots before each demo.
- RDS: daily automated, 7d retention; manual snapshot before each demo.
- S3 / OSS: versioning enabled on `models/`.
