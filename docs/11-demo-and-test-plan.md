---
name: 11-demo-and-test-plan
description: Demo storyline (4 minutes), test scenarios, manual NFC peer-test checklist — merchant-initiated two-tap flow
owner: QA
status: ready
depends-on: [02-user-flows, 03-token-protocol, 04-credit-score-ml, 07-mobile-app]
last-updated: 2026-04-25
---

# Demo & Test Plan

## 1. Demo storyline — 4 minutes flat

**Setup on stage:**
- Two Pixel 8 phones: `Faiz` (payer/rider) and `Aida` (merchant/receiver).
- Big-screen mirror of **Aida's** phone first, then switch to Faiz's for the confirm.
- Live admin dashboard: Alibaba CloudMonitor + AWS CloudWatch dual view.
- Both phones online at start.

| min | Action | What viewer sees | What's happening behind |
|---|---|---|---|
| 0:00 | "Meet Faiz, a Grab rider on prepaid data." Open Faiz's app. | Home screen, online, balance RM 248.50, **safe offline RM 120**. | Cognito JWT + GET balance from Alibaba FC. |
| 0:20 | Tap AI Score Panel. | Shows features driving the safe balance (txn velocity, last sync age). | TF Lite ran on-device. |
| 0:40 | "His data dies underground." Toggle airplane mode on Faiz's phone. | Banner flips to **Offline · last sync 0 min**. UI dims slightly. | Connectivity service triggers OFFLINE state. |
| 1:00 | "Aida is offline too — she runs a hawker stall underground." Toggle airplane on Aida's phone. | Aida's home shows offline, safe offline balance visible. | Same offline state. |
| 1:10 | "Aida enters the amount — like a POS terminal." Aida opens **Request Payment**, enters RM 8.50, memo "Nasi lemak + teh tarik". | Aida's screen: numpad + amount field filled. | — |
| 1:25 | "She taps her phone to Faiz's — tap 1." Aida taps to Faiz. | Brief NFC animation. Aida: "Request sent, waiting for Faiz". Faiz: **Pay Confirm screen pops up automatically**: "Pay RM 8.50 to Aida Stall — Nasi lemak + teh tarik". | HCE SELECT AID → Aida reader reads Faiz pub → Aida sends payment request JSON → Faiz HCE fires EventChannel → Flutter navigates to confirm. |
| 1:45 | Mirror switches to Faiz's phone. "Faiz sees the request. He reviews and approves." Faiz taps [Authorize with PIN]. | Biometric prompt. | Android Keystore unlock; JWS signed with Ed25519 immediately after. |
| 2:00 | "Now Faiz taps back — tap 2 — to complete the payment." Faiz taps to Aida. | Faiz: "Payment sent — pending settlement". Aida: "Received RM 8.50 from Faiz — pending". | Faiz reader → SELECT AID → Aida HCE → JWS chunks sent → GET ACK → ack-sig returned → outbox + inbox written. |
| 2:20 | "Both phones are still offline. The tokens are signed, stored, waiting." Show both pending screens. | Faiz outbox: 1 pending. Aida inbox: 1 pending. | Drift rows. No network needed. |
| 2:35 | "Now Aida's data comes back." Toggle airplane off on Aida's phone only. | Aida: banner flips Online. Push notification: "RM 8.50 settled from Faiz". | Aida's outbox/inbox worker fires → POST /tokens/settle to Alibaba FC → cross-cloud event → AWS Lambda settle → DynamoDB conditional put → return event → Tablestore wallet update → Mobile Push. |
| 2:55 | Switch to admin dashboard. Show CloudWatch settle metrics. | New entry in `tng_token_ledger`, `nonce_seen` row. | Live AWS calls. |
| 3:10 | "What if someone tries to double-spend?" Trigger the prepared replay (re-submit same JWS via curl). | Dashboard shows REJECTED reason=NONCE_REUSED. | Conditional put fails. |
| 3:25 | "The AI knows Faiz spent RM 8.50 offline." Show Faiz's AI panel. | Safe offline dropped: RM 120 → RM 111.50. | Local recomputation on next TF Lite run. |
| 3:40 | Faiz toggles airplane off. | Faiz's outbox flushes; UI shows ✓. Idempotency cache returns prior result. | Same settle path, idempotency-key hit. |
| 3:50 | "AWS handles the ledger and ML training. Alibaba handles APAC inference and wallet APIs. Two clouds, each purposeful." Show boundary-call table or live logs. | Why the cloud split is real. | — |
| 4:00 | Done. | "Pay anywhere — even when the network can't." | — |

## 2. Demo prep checklist

- [ ] Both Pixel devices flashed with the demo APK; signing keys generated and registered.
- [ ] Admin user logged in for both wallets, balances seeded (Faiz RM 248.50, Aida RM 0).
- [ ] Pre-warm PAI-EAS endpoint (one ping 60s before demo).
- [ ] Pre-warm AWS Lambda (one settle of an empty batch).
- [ ] CloudWatch dashboard `tng-finhack` open, filtered to last 5 min.
- [ ] CloudMonitor `tng-finhack-ops` open.
- [ ] scrcpy mirroring tested — start on Aida's phone for tap 1, switch to Faiz for confirm.
- [ ] Replay-attack curl command pre-staged with the prior-tx JWS.
- [ ] Backup hotspot phone in case of WiFi loss for the cross-cloud event roundtrip.
- [ ] Spare APK on USB stick.
- [ ] Aida's "Request Payment" screen opened in advance with RM 8.50 pre-entered to reduce live typing.

## 3. Failure recovery on stage

