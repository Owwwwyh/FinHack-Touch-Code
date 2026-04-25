---
name: 02-user-flows
description: User stories, screens with ASCII wireframes, and step-by-step user flows — two-tap merchant-initiated payment
owner: UX
status: ready
depends-on: [00-overview, 01-architecture]
last-updated: 2026-04-25
---

# User Flows & Screens

## 1. Personas

| Persona | Tag | Lives in |
|---|---|---|
| Aida — hawker stall owner, occasional 4G | `merchant-rural` | Coverage gap zone |
| Faiz — Grab rider on prepaid data | `gig-prepaid` | Mostly online but data runs out |
| Mei — student, often basement classes | `student-deadzone` | Indoor dead zones |
| Encik Hassan — first-time digital wallet user, distrustful | `new-cashless` | Wedge for inclusion |

## 2. User stories

| ID | Story | Acceptance |
|---|---|---|
| US-01 | As Faiz, I want my wallet to show a "safe offline balance" so I know how much I can spend on the next ride if my data dies. | Home screen always shows two numbers: synced balance + safe-offline. |
| US-02 | As Aida, I want to initiate a payment request by entering the amount myself and tapping to Faiz's phone, so the flow mirrors how I handle cash. | Aida enters amount on Request screen; tap 1 delivers request; Faiz approves with biometric; tap 2 completes payment — all offline. |
| US-03 | As Encik Hassan, I want clear feedback that my offline payment will be settled later, with a receipt I can show. | Receipt with QR/txId + signed-by-bank-style stamp, viewable offline. |
| US-04 | As Mei, I want my balance to auto-sync when data returns and pending tokens to settle silently. | Background settlement on connectivity recovery, success toast. |
| US-05 | As ops, I want every offline transaction to be cryptographically attributable to a specific device key. | Each token has Ed25519 signature; JWKS lookup at settlement. |
| US-06 | As ops, I want double-spends caught at settlement, not in production cash flow. | Second use of a nonce returns `409 NONCE_REUSED`. |

## 3. Screen inventory

| Screen | Route | Key states | Who uses it |
|---|---|---|---|
| Splash / KYC gate | `/` | first-run vs returning | both |
| Onboarding (KYC tier 1) | `/onboard` | 3 steps: phone, eKYC stub, device-key gen | both |
| Home | `/home` | online / 10-min-stale / offline | both |
| Request Payment | `/request` | enter amount → tap 1 → waiting | **Aida (merchant)** |
| Request Pending | `/request/pending` | countdown, waiting for Faiz's tap 2 | Aida |
| Pay Confirm | `/pay/confirm` | incoming request → biometric approve → tap 2 | **Faiz (payer)** |
| Receive (post-settlement) | `/receive` | receipt after tap 2 completes | Aida |
| Pending tokens | `/pending` | outbox + inbox | both |
| History | `/history` | settled + pending | both |
| Settings | `/settings` | device info, policy version, sign-out, key rotation | both |
| AI Score Panel | `/score` | breakdown + how-to-improve | Faiz |

> The previous single-screen **Pay** flow (payer enters amount) and **Receive** flow
> (passive wait) are replaced by the two-tap merchant-initiated flow described in §5.

## 4. Wireframes (ASCII)

### 4.1 Home — online state
```
┌──────────────────────────────────────┐
│ ◀ TNG Wallet                  ☰      │
│                                      │
│   ●  Online  ·  synced 2 sec ago     │
│                                      │
│   RM 248.50                          │
│   ───────────                        │
│   available balance                  │
│                                      │
│   Safe offline:  RM 120.00 ✓ AI      │
│   ───────────────────────────────    │
│                                      │
│   ┌──────────┐    ┌──────────┐       │
│   │ REQUEST  │    │ HISTORY  │       │
│   │ PAYMENT  │    │          │       │
│   └──────────┘    └──────────┘       │
│                                      │
│   Recent                             │
│   ─ Aida Stall      −RM 8.50  ✓      │
│   ─ Top-up          +RM 50    ✓      │
└──────────────────────────────────────┘
```

> **Note:** Both merchants and payers see the same home screen. Merchants tap
> "REQUEST PAYMENT" to initiate. Payers do not need to navigate anywhere —
> the pay confirm screen appears automatically when their phone receives tap 1.

