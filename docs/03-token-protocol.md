---
name: 03-token-protocol
description: JWS token schema, Ed25519 signing rules, NFC APDU exchange, replay and double-spend defenses
owner: Security
status: ready
depends-on: [00-overview, 01-architecture]
last-updated: 2026-04-25
---

# Token Protocol

## 1. Goals

1. **Authenticity** — only the legitimate sender device could have produced a token.
2. **Integrity** — amount/recipient cannot be modified post-signing.
3. **Non-repudiation** — sender cannot later deny signing.
4. **Replay resistance** — a token cannot settle twice (no double-spend).
5. **Bounded validity** — tokens expire so server-side state is bounded.
6. **Offline verifiability** — receiver, if it has the sender's public key, can validate
   without server.

## 2. Choice of crypto

- **Ed25519** signatures (RFC 8032). 64-byte signatures, ~30µs sign/verify on modern
  Android, deterministic, no nonce reuse pitfalls. Key generated and held in **Android
  Keystore**, hardware-backed where available (StrongBox or TEE).
- **JWS Compact Serialization** (RFC 7515) for the wire format. Familiar, compact, easy
  to debug, supported by most server-side libs.

## 3. Token format (JWS)

A compact JWS: `BASE64URL(header) + "." + BASE64URL(payload) + "." + BASE64URL(sig)`.

### 3.1 Header
```json
{
  "alg": "EdDSA",
  "typ": "tng-offline-tx+jws",
  "kid": "did:tng:device:01HW3YKQ8X2A5FR7JM6T1EE9NP",
  "policy": "v3.2026-04-22",
  "ver": 1
}
```

| Field | Required | Notes |
|---|---|---|
| `alg` | yes | Must be `EdDSA` |
| `typ` | yes | Must be `tng-offline-tx+jws` |
| `kid` | yes | Stable device key id; opaque to mobile, looked up server-side |
| `policy` | yes | Score-policy version under which sender derived their safe-offline balance |
| `ver` | yes | Schema version, currently `1` |

### 3.2 Payload
```json
{
  "tx_id": "01HW3YKQ8X2A5FR7JM6T1EE9NP",
  "sender": {
    "kid": "did:tng:device:01HW3...",
    "user_id": "u_8412",
    "pub": "BASE64URL(32 bytes)"
  },
  "receiver": {
    "kid": "did:tng:device:01HW4...",
    "user_id": "u_3091",
    "pub": "BASE64URL(32 bytes)"
  },
  "amount": {
    "value": "8.50",
    "currency": "MYR",
    "scale": 2
  },
  "nonce": "BASE64URL(16 random bytes)",
  "iat": 1745603421,
  "exp": 1745862621,
  "geo": { "lat": 3.139, "lon": 101.687, "acc_m": 50 },
  "device_attest": "BASE64URL(android-keystore-attest-cert-chain-sha256)",
  "policy_signed_balance": "120.00"
}
```

| Field | Required | Notes |
|---|---|---|
| `tx_id` | yes | UUIDv7 — time-ordered for ledger sharding |
| `sender.pub` | yes | Raw Ed25519 public key (32 bytes); allows offline verify by receiver |
| `receiver.pub` | yes | Pinned at signing time so token isn't reusable for a different receiver |
| `amount.value` | yes | Decimal string; `scale` indicates fractional digits |
| `nonce` | yes | 128 bits of CSPRNG; used by ledger for idempotency |
| `iat` | yes | Unix seconds at signing |
| `exp` | yes | Default `iat + 72h`; configurable by server policy |
| `geo` | optional | Best-effort location for fraud heuristics |
| `device_attest` | yes (in tier-2) | SHA-256 of Android Key Attestation chain |
| `policy_signed_balance` | yes | Sender's claimed safe-offline at signing — auditable post-hoc |

### 3.3 Signature
- Computed over `BASE64URL(header) + "." + BASE64URL(payload)`.
- Algorithm = Ed25519 over UTF-8 bytes.
- Result is the standard 64-byte Ed25519 signature, BASE64URL'd.

