---
name: 10-security-threat-model
description: STRIDE threat model, mitigations, key lifecycle, KYC tiers, data residency
owner: Security
status: ready
depends-on: [03-token-protocol, 05-aws-services, 06-alibaba-services, 09-data-model]
last-updated: 2026-04-25
---

# Security & Threat Model

## 1. Trust assumptions

- Android Keystore (StrongBox/TEE-backed where available) is trusted for private-key
  storage.
- TLS 1.3 everywhere on the wire; mTLS on cross-cloud bridges.
- Cognito is trusted to issue authentic JWTs.
- The user is **untrusted** for app integrity but **assumed honest** as a baseline;
  the system must still defend against malicious users (double-spend, dispute abuse).
- The hackathon network (demo Wi-Fi) is untrusted.

## 2. Assets

| Asset | Sensitivity |
|---|---|
| Device Ed25519 private key | **Critical** — full forgery if leaked |
| Wallet balance | High |
| Token ledger | High |
| User PII (phone, IC last 4) | High |
| Settlement signing/envelope keys (KMS) | Critical |
| Model artifacts | Medium (tampering → bad scores) |

## 3. STRIDE table

| ID | Threat | STRIDE | Mitigation | Where it lives |
|---|---|---|---|---|
| T-01 | Stolen device used to sign new tokens | **S**poofing | Biometric/PIN required at sign-time (`setUserAuthenticationRequired(true)`). Server can revoke `kid` on user request. Pre-revocation tokens still settle; server caps damage via `policy_signed_balance` field. | [docs/03-token-protocol.md §4](03-token-protocol.md), [docs/07-mobile-app.md §6](07-mobile-app.md) |
| T-02 | Cloned device key (rooted phone) | **S** | Hardware-backed Keystore + Android Key Attestation chain verified server-side at registration. KYC tier gates higher offline limits. | [docs/03-token-protocol.md §3.2](03-token-protocol.md), [docs/08-backend-api.md §3.1](08-backend-api.md) |
| T-03 | Replay of a signed JWS to settle twice | **T**ampering / Repudiation | DynamoDB `tng_nonce_seen` conditional put. `exp` window. | [docs/03-token-protocol.md §6.1](03-token-protocol.md), [docs/05-aws-services.md §4.1](05-aws-services.md) |
| T-04 | Double-spend across two receivers (same nonce) | **T** | Same nonce-seen guard; first wins, second rejected. Receiver gets clear status. | [docs/03-token-protocol.md §6.2](03-token-protocol.md) |
| T-05 | Tampered amount in transit | **T** | JWS signature covers amount; verification rejects. | [docs/03-token-protocol.md §3.3](03-token-protocol.md) |
| T-06 | MITM intercepts NFC and modifies token | **T** | NFC range ~4cm; signature still validates only original payload. Tampered → bad sig → reject. | [docs/03-token-protocol.md §5](03-token-protocol.md) |
| T-07 | Receiver pretends not to have received (repudiation) | **R**epudiation | Sender keeps the receiver's ack-signature alongside the outbox; server records both during settlement. | [docs/03-token-protocol.md §5.4](03-token-protocol.md) |
| T-08 | Server compromise: malicious settlement | **E**levation | KMS-wrapped envelope keys; settle Lambda runs with least-privilege role; admin actions need MFA + Step Functions approval. | [docs/05-aws-services.md §11](05-aws-services.md) |
| T-09 | Model tampering (OTA poisoning) | **T**ampering | Sigstore-signed model.tflite; mobile verifies signature against bundled root before swap. | [docs/04-credit-score-ml.md §10](04-credit-score-ml.md) |
| T-10 | Malicious merchant accepts then disputes everything | **R** | Dispute rate per merchant → flagged via fraud-score Lambda; KYC tier locked till review. | [docs/05-aws-services.md §4](05-aws-services.md) |
| T-11 | DOS on wallet API | **D**oS | API Gateway rate limit + per-user throttle; FC autoscale; ledger is on-demand DynamoDB | [docs/06-alibaba-services.md §5](06-alibaba-services.md) |
| T-12 | Information disclosure of PII | **I** | Direct PII (name, phone, IC) stays in APAC (Alibaba). AWS holds pseudonymous IDs, amounts, and signed JWS (which include best-effort `geo` — treated as indirect PII). KMS-encrypted at rest both sides. See [docs/09-data-model.md §6](09-data-model.md) for precise residency posture. | [docs/09-data-model.md §6](09-data-model.md) |
| T-13 | Lost phone with offline-signed tokens not yet settled | **R** | Receiver still settles using sender's signed token; sender can't repudiate. User can revoke key, but pre-revocation tokens settle. | [docs/03-token-protocol.md §4](03-token-protocol.md) |
| T-14 | Token forgery via weak RNG | **T** | Use platform CSPRNG (`SecureRandom`) for nonce; Ed25519 deterministic so no nonce reuse on signing side. | [docs/03-token-protocol.md §3.2](03-token-protocol.md) |
| T-15 | Cross-cloud webhook abuse | **S** | mTLS + HMAC-signed payload + IP allowlist + replay protection (timestamp + signed nonce). | [docs/05-aws-services.md §8](05-aws-services.md), [docs/06-alibaba-services.md §10](06-alibaba-services.md) |
| T-16 | Stolen Cognito JWT used after device loss | **S** | Short access-token TTL (15 min); refresh token bound to device fingerprint; revoke on lost-device flow. | [docs/05-aws-services.md §6](05-aws-services.md) |
| T-17 | Settlement API receives malformed JWS that crashes worker | **D** | Strict JSON schema + JWS regex pre-check; bounded chunk size; per-token try/except in `settle-batch`. | [docs/05-aws-services.md §4.1](05-aws-services.md) |
| T-18 | User refunds via dispute flood | **R** | Dispute rate-limited per user; abuse pattern detection in fraud-score; legitimate disputes always reach human review. | [docs/08-backend-api.md §3.6](08-backend-api.md) |

