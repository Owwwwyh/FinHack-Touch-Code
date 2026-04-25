---
name: 11-demo-and-test-plan
description: Demo storyline (4 minutes), test scenarios, manual NFC peer-test checklist
owner: QA
status: ready
depends-on: [02-user-flows, 03-token-protocol, 04-credit-score-ml, 07-mobile-app]
last-updated: 2026-04-25
---

# Demo & Test Plan

## 1. Demo storyline — 4 minutes flat

**Setup on stage:**
- Two Pixel 8 phones: `Faiz` (sender) and `Aida` (merchant/receiver).
- Big-screen mirror of Faiz's phone via scrcpy.
- Live admin dashboard: Alibaba CloudMonitor + AWS CloudWatch dual view.
- Both phones online at start.

| min | Action | What viewer sees | What's happening behind |
|---|---|---|---|
| 0:00 | "Meet Faiz, a Grab rider on prepaid data." Open Faiz's app. | Home screen, online, balance RM 248.50, **safe offline RM 120**. | Cognito JWT + GET balance from Alibaba FC. |
| 0:25 | Tap AI Score Panel. | Shows features driving the safe balance (txn velocity, last sync age). | TF Lite ran on-device. |
| 0:50 | "His data dies underground." Toggle airplane mode on Faiz's phone. | Banner flips to **Offline · last sync 0 min**. UI dims. | Connectivity service triggers OFFLINE state. |
| 1:10 | "Aida is offline too." Airplane on Aida's phone. Aida opens Receive. | Aida shows "Hold sender's phone near this one". | HCE service active. |
| 1:25 | Faiz hits PAY → enters RM 8.50 → biometric → tap. | "RM 8.50 to …a3f4 — Authorize". Tap. Confirmation animation. | JWS built, signed via Keystore, NFC APDU exchanged. |
| 1:55 | Aida shows "Received RM 8.50 — pending settlement". | Inbox row appears. | Drift insert. Both still offline. |
| 2:15 | "Now, what happens when the network comes back?" Toggle airplane off Aida only. | Banner returns to Online. Push notification: "RM 8.50 settled from Faiz". | Outbox upload via Alibaba FC → cross-cloud event → AWS Lambda settle → DynamoDB conditional put → return event → Tablestore wallet update → Mobile Push. |
| 2:35 | Switch to admin dashboard. Show CloudWatch settle metrics. | New entry in `tng_token_ledger`, `nonce_seen` row. | Live AWS calls. |
| 2:50 | "What if someone tries to double-spend?" Trigger the prepared replay (re-submit same JWS via curl). | Dashboard shows REJECTED reason=NONCE_REUSED. | Conditional put fails, returns reject. |
| 3:10 | "Why is this fair?" Show the AI panel: safe balance dropped to RM 111.50 after the offline spend. | Updated number. | Local recomputation + score refresh on next online. |
| 3:25 | Faiz toggles airplane off too. | Outbox flushes; UI shows ✓ for the original tx. | Same settle path; this time idempotency-key cache returns the prior result. |
| 3:45 | "We use AWS for ML and ledger, Alibaba for APAC inference and wallet APIs — both clouds, both purposeful." Show the boundary-call table image. | Brief pitch. | — |
| 4:00 | Done. | "Pay anywhere — even when the network can't." | — |

## 2. Demo prep checklist

- [ ] Both Pixel devices flashed with the demo APK; signing key generated and registered.
- [ ] Admin user logged in for both wallets, balances seeded (Faiz RM 248.50, Aida RM 0).
- [ ] Pre-warm PAI-EAS endpoint (one ping 60s before demo).
- [ ] Pre-warm AWS Lambda (one settle of an empty batch).
- [ ] CloudWatch dashboard `tng-finhack` open, filtered to last 5 min.
- [ ] CloudMonitor `tng-finhack-ops` open.
- [ ] scrcpy mirroring tested.
- [ ] Replay-attack curl command pre-staged with the prior-tx JWS.
- [ ] Backup hotspot phone in case of WiFi loss for the cross-cloud event roundtrip.
- [ ] Spare APK on USB stick.

## 3. Failure recovery on stage

| If… | Do… |
|---|---|
| NFC tap fails | Bring phones closer (≤ 2cm); say "let's try once more" — script tolerates one retry. |
| Settlement times out | Show that the token is still safely in the outbox; segue into "and crucially, this is what makes the system robust — we own the proof". |
| AWS region briefly slow | The 1.5s sync timeout in FC will return 202 Accepted; show the polling endpoint as a feature ("settled async"). |
| Both phones won't NFC | Switch to recorded video clip (have one ready). |

