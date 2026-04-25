---
name: 03-token-protocol
description: JWS token schema, Ed25519 signing rules, two-tap NFC APDU exchange (merchant-initiated), replay and double-spend defenses
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

### 3.4 Payment request format (tap 1)

The payment request is **not** a JWS — it is a plain JSON structure sent by the
merchant (Aida) to the payer (Faiz) during tap 1. It is not signed because Aida's
identity is conveyed by her pubkey, which Faiz can cache from prior interactions or
accept at face value for low-value taps.

```json
{
  "typ": "tng-payment-request+json",
  "ver": 1,
  "request_id": "01HW5ABCD...",
  "receiver": {
    "kid": "did:tng:device:01HW4...",
    "pub": "BASE64URL(32 bytes)",
    "display_name": "Aida Stall"
  },
  "amount": {
    "value": "8.50",
    "currency": "MYR",
    "scale": 2
  },
  "memo": "Nasi lemak + teh tarik",
  "issued_at": 1745603400,
  "expires_at": 1745603700
}
```

| Field | Required | Notes |
|---|---|---|
| `typ` | yes | Must be `tng-payment-request+json` |
| `request_id` | yes | UUIDv7 for deduplication |
| `receiver.pub` | yes | Aida's Ed25519 pub; Faiz uses this as `receiver.pub` when building the JWS |
| `amount` | yes | Pre-filled by Aida on her Request screen |
| `memo` | no | Human-readable item description |
| `issued_at` / `expires_at` | yes | Request valid for 5 minutes; Faiz's app rejects stale requests |

### 3.5 Size budget

| Component | Bytes |
|---|---|
| Header | ~140 |
| Payload (typical) | ~480 |
| Signature | 88 |
| **Total compact JWS** | ~720 bytes |
| Payment request JSON (tap 1) | ~300 bytes |

Both fit comfortably in NFC APDU multi-frame transfer (1–2 chunks each).

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

## 5. NFC APDU exchange — two-tap merchant-initiated flow

The flow is **merchant-initiated**: Aida (merchant) enters the amount and taps first.
This mirrors how physical POS terminals work — the merchant's device presents the
bill; the customer's device pays. It requires two separate NFC sessions with swapped
reader/HCE roles.

### 5.1 Application IDs

**Canonical AID** (single source of truth — every component must use this exact value):

```
AID = F0544E47504159   (7 bytes; "F0" + ASCII "TNGPAY")
```

- The *active reader* in each tap sends `SELECT` with this AID.
- The *active HCE service* on each phone registers with this AID in `apduservice.xml`.
- Phones always register the HCE service; role switching is purely about which screen
  is open and which APDU sequence each side executes within the session.

### 5.2 Tap 1 — payment request delivery (Aida reader → Faiz HCE)

Aida opens the **Request Payment** screen, enters RM 8.50, then taps her phone to
Faiz's phone.

```
         Aida (reader mode)                   Faiz (HCE mode)
               │                                    │
               │ ─── SELECT AID F0544E47504159 ──>  │
               │ <─── 9000 + faiz_pub (32B) ─────── │  ← Faiz's HCE responds immediately
               │                                    │
               │ ─── PUT-REQUEST chunk 0/N ──────>  │  ← payment request JSON
               │ ─── PUT-REQUEST chunk N/N ──────>  │
               │ <─── 9000 (ack) ────────────────── │
               │                                    │
               ▼                                    ▼
   shows "request sent, waiting             shows "Pay RM 8.50 to Aida Stall?"
    for Faiz to confirm"                    [Confirm with biometric]
```

**What Faiz's HCE responds on SELECT:** Faiz's `TngHostApduService` is running in the
background whenever HCE is enabled. On receiving SELECT AID, it immediately returns
Faiz's 32-byte Ed25519 public key + `9000`. No user interaction is needed at this
point.

**What Faiz's app does after receiving the payment request:** The app surfaces a
confirmation screen: amount, merchant name, memo. Faiz must authorize with biometric
or PIN before tap 2 proceeds.

### 5.3 Tap 2 — JWS payment delivery (Faiz reader → Aida HCE)

After Faiz authorizes biometrically, he taps his phone to Aida's phone again.
Roles are now reversed: Faiz is the reader, Aida is the HCE card.

```
         Faiz (reader mode)                   Aida (HCE mode)
               │                                    │
               │ ─── SELECT AID F0544E47504159 ──>  │
               │ <─── 9000 + aida_pub (32B) ──────── │  ← confirms Aida's pub (already known from tap 1)
               │                                    │
               │ ─── PUT-DATA chunk 0/N (JWS) ───>  │
               │ ─── PUT-DATA chunk 1/N ──────────> │
               │ ─── PUT-DATA chunk N/N ──────────> │
               │ <─── 9000 + last-chunk-ack ─────── │
               │                                    │
               │ ─── GET ACK ────────────────────>  │
               │ <─── 9000 + ack-signature (64B) ── │  ← Aida signs sha256(jws) with her key
               │                                    │
               ▼                                    ▼
        outbox: PENDING_SETTLEMENT          inbox: PENDING_SETTLEMENT
        shows receipt screen                shows "Received RM 8.50 — pending"
```

Faiz builds the JWS payload using `receiver.pub` obtained in tap 1, signs it via
Android Keystore (biometric already cleared), and transmits.

### 5.4 APDUs in detail

#### Tap 1 APDUs

| APDU | C-APDU | R-APDU |
|---|---|---|
| Select AID | `00 A4 04 00 07 F0544E47504159 00` | `<32B payer_pub> 90 00` |
| Put-Request chunk | `80 E0 <p1> <p2> <Lc> <data...>` where p1=chunk index, p2=total chunks | `90 00` |