### 3.4 Size budget

| Component | Bytes |
|---|---|
| Header | ~140 |
| Payload (typical) | ~480 |
| Signature | 88 |
| **Total compact JWS** | ~720 bytes |

Fits comfortably in NFC APDU multi-frame transfer (1–2 chunks).

## 4. Key management on device

| Lifecycle stage | Action |
|---|---|
| Generate | At onboarding, `KeyGenParameterSpec` Ed25519 key, alias = `tng_signing_v1`, `setUserAuthenticationRequired(true)` for sensitive ops, `setIsStrongBoxBacked(true)` if available, attestation challenge from server |
| Register | Send pub + attestation cert chain to `POST /devices/register`; server verifies chain rooted at Google attestation root |
| Use | Each sign requires biometric/PIN unlock (skipped for amounts ≤ RM 5 to keep tap UX fast) |
| Rotate | Server can request rotation; app generates new key, registers, retains old for 30d to settle in-flight tokens |
| Revoke | Server marks `kid` revoked; settlement of new tokens with that kid fails after revocation timestamp; pre-revocation tokens still settle (proof was valid at sign time) |

Reference Flutter package: `cryptography: ^2.7.0` for Ed25519 logic, with a thin Kotlin
platform channel that delegates the actual private-key operations to Keystore.
`flutter_secure_storage` for non-key secrets only — never holds the Ed25519 private key.

## 5. NFC APDU exchange

### 5.1 Application IDs

**Canonical AID** (single source of truth — every component must use this exact value):

```
AID = F0544E47504159   (7 bytes; "F0" + ASCII "TNGPAY")
```

- Sender (reader mode) sends `SELECT` with this AID.
- Receiver HCE service registers with this AID in `apduservice.xml` (see
  [docs/07-mobile-app.md §4](07-mobile-app.md)).
- Apps switch role by which screen the user opens (Pay vs Receive); the AID is the same.

### 5.2 Sequence (sender → receiver)

```
                Sender                           Receiver (HCE)
                  │                                    │
                  │ ─── SELECT AID F0544E47504159 ──>  │
                  │ <─── 9000 + receiver_pub (32B) ── │
                  │                                    │
                  │ ─── PUT-DATA chunk 0/N (256B) ──> │
                  │ ─── PUT-DATA chunk 1/N ────────── │
                  │ ─── PUT-DATA chunk N/N ────────── │
                  │ <─── 9000 + ack-signature ─────── │
                  │                                    │
                  ▼                                    ▼
            outbox: PENDING                       inbox: PENDING
```

### 5.3 APDUs in detail

| APDU | C-APDU | R-APDU |
|---|---|---|
| Select AID | `00 A4 04 00 07 F0544E47504159 00` (Lc=07, AID=7 bytes) | `<32B receiver_pub> 90 00` |
| Put-Data chunk | `80 D0 <p1> <p2> <Lc> <data...>` where p1=chunk index, p2=total | `90 00` (more) / `90 01` (last received) |
| Get Ack | `80 C0 00 00 40` | `<64B ack-sig> 90 00` |

Chunking: each chunk ≤ 240 bytes payload (plus header) to stay below typical 256-byte
APDU max comfortably across drivers. JWS string split front-to-back; receiver reassembles.

### 5.4 Receiver ack-signature
- Receiver signs `sha256(jws)` with its own Ed25519 key.
- Purpose: proves to sender that "the device with kid X received my token at timestamp Y".
- Sender stores ack alongside outbox entry; included in `POST /tokens/settle` for audit.

### 5.5 Failure handling
- Tap timeout (no APDUs after 30s) → both sides cancel, no state change.
- Mid-stream disconnect → receiver discards partial; sender's outbox not yet committed
  until ack received.
- Verification fail at receiver → sends `6A 80` and aborts; sender drops the attempt.

## 6. Anti-replay & double-spend defenses