## 4. Key lifecycle (device signing key)

```
[generate]  Onboarding → KeyGenParameterSpec(Ed25519, StrongBox if avail,
            user-auth required, attestation challenge)
   │
   ▼
[register]  POST /devices/register {pub, attestation_chain}
            Server verifies chain rooted in Google attestation root.
            Status set ACTIVE in Tablestore + cached in DynamoDB.
   │
   ▼
[use]       Each sign() requires biometric/PIN unless amount ≤ RM 5
            (UX cap, configurable).
   │
   ▼
[rotate]    Triggered by: server policy bump, OS upgrade with attestation refresh,
            manual user request. New kid registered; old kept ACTIVE for 30d
            grace to settle in-flight tokens; then PENDING_REVOKE.
   │
   ▼
[revoke]    Triggered by: lost device flow, compromise. Status REVOKED;
            new tokens with revoked kid rejected at settlement; pre-revocation
            tokens (iat < revoked_at) still settle.
   │
   ▼
[purge]     After 1 year revoked, kid record archived to cold storage.
```

## 5. Key lifecycle (settlement KMS keys)

- AWS KMS CMK `tng-finhack-jwt-signer`: rotated annually (CMK auto-rotation).
  Used for signing internal service-to-service JWTs.
- AWS KMS CMK `tng-finhack-key`: data encryption envelope; auto-rotated annually.
- Alibaba KMS CMK `tng-finhack-cert-ca`: issues per-device X.509 in higher-tier
  scenarios; rotated on Org event.
- All KMS access logged via CloudTrail / ActionTrail; alarm on unexpected `Decrypt`
  callers.

## 6. KYC tiers

| Tier | Onboarding effort | Hard cap (per token) | Hard cap (offline cumulative / 24h) | Allowed offline use |
|---|---|---|---|---|
| 0 (default) | phone OTP only | RM 20 | RM 50 | Pay only, no receive |
| 1 | + IC last 4 | RM 50 | RM 150 | Pay + receive |
| 2 | + government eKYC verification | RM 250 | RM 500 | All; eligible for AI safe-balance computation |

The 600-transaction segmentation rule from `Idea.md` is independent: **regardless of
tier**, users with <600 lifetime txns get the manual-pre-load offline wallet, not the
AI-derived dynamic balance. KYC tier is about caps; segmentation is about model
applicability.

## 7. Data residency

- Direct PII (`users`, `kyc_records`, `disputes`, `merchants`) stored in Alibaba
  ap-southeast-3 (KL) only.
- Token ledger on AWS holds: pseudonymous `user_id`, `kid`, amounts, signed JWS
  blobs. JWS payloads contain optional `geo` (lat/lon) and `policy_signed_balance`
  — these are indirect PII; the AWS surface is **pseudonymous-minimal**, not
  PII-free.
- Cross-cloud events carry `user_id` opaque IDs only; never names, phones, IC numbers.
- Logs scrubbed of PII before shipping (FC log filter; Lambda log filter on AWS).

## 8. Crypto choices summary

| Use | Algo | Why |
|---|---|---|
| Token signing | Ed25519 | small sigs, deterministic, fast on phones, hardware-backed |
| Pubkey directory | OSS storage of raw 32-byte pub | offline verifiability |
| Service auth | Cognito JWT (RS256) | standard JWKS workflow |
| Cross-cloud auth | mTLS + HMAC body | belt-and-suspenders |
| Data at rest | KMS envelopes (AES-256-GCM) | both clouds |
| Model integrity | sigstore Cosign signature on tflite | OTA poisoning defense |

## 9. Demo-day risks

- WiFi flaky → can't reach AWS during demo: mitigated by both clouds being reachable
  from the demo phones; the showcase is exactly about not requiring network.
- Audience phone in airplane mode but tries to connect: NFC tap demoed first, then
  reconnect — script covers this.
- Demo Pixel devices may have outdated Keystore: pre-flight checklist verifies API 33+.

## 10. Future hardening (post-hackathon)

- Move from JWS to COSE_Sign1 for ~30% smaller token size.
- Hardware Security Module for KMS root keys.
- Federated learning across phones to improve safe-balance personalization with no
  raw data leaving devices.
- Zero-knowledge balance proofs for stronger receiver privacy.
- Bounded liability via ramp-up: new accounts get tighter caps for first N days.