## 4. Test scenarios (functional)

Scenario IDs map to test files under `mobile/test/integration/` and `backend/tests/`.

| ID | Scenario | Expected | Owner |
|---|---|---|---|
| TS-01 | Online happy path: pay merchant online | Standard online flow; settled instantly | mobile + backend |
| TS-02 | Offline-online: sender airplane, receiver online | Token signed offline, settled when sender comes back | mobile + backend |
| TS-03 | Offline-offline: both airplane | Token exchanged, settled when either comes back | mobile + backend |
| TS-04 | Replay attack at settlement | Second submission rejected `NONCE_REUSED` | backend |
| TS-05 | Tampered JWS amount | Settlement rejects `BAD_SIGNATURE` | backend |
| TS-06 | Expired token | Rejects `EXPIRED_TOKEN` | backend |
| TS-07 | Unknown sender kid | Rejects `UNKNOWN_KID`; warmer pulls then succeeds on retry | backend |
| TS-08 | Receiver pubkey unknown to sender | Sender skips local pubkey lookup, signs with provided pub from APDU; settlement still validates | mobile |
| TS-09 | Amount > safe-offline | App blocks with inline hint; pay button disabled | mobile |
| TS-10 | Score refresh online: PAI-EAS returns conservative number; UI updates | mobile + ML |
| TS-11 | Score refresh timeout: client falls back to on-device estimate | mobile |
| TS-12 | OTA model swap: new policy version published, app downloads + verifies signature, swaps atomically | mobile + ML |
| TS-13 | OTA poisoning: tampered tflite published; signature check fails; app keeps old model | mobile |
| TS-14 | Dispute: user opens dispute on a settled tx; ledger marks DISPUTED | mobile + backend |
| TS-15 | Lost device: revoke kid; pre-revocation tokens still settle; new tokens rejected | backend |
| TS-16 | Cross-cloud webhook tampered HMAC | Rejected | backend |
| TS-17 | DynamoDB throttled at peak | Lambda retries with backoff; demo throughput maintained | backend |
| TS-18 | Onboarding on a non-StrongBox device | Falls back to TEE Keystore; attestation chain still verifies | mobile |
| TS-19 | Account with <600 lifetime txns | App offers manual offline-wallet reload, AI panel shows "not eligible yet" | mobile + backend |
| TS-20 | Account with >=600 lifetime txns | AI panel computes dynamic safe balance | mobile + ML |

## 5. Manual NFC peer-test checklist

To run on each demo device pair before any practice:

- [ ] Both devices on Android 14+, NFC on, screen unlocked
- [ ] App installed and onboarded with distinct user IDs
- [ ] Faiz on Pay screen, Aida on Receive screen
- [ ] Tap and hold ~1.5s
- [ ] Faiz: receipt screen shows expected amount
- [ ] Aida: inbox row appears with expected amount
- [ ] Switch roles, repeat
- [ ] Test with one phone in case + thicker case (some attenuate NFC)
- [ ] Test with screen at 50% brightness (rule out power-throttling NFC)
- [ ] Verify ack-signature persisted in Drift (`adb shell run-as com.tng.finhack ...`)

## 6. Performance targets verification

| Metric | Target | How to measure |
|---|---|---|
| Tap-to-receipt | < 2s | stopwatch on demo build with logging |
| Online balance fetch p95 | < 800ms | k6 script against deployed endpoint |
| Settle 50-token batch p95 | < 3s | Load test: send 100 batches via `backend/tests/load.k6.js` |
| TF Lite inference | < 30ms | flutter_test perf benchmark |
| PAI-EAS p95 | < 250ms | EAS metric |

## 7. Pitch deck ↔ doc mapping (so the deck stays consistent)

| Slide | Sourced from |
|---|---|
| Problem | [docs/00-overview.md §1](00-overview.md) |
| Solution | [docs/00-overview.md §2](00-overview.md) |
| Architecture diagram | [docs/01-architecture.md §1](01-architecture.md) |
| AI explainer | [docs/04-credit-score-ml.md §3, §5](04-credit-score-ml.md) |
| Multi-cloud rationale | [docs/01-architecture.md §3, §4](01-architecture.md) |
| Live demo | this doc §1 |
| Roadmap | [docs/00-overview.md §4 + docs/10-security-threat-model.md §10](10-security-threat-model.md) |