### 4.2 Home — offline state
```
┌──────────────────────────────────────┐
│ ◀ TNG Wallet                  ☰      │
│                                      │
│   ◌  Offline  ·  last sync 14 min    │
│      ⚠ Limited mode                  │
│                                      │
│   Safe offline:  RM 120.00           │
│   ────────────                       │
│   available offline                  │
│                                      │
│   ┌──────────┐    ┌──────────┐       │
│   │ REQUEST  │    │ HISTORY  │       │
│   │ PAYMENT  │    │          │       │
│   └──────────┘    └──────────┘       │
│                                      │
│   ✱  Tap RECONNECT to refresh        │
│      [   Reconnect   ]               │
│                                      │
│   2 pending tokens • will settle      │
└──────────────────────────────────────┘
```

### 4.3 Request Payment — Aida enters amount (NEW)
```
┌──────────────────────────────────────┐
│ ◀ Request Payment                    │
│                                      │
│         RM  ____.__                  │
│         ─────────                    │
│                                      │
│   [ 1 ][ 2 ][ 3 ]                    │
│   [ 4 ][ 5 ][ 6 ]                    │
│   [ 7 ][ 8 ][ 9 ]                    │
│   [ . ][ 0 ][ ⌫ ]                    │
│                                      │
│   Memo (optional):  ________________ │
│                                      │
│   ┌──────────────────────────────┐   │
│   │  📡  Tap payer's phone  →    │   │
│   └──────────────────────────────┘   │
└──────────────────────────────────────┘
```

### 4.4 Request Pending — Aida waits for Faiz (NEW)
```
┌──────────────────────────────────────┐
│ ◀ Waiting for payment                │
│                                      │
│         RM 8.50                      │
│         ──────                       │
│         Nasi lemak + teh tarik       │
│                                      │
│         📡  Waiting for Faiz         │
│             to tap back...           │
│                                      │
│         ⏱  4:32 remaining            │
│                                      │
│   ─────────────────────────────────  │
│   [ Resend request ]  [ Cancel ]     │
└──────────────────────────────────────┘
```

### 4.5 Pay Confirm — Faiz sees Aida's request (NEW)
```
┌──────────────────────────────────────┐
│  Payment Request Received            │
│  ────────────────────────────────    │
│                                      │
│         RM 8.50                      │
│         ──────                       │
│         to:  Aida Stall              │
│         for: Nasi lemak + teh tarik  │
│                                      │
│   Safe offline balance: RM 120.00    │
│   After payment:        RM 111.50    │
│                                      │
│   ┌──────────────────────────────┐   │
│   │   ✓  Authorize with PIN      │   │
│   └──────────────────────────────┘   │
│                                      │
│         [ Cancel ]                   │
└──────────────────────────────────────┘
```

This screen appears **automatically** when Faiz's phone receives the tap-1 NFC event.
Faiz does not need to navigate to it.

### 4.6 Tap 2 prompt — Faiz taps back (NEW)
```
┌──────────────────────────────────────┐
│             ●  Authorized            │
│                                      │
│             RM 8.50                  │
│             ──────                   │
│             to: Aida Stall           │
│                                      │
│   📡  Now tap your phone             │
│       to Aida's phone to pay         │
│                                      │
│       [  ●●●  Tap detected  ]        │
│                                      │
│       [ Cancel payment ]             │
└──────────────────────────────────────┘
```

### 4.7 Payment sent — Faiz receipt
```
┌──────────────────────────────────────┐
│  ✓  Payment sent                     │
│  ────────────────────────────────    │
│                                      │
│   RM 8.50  →  Aida Stall            │
│   Nasi lemak + teh tarik             │
│   Pending settlement                 │
│                                      │
│   Ref: …e9NP                        │
│                                      │
│   [ View receipt ]  [ Done ]         │
└──────────────────────────────────────┘
```

### 4.8 Received — Aida receipt
```
┌──────────────────────────────────────┐
│  ✓  Payment received                 │
│  ────────────────────────────────    │
│                                      │
│   RM 8.50  from Faiz (…3f4)         │
│   Pending settlement                 │
│                                      │
│   [ View pending ]  [ New request ]  │
└──────────────────────────────────────┘
```

### 4.9 AI Score Panel
```
┌──────────────────────────────────────┐
│ ◀ Your safe offline balance          │
│                                      │
│      RM 120.00                       │
│      ─────────                       │
│      out of RM 248.50 available      │
│                                      │
│   How we calculate this:             │
│   • Your usual spend                 │
│   • How often you reload             │
│   • Time since last sync             │
│   • Your transaction history         │
│                                      │
│   To raise this limit:               │
│   ▸ Reload more regularly            │
│   ▸ Complete KYC tier 2              │
│                                      │
│   Model version: 2026-04-22 v3       │
└──────────────────────────────────────┘
```

