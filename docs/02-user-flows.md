---
name: 02-user-flows
description: User stories, screens with ASCII wireframes, and step-by-step user flows
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
| US-02 | As Aida, I want to receive payments by NFC tap even when both phones are offline. | A tap exchange completes < 2s and shows "received pending". |
| US-03 | As Encik Hassan, I want clear feedback that my offline payment will be settled later, with a receipt I can show. | Receipt with QR/txId + signed-by-bank-style stamp, viewable offline. |
| US-04 | As Mei, I want my balance to auto-sync when data returns and pending tokens to settle silently. | Background settlement on connectivity recovery, success toast. |
| US-05 | As ops, I want every offline transaction to be cryptographically attributable to a specific device key. | Each token has Ed25519 signature; JWKS lookup at settlement. |
| US-06 | As ops, I want double-spends caught at settlement, not in production cash flow. | Second use of a nonce returns `409 NONCE_REUSED`. |

## 3. Screen inventory

| Screen | Route | Key states |
|---|---|---|
| Splash / KYC gate | `/` | first-run vs returning |
| Onboarding (KYC tier 1) | `/onboard` | 3 steps: phone, eKYC stub, device-key gen |
| Home | `/home` | online / 10-min-stale / offline |
| Pay | `/pay` | enter amount → NFC tap → confirm |
| Receive | `/receive` | show NFC-ready → tap → received |
| Pending tokens | `/pending` | outbox + inbox |
| History | `/history` | settled + pending |
| Settings | `/settings` | device info, policy version, sign-out, key rotation |
| AI Score Panel | `/score` | breakdown + how-to-improve |

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
│   │   PAY    │    │ RECEIVE  │       │
│   └──────────┘    └──────────┘       │
│                                      │
│   Recent                             │
│   ─ Aida Stall      −RM 8.50  ✓      │
│   ─ Top-up          +RM 50    ✓      │
└──────────────────────────────────────┘
```

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
│   │   PAY    │    │ RECEIVE  │       │
│   └──────────┘    └──────────┘       │
│                                      │
│   ✱  Tap RECONNECT to refresh        │
│      [   Reconnect   ]               │
│                                      │
│   2 pending tokens • will settle      │
└──────────────────────────────────────┘
```

### 4.3 Pay
```
┌──────────────────────────────────────┐
│ ◀ Pay                                │
│                                      │
│         RM  ____.__                  │
│         ─────────                    │
│                                      │
│   [ 1 ][ 2 ][ 3 ]                    │
│   [ 4 ][ 5 ][ 6 ]                    │
│   [ 7 ][ 8 ][ 9 ]                    │
│   [ . ][ 0 ][ ⌫ ]                    │
│                                      │
│   Safe offline limit: RM 120.00      │
│                                      │
│   ┌──────────────────────────────┐   │
│   │   📡  Hold near receiver     │   │
│   └──────────────────────────────┘   │
└──────────────────────────────────────┘
```

### 4.4 Pay — tap in progress
```
┌──────────────────────────────────────┐
│             ●●●  Tap detected        │
│                                      │
│             RM 8.50                  │
│             ──────                   │
│             to: device …a3f4         │
│                                      │
│         [ ✓ Authorize with PIN ]     │
└──────────────────────────────────────┘
```

### 4.5 Receive
```
┌──────────────────────────────────────┐
│ ◀ Receive                            │
│                                      │
│         📡   Hold sender's phone     │
│              near this one           │
│                                      │
│         Waiting for tap...           │
│                                      │
│   ─ Last received: RM 12 (pending)   │
│   ─ Last received: RM 5  (settled)   │
└──────────────────────────────────────┘
```

### 4.6 AI Score Panel
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

Each flow names the source-of-truth doc + section for the *behavior* it depends on,
so no flow is orphaned.

### Flow F1 — Onboarding & device-key generation
**Trigger:** First app launch.
**Behavior owners:** [docs/03-token-protocol.md §Key gen](03-token-protocol.md), [docs/10-security-threat-model.md §Key lifecycle](10-security-threat-model.md), [docs/08-backend-api.md §POST /devices/register](08-backend-api.md).

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
**Behavior owners:** [docs/01-architecture.md §5.1](01-architecture.md), [docs/08-backend-api.md §GET /wallet/balance](08-backend-api.md).

```
1. App calls GET /wallet/balance with Cognito JWT
2. FC reads Tablestore.wallets[userId] → returns balance + version
3. App writes Drift cache with synced_at = now
4. UI shows "Online · synced 2s ago"
```