### 6.1 Layers
1. **Per-tx nonce**: 128-bit random nonce in payload. Server's `nonce_seen` table
   uses conditional put (DynamoDB `attribute_not_exists(nonce)`); the second submission
   gets `ConditionalCheckFailedException` → reject.
2. **`tx_id` uniqueness**: secondary uniqueness check in token_ledger.
3. **`exp` window**: tokens > exp are auto-rejected without reaching the ledger.
4. **Receiver pinning**: `receiver.pub` is in the signed payload — sender can't reuse
   the same token for a different receiver.
5. **Monotonic device counter** (optional): each token includes `seq` per device;
   server keeps `last_seq[kid]` and rejects out-of-order seqs (relaxes for parallel
   inbox/outbox; primary defense remains nonce).
6. **Geo + velocity heuristics**: server-side fraud scoring (AWS Lambda) flags rapid
   geographically impossible signatures; flagged items go to manual review, not
   auto-reject (avoid false positives in demo).

### 6.2 Double-spend across two receivers — concrete example
- Sender signs token T with nonce N for receiver A.
- Sender (offline) tries to sign a *new* token T' with the same nonce N for receiver B.
  The app's outbox prevents this in normal operation by tracking nonces and never
  re-using.
- Even if the sender's app is *compromised* and reuses N: at settlement, whichever
  reaches the server first wins; the second receives `409 NONCE_REUSED`. Receivers
  observe pending status and the loser is notified.

### 6.3 Token chaining (offline-offline relay) — optional v1.1
- A receiver who is also offline can immediately *forward* the value as a new token
  signed by them, referencing the inbound token's `tx_id` in `parent_tx`.
- At settlement, server resolves the chain atomically: parent settles first; child
  settles only if parent succeeded. Out of MVP scope but designed for here.

## 7. Server-side verification (in `Lambda settle`)

Pseudo-code (Python):
```python
def verify_token(jws: str) -> Result:
    header, payload, sig = decode(jws)
    if header['alg'] != 'EdDSA' or header['typ'] != 'tng-offline-tx+jws':
        return REJECT('bad_header')
    pub = pubkey_lookup(header['kid'])  # Dynamo + OSS
    if pub is None:
        return REJECT('unknown_kid')
    if not ed25519_verify(pub, signing_input(jws), sig):
        return REJECT('bad_sig')
    if payload['exp'] < now():
        return REJECT('expired')
    if payload['receiver']['pub'] != recorded_recipient(payload):
        return REJECT('receiver_mismatch')
    if not nonce_first_seen(payload['nonce'], payload['tx_id']):
        return REJECT('nonce_reused')
    return ACCEPT(payload)
```

`nonce_first_seen` is a DynamoDB conditional put on `nonce_seen` table — see
[docs/09-data-model.md §DynamoDB](09-data-model.md).

## 8. Test vectors

A canonical test JWS will live at `ml/test-vectors/token-001.jws` after build. The
verification suite must include:

| Vector | Expected |
|---|---|
| `token-001.jws` | valid → ACCEPT |
| `token-001-bad-sig.jws` | tampered last byte of sig → `bad_sig` |
| `token-001-expired.jws` | exp = iat → `expired` |
| `token-001-replayed.jws` | second submission of same nonce → `nonce_reused` |
| `token-001-wrong-recv.jws` | receiver pub mutated → `receiver_mismatch` |
| `token-001-unknown-kid.jws` | kid not in directory → `unknown_kid` |

## 9. Open issues

- Should we allow `kid` rotation mid-batch? **Decision:** no in v1; settle pre-rotation
  tokens against pre-rotation key for a 30-day grace period.
- Should ack-signature be required for settlement? **Decision:** no in v1 (receiver may
  be unreachable); ack improves auditability but is not a settlement gate.
- Token max amount: **decision** caps at sender's `policy_signed_balance` field; server
  also enforces global cap (default RM 250) per token to bound risk.