## 5. Flows

Each flow names the source-of-truth doc + section for the *behavior* it depends on.

### Flow F1 — Onboarding & device-key generation
**Trigger:** First app launch.
**Behavior owners:** [docs/03-token-protocol.md §4](03-token-protocol.md), [docs/10-security-threat-model.md §4](10-security-threat-model.md), [docs/08-backend-api.md §3.1](08-backend-api.md).

```
1. App launches → splash → "Set up your offline wallet"
2. User enters phone → OTP (stubbed for demo)
3. KYC tier 1 stub: name + IC last 4
4. App generates Ed25519 keypair in Android Keystore
5. App calls POST /devices/register {userId, devicePub, attestation}
6. Backend stores in Tablestore.devices and OSS pubkey directory
7. App receives initial policy_version + initial cached safe-offline = RM 50
8. → Home
```

### Flow F2 — Online balance refresh
**Trigger:** App foreground OR pull-to-refresh OR every 10 min while online.
**Behavior owners:** [docs/01-architecture.md §5.1](01-architecture.md), [docs/08-backend-api.md §3.3](08-backend-api.md).

```
1. App calls GET /wallet/balance with Cognito JWT
2. FC reads Tablestore.wallets[userId] → returns balance + version
3. App writes Drift cache with synced_at = now
4. UI shows "Online · synced 2s ago"
```

### Flow F3 — Going offline indicator
**Trigger:** ConnectivityResult changes to none, OR balance sync fails 3x.
**Behavior owners:** [docs/07-mobile-app.md §5](07-mobile-app.md).

```
1. App enters OFFLINE state
2. Banner shows "Offline · last sync N min"
3. Home replaces "available" with "safe offline"
4. AI scorer (TF Lite) runs locally to recompute safe_offline_balance
5. Result clamped to min(cached_balance, model_output, hard_cap_per_policy)
6. User sees the lower number; payment is blocked if request > safe balance
```

### Flow F4 — Offline payment (merchant-initiated, two taps)
**Trigger:** Aida opens Request Payment screen, enters amount, taps phone to Faiz.
**Behavior owners:** [docs/03-token-protocol.md §3.4, §5](03-token-protocol.md), [docs/07-mobile-app.md §7](07-mobile-app.md).

```
── TAP 1 ──────────────────────────────────────────────────────

1. Aida opens REQUEST PAYMENT screen, enters RM 8.50 + optional memo.
2. Aida taps her phone to Faiz's phone (Aida = reader, Faiz = HCE).
   a. SELECT AID → Faiz's HCE responds with Faiz's Ed25519 pub (no user action needed).
   b. Aida's app sends payment request JSON in chunks via PUT-REQUEST APDUs.
      Payload: {request_id, receiver: {Aida's kid + pub}, amount, memo, issued_at, expires_at}
   c. Faiz's HCE reassembles and fires an EventChannel event to Flutter.
3. Aida's screen transitions to REQUEST PENDING (4:59 countdown).
4. Faiz's app navigates automatically to PAY CONFIRM screen showing:
   "Pay RM 8.50 to Aida Stall — Nasi lemak + teh tarik"
   Remaining safe balance after: RM 111.50
5. Faiz reviews and taps [Authorize with PIN] → biometric prompt.
   If amount > safe_offline_balance → button disabled, inline error shown.
   If request expired → app shows "Request expired, ask Aida to resend".
6. Biometric clears → JWS is signed in Android Keystore:
   payload: {tx_id=UUIDv7, sender={Faiz kid+pub}, receiver={Aida kid+pub from request},
             amount, nonce, iat, exp=iat+72h, policy_version, policy_signed_balance}
   signature: Ed25519 over base64url(header)+"."+base64url(payload)
7. Faiz's screen shows "Tap your phone to Aida's phone to pay →"

── TAP 2 ──────────────────────────────────────────────────────

8. Faiz taps his phone to Aida's phone (Faiz = reader, Aida = HCE).
   a. SELECT AID → Aida's HCE responds with Aida's pub (confirms receiver identity).
      Faiz's app checks this matches the pub received in tap 1.
   b. Faiz sends signed JWS in chunks via PUT-DATA APDUs.
   c. Aida's HCE reassembles JWS, verifies Ed25519 signature locally (if Faiz's pub
      is in cache; otherwise flags VERIFY_AT_SETTLEMENT).
   d. Aida's HCE fires EventChannel event with incoming JWS to Flutter.
   e. Faiz sends GET ACK → Aida's HCE signs sha256(jws) with Aida's key → returns
      64-byte ack-signature.
9. Faiz: writes outbox row {jws, ackSig, status=PENDING_SETTLEMENT}; shows receipt.
   Locally decrements safe_offline_balance by RM 8.50.
10. Aida: writes inbox row {jws, status=PENDING_SETTLEMENT}; shows "Received RM 8.50".
```