### Flow F3 — Going offline indicator
**Trigger:** ConnectivityResult changes to none, OR balance sync fails 3x.
**Behavior owners:** [docs/07-mobile-app.md §State machine](07-mobile-app.md).

```
1. App enters OFFLINE state
2. Banner shows "Offline · last sync N min"
3. Home replaces "available" with "safe offline"
4. AI scorer (TF Lite) runs locally to recompute safe_offline_balance
   inputs: cached balance, last_sync_age, recent tx velocity, time-of-day, day-of-week
5. Result clamped to min(cached_balance, model_output, hard_cap_per_policy)
6. User sees the lower number; pay button enforces it
```

### Flow F4 — Offline pay (sender's view)
**Trigger:** User on Pay screen, taps phone to receiver.
**Behavior owners:** [docs/03-token-protocol.md](03-token-protocol.md), [docs/07-mobile-app.md §HCE](07-mobile-app.md).

```
1. User enters amount (validated <= safe_offline_balance)
2. App requests user PIN/biometric (Keystore unlock)
3. App constructs token payload {tx_id=UUIDv7, sender_pub, receiver_pub*, amount,
   iat, exp=iat+72h, nonce, policy_version}
   * receiver_pub is read from peer via SELECT-AID exchange before payload
4. App signs with Ed25519 → JWS
5. NFC APDU exchange:
   - Phase A: SELECT AID (sender → receiver)
   - Phase B: receiver returns its pub_key
   - Phase C: sender sends signed JWS in chunks
   - Phase D: receiver returns ACK + receiver-side ack-signature
6. App writes to outbox (Drift): status=PENDING_SETTLEMENT
7. App locally decrements safe_offline_balance by amount
8. UI shows receipt
```

### Flow F5 — Offline receive (receiver's view)
**Trigger:** Receive screen open, phone tapped by sender.
**Behavior owners:** [docs/03-token-protocol.md](03-token-protocol.md).

```
1. HCE service handles SELECT AID, returns receiver_pub
2. Receives JWS chunks; reassembles
3. Verifies signature using sender_pub embedded in token
   - if pub_key not in local cache: still accept, mark as VERIFY_AT_SETTLEMENT
4. Verifies amount, exp, policy_version
5. Stores in inbox (Drift): status=PENDING_SETTLEMENT
6. Returns ack-signature (proof-of-receipt)
7. UI: "Received RM X.XX from …a3f4 — pending"
```

### Flow F6 — Back-online settlement
**Trigger:** Either party regains connectivity AND outbox/inbox non-empty.
**Behavior owners:** [docs/01-architecture.md §5.3](01-architecture.md), [docs/08-backend-api.md §POST /tokens/settle](08-backend-api.md).

```
1. App background worker batches up to 50 tokens
2. POST /tokens/settle with idempotency-key = sha256(batch)
3. FC validates batch shape → emits Alibaba EventBridge event
4. AWS Lambda consumes event, processes each token:
   a. Verify Ed25519 against pubkey from DynamoDB cache (refilled from OSS)
   b. Conditional put on nonce_seen → if exists → reject DUPLICATE
   c. Write token_ledger with status=SETTLED
   d. Update wallet balance via cross-cloud event back to Alibaba
5. Lambda response → Alibaba EventBridge → FC → mobile sees settled set
6. App moves tokens to history with status=SETTLED
7. Mobile Push notifies receiver "RM X.XX received from Faiz — settled"
```

### Flow F7 — Dispute a transaction
**Trigger:** User taps a settled txn in history → "Dispute".
**Behavior owners:** [docs/08-backend-api.md §POST /tokens/dispute](08-backend-api.md), [docs/10-security-threat-model.md](10-security-threat-model.md).

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
| Pay | amount > safe-offline | Disable confirm button, show inline hint |
| Pay | NFC disabled | Modal "Enable NFC in settings" with deeplink |
| Pay | tap timeout 30s | Cancel, allow retry |
| Receive | sender pubkey unknown | Accept + flag VERIFY_AT_SETTLEMENT (still safe — server verifies) |
| Settlement | partial failure | Successful tokens move; failed stay PENDING with attempt counter; exponential backoff |
| Onboarding | Keystore unavailable | Block onboarding, show device-not-supported page |

## 7. Accessibility

- All interactive elements ≥ 48 dp tap target.
- Color is not the only signal for online/offline (icon + text label).
- Screen-reader labels on all currency values (Malay + English locales).
- Vibration confirmation on NFC tap to support low-vision users.