`0x80 0xE0` is the instruction byte for PUT-REQUEST (tap 1 direction).
Faiz's HCE stores the assembled payment request JSON and triggers the confirmation
notification to the Flutter layer via a `MethodChannel` event.

#### Tap 2 APDUs

| APDU | C-APDU | R-APDU |
|---|---|---|
| Select AID | `00 A4 04 00 07 F0544E47504159 00` | `<32B receiver_pub> 90 00` |
| Put-Data chunk | `80 D0 <p1> <p2> <Lc> <data...>` where p1=chunk index, p2=total | `90 00` (more) / `90 01` (last received) |
| Get Ack | `80 C0 00 00 40` | `<64B ack-sig> 90 00` |

`0x80 0xD0` is the instruction byte for PUT-DATA (tap 2 direction, same as original single-tap spec).

Chunking: each chunk ≤ 240 bytes payload to stay below typical 256-byte APDU max.
Both PUT-REQUEST and PUT-DATA split front-to-back; the HCE side reassembles.

### 5.5 HCE role disambiguation

Both phones run `TngHostApduService` at all times. The service distinguishes tap 1 from
tap 2 by the instruction byte of the first PUT command after SELECT:

| Instruction byte | Session type | What the HCE does |
|---|---|---|
| `0x80 0xE0` | Tap 1 — incoming payment request | Reassemble request JSON; notify Flutter; respond with own pub on SELECT |
| `0x80 0xD0` | Tap 2 — incoming JWS payment | Reassemble JWS; verify locally if pub cached; write to inbox; return ack-sig |

This makes the HCE service stateless across taps — state is keyed by instruction,
not by session ordering.

### 5.6 Ack-signature (tap 2)

- **What it is:** Aida signs `sha256(jws)` with her own Ed25519 key and sends it back
  to Faiz via GET ACK in tap 2.
- **Why:** Proves that Aida's specific device received this exact token. Faiz stores the
  ack alongside the JWS in his outbox and includes it in `POST /tokens/settle` for audit.
- **Settlement gate:** ack-signature is **not** required for settlement to succeed in v1.
  Settlement proceeds on the JWS alone. The ack improves auditability and dispute
  resolution but is not a hard precondition.

### 5.7 Failure handling

| Failure | Tap | Behavior |
|---|---|---|
| Tap timeout (no APDUs after 30s) | Either | Both sides cancel; no state change |
| Mid-stream disconnect during PUT | Either | HCE discards partial; no commit |
| Faiz rejects on confirmation screen | After tap 1 | Tap 2 never happens; Aida's request expires after 5 min |
| Faiz's biometric fails | After tap 1 | Retry biometric; tap 2 blocked until cleared |
| Verification fail at Aida's HCE | Tap 2 | Sends `6A 80`; Faiz shows error; outbox not written |
| Aida's app killed between taps | Tap 1 → tap 2 gap | Aida reopens Request screen; new `request_id` issued; old one expires harmlessly |

## 6. Anti-replay & double-spend defenses

### 6.1 Layers
1. **Per-tx nonce**: 128-bit random nonce in payload. Server's `nonce_seen` table
   uses conditional put (DynamoDB `attribute_not_exists(nonce)`); the second submission
   gets `ConditionalCheckFailedException` → reject.
2. **`tx_id` uniqueness**: secondary uniqueness check in token_ledger.
3. **`exp` window**: tokens > exp are auto-rejected without reaching the ledger.
4. **Receiver pinning**: `receiver.pub` is in the signed payload — sender can't reuse
   the same token for a different receiver.
5. **Payment request expiry**: `request_id` has a 5-minute `expires_at`. Faiz's app
   rejects stale requests before building the JWS, preventing Aida from replaying an
   old request to charge Faiz again.
6. **Monotonic device counter** (optional): each token includes `seq` per device;
   server keeps `last_seq[kid]` and rejects out-of-order seqs (relaxes for parallel
   inbox/outbox; primary defense remains nonce).
7. **Geo + velocity heuristics**: server-side fraud scoring (AWS Lambda) flags rapid
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

A canonical test JWS will live at `ml/test-vectors/token-001.jws` after build.
A canonical test payment request will live at `ml/test-vectors/request-001.json`.
The verification suite must include:

| Vector | Expected |
|---|---|
| `token-001.jws` | valid → ACCEPT |
| `token-001-bad-sig.jws` | tampered last byte of sig → `bad_sig` |
| `token-001-expired.jws` | exp = iat → `expired` |
| `token-001-replayed.jws` | second submission of same nonce → `nonce_reused` |
| `token-001-wrong-recv.jws` | receiver pub mutated → `receiver_mismatch` |
| `token-001-unknown-kid.jws` | kid not in directory → `unknown_kid` |
| `request-001-expired.json` | `expires_at` in past → app rejects before tap 2 |

## 9. Open issues

- Should we allow `kid` rotation mid-batch? **Decision:** no in v1; settle pre-rotation
  tokens against pre-rotation key for a 30-day grace period.
- Should ack-signature be required for settlement? **Decision:** no in v1 (receiver may
  be unreachable); ack improves auditability but is not a settlement gate.
- Token max amount: **decision** caps at sender's `policy_signed_balance` field; server
  also enforces global cap (default RM 250) per token to bound risk.
- Payment request signing: **decision** not signed in v1 (low-value, short TTL, and
  receiver.pub is verified by Faiz's app against cached directory on next online). v1.1
  may add a request signature to prevent a MITM from swapping Aida's pub to their own.