### Flow F5 — Offline receive (Aida's view — updated)
**Trigger:** Tap 2 NFC session on Aida's phone (HCE receives JWS chunks).
**Behavior owners:** [docs/03-token-protocol.md §5.3](03-token-protocol.md).

```
1. Aida's HCE service receives SELECT AID → returns Aida's pub.
2. Receives JWS chunks via PUT-DATA APDUs; reassembles.
3. Verifies Ed25519 signature using sender_pub embedded in token:
   - If pub in local cache: full offline verify.
   - If pub not in cache: accept + flag VERIFY_AT_SETTLEMENT (still safe — server verifies).
4. Verifies amount matches the request amount (if pending request in state).
5. Verifies exp not in past.
6. Writes inbox row (Drift): status=PENDING_SETTLEMENT.
7. Responds to GET ACK with ack-signature: sha256(jws) signed with Aida's key.
8. Fires EventChannel event → Flutter shows "Received RM 8.50 from Faiz — pending".
```

### Flow F6 — Back-online settlement
**Trigger:** Either party regains connectivity AND outbox/inbox non-empty.
**Behavior owners:** [docs/01-architecture.md §5.3](01-architecture.md), [docs/08-backend-api.md §3.5](08-backend-api.md).

```
1. App background worker batches up to 50 tokens from outbox
2. POST /tokens/settle with idempotency-key = sha256(batch)
3. FC validates batch shape → emits Alibaba EventBridge event
4. AWS Lambda consumes event, processes each token:
   a. Verify Ed25519 against pubkey from DynamoDB cache (refilled from OSS)
   b. Conditional put on nonce_seen → if exists → reject DUPLICATE
   c. Write token_ledger with status=SETTLED
   d. Update wallet balance via cross-cloud event back to Alibaba
5. Lambda response → Alibaba EventBridge → FC → mobile sees settled set
6. App moves tokens to history with status=SETTLED
7. Mobile Push notifies Aida "RM 8.50 received from Faiz — settled"
```

### Flow F7 — Dispute a transaction
**Trigger:** User taps a settled txn in history → "Dispute".
**Behavior owners:** [docs/08-backend-api.md §3.6](08-backend-api.md), [docs/10-security-threat-model.md](10-security-threat-model.md).

```
1. User selects reason: didn't authorize / wrong amount / didn't receive goods
2. App POSTs /tokens/dispute with txId + reason + optional evidence text
3. FC writes dispute record in RDS, marks ledger status=DISPUTED
4. Out-of-band ops review (out of MVP scope; stubbed)
```

## 6. Empty / error / edge states (non-exhaustive)

| Screen | State | Behavior |
|---|---|---|
| Home | balance fetch fail | Stay on cached value, show "couldn't refresh, retrying" |
| Request Payment | amount entered, tap 1 fails | Show "tap failed, try again"; request not yet sent |
| Pay Confirm | amount > safe-offline | Disable authorize button, show inline hint |
| Pay Confirm | request expired | Show "Request expired — ask merchant to resend" |
| Pay Confirm | NFC disabled | Modal "Enable NFC in settings" with deeplink |
| Tap 2 | receiver pub mismatch | Cancel session, show "Device mismatch — tap Aida's phone again" |
| Tap 2 | tap timeout 30s | Cancel, return to "tap to pay" prompt; allow retry |
| Request Pending | 5-min countdown expires | Aida sees "Request expired" + [New request] button |
| Receive (tap 2) | sender pubkey unknown | Accept + flag VERIFY_AT_SETTLEMENT |
| Settlement | partial failure | Successful tokens move; failed stay PENDING with exponential backoff |
| Onboarding | Keystore unavailable | Block onboarding, show device-not-supported page |

## 7. Accessibility

- All interactive elements ≥ 48 dp tap target.
- Color is not the only signal for online/offline (icon + text label).
- Screen-reader labels on all currency values (Malay + English locales).
- Vibration confirmation on NFC tap (both tap 1 and tap 2) to support low-vision users.
- Pay Confirm screen readable by screen reader in full before biometric prompt.