| If… | Do… |
|---|---|
| Tap 1 fails (Aida → Faiz) | Bring phones closer (≤ 2cm); Aida taps again — request is idempotent on `request_id`. Say "let's try once more". |
| Faiz's confirm screen doesn't pop | Check NFC is enabled on Faiz's phone; worst case, Faiz manually opens Pay from Home — the request is already cached. |
| Tap 2 fails (Faiz → Aida) | Faiz still has JWS in memory; tap again within the 5-min window. |
| Settlement times out after Aida goes online | Token is safely in Aida's inbox; segue into "and this is what makes it robust — the proof lives on the device until the network is ready". |
| AWS region briefly slow | FC 1500ms timeout returns 202 Accepted; show polling endpoint as a feature ("settled async"). |
| Both phones won't NFC | Switch to recorded video clip (have one ready). |

## 4. Test scenarios (functional)

Scenario IDs map to test files under `mobile/test/integration/` and `backend/tests/`.

| ID | Scenario | Expected | Owner |
|---|---|---|---|
| TS-01 | Online happy path: Aida requests, Faiz confirms, both online | Full two-tap flow; settled immediately on reconnect (both already online) | mobile + backend |
| TS-02 | Offline-offline both taps: Aida and Faiz both airplane, complete two taps, Aida reconnects | Token exchanged offline; settled when Aida reconnects | mobile + backend |
| TS-03 | Offline tap 1 + tap 2, Faiz reconnects first | Token settled from Faiz's outbox | mobile + backend |
| TS-04 | Replay attack at settlement | Second submission rejected `NONCE_REUSED` | backend |
| TS-05 | Tampered JWS amount | Settlement rejects `BAD_SIGNATURE` | backend |
| TS-06 | Expired token | Rejects `EXPIRED_TOKEN` | backend |
| TS-07 | Unknown sender kid | Rejects `UNKNOWN_KID`; warmer pulls then succeeds on retry | backend |
| TS-08 | Receiver pub mismatch at tap 2 | Faiz's app detects pub mismatch on SELECT AID response; cancels; shows error | mobile |
| TS-09 | Amount > safe-offline | Faiz's Pay Confirm shows disabled authorize button + inline hint | mobile |
| TS-10 | Payment request expired (Faiz takes > 5 min between taps) | Faiz's app shows "Request expired"; Aida resends with new request_id | mobile |
| TS-11 | Score refresh online: PAI-EAS returns conservative number; UI updates | mobile + ML |
| TS-12 | Score refresh timeout: client falls back to on-device estimate | mobile |
| TS-13 | OTA model swap: new policy version published, app downloads + verifies signature, swaps atomically | mobile + ML |
| TS-14 | OTA poisoning: tampered tflite published; signature check fails; app keeps old model | mobile |
| TS-15 | Dispute: user opens dispute on a settled tx; ledger marks DISPUTED | mobile + backend |
| TS-16 | Lost device: revoke kid; pre-revocation tokens still settle; new tokens rejected | backend |
| TS-17 | Cross-cloud webhook tampered HMAC | Rejected | backend |
| TS-18 | DynamoDB throttled at peak | Lambda retries with backoff; demo throughput maintained | backend |
| TS-19 | Onboarding on a non-StrongBox device | Falls back to TEE Keystore; attestation chain still verifies | mobile |
| TS-20 | Account with <600 lifetime txns | App offers manual offline-wallet reload, AI panel shows "not eligible yet" | mobile + backend |
| TS-21 | Account with >=600 lifetime txns | AI panel computes dynamic safe balance | mobile + ML |

> Note: TS-01..TS-03 replace the original TS-01..TS-03 to reflect the merchant-initiated
> two-tap flow. TS-08, TS-09, TS-10 are new scenarios specific to this flow.
> TS-19..TS-21 renumbered from original TS-18..TS-20.

## 5. Manual NFC peer-test checklist

To run on each demo device pair before any practice:

**Tap 1 (Aida → Faiz):**
- [ ] Both devices on Android 14+, NFC on, screen unlocked
- [ ] Aida on Request Payment screen with amount entered
- [ ] Faiz on Home screen (no action needed — HCE is always running)
- [ ] Tap and hold ~1.5s
- [ ] Aida: screen transitions to "Request sent — waiting for Faiz"
- [ ] Faiz: Pay Confirm screen appears automatically with correct amount + memo

**Tap 2 (Faiz → Aida):**
- [ ] Faiz taps [Authorize with PIN] → biometric clears
- [ ] Faiz taps to Aida's phone
- [ ] Faiz: receipt screen shows "Payment sent — pending"
- [ ] Aida: "Received RM 8.50 — pending" appears

**Additional checks:**
- [ ] Switch roles, repeat (Faiz requests, Aida pays)
- [ ] Test with one phone in case + thicker case (some attenuate NFC)
- [ ] Test with screen at 50% brightness (rule out power-throttling NFC)
- [ ] Verify ack-signature persisted in Drift (`adb shell run-as com.tng.finhack ...`)
- [ ] Verify payment request expires after 5 minutes if not completed

## 6. Performance targets verification

| Metric | Target | How to measure |
|---|---|---|
| Tap 1 (request delivery, both phones) | < 1.5s | stopwatch; NFC session open + close |
| Tap 2 (JWS + ack, both phones) | < 2s | stopwatch on demo build with logging |
| Pay Confirm screen appears after tap 1 | < 0.5s after NFC session close | logcat timing |
| Online balance fetch p95 | < 800ms | k6 script against deployed endpoint |
| Settle 50-token batch p95 | < 3s | Load test: 100 batches via `backend/tests/load.k6.js` |
| TF Lite inference | < 30ms | flutter_test perf benchmark |
| PAI-EAS p95 | < 250ms | EAS metric |
