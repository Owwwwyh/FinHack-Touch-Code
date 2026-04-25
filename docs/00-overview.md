---
name: 00-overview
description: Problem, target user, value proposition, scope, success metrics, FINHACK criteria mapping
owner: PM
status: ready
depends-on: []
last-updated: 2026-04-26
---

# Project Overview

## 1. Problem

Cashless adoption in Malaysia (and broader APAC) plateaus where connectivity is unreliable:
rural areas, transit underground, basements, packed events, and disaster scenarios.
A user with a TNG balance still falls back to physical cash because the wallet *cannot
transact without a network*. That same friction is amplified for the **financially
underserved**: gig workers, hawkers, students with prepaid data, and rural micro-merchants.

The cash-comfort wedge from the speaker notes is real: *"How do we involve those still
using cash, who feel uncomfortable going cashless?"* The honest answer is: stop forcing
them online to spend their own money.

## 2. Solution

A TNG e-wallet extension that supports **offline NFC payments** with three pillars:

1. **Cached + sync'd balance** with a 10-minute confidence window (per `Idea.md`).
2. **AI-derived safe offline balance** — an on-device model decides how much of the
   cached balance can be spent offline without overdraft risk, based on the user's
   transaction history. Ground-truth-tracked when the device returns online.
3. **Signed token settlement** — every offline payment produces an Ed25519-signed JWS
   token exchanged via NFC. When either party returns online, tokens are submitted to
   the settlement service, which deducts the sender and credits the receiver.

## 3. Target user

| Segment | Why this fits |
|---|---|
| Rural micro-merchants (warungs, pasar stalls) | Often in low-coverage zones; receiving offline cuts cash handling. |
| Gig workers (delivery, ride-hail) | Frequent dead-zones; need the next pickup not blocked on connectivity. |
| Students/youth on prepaid data | Run out of data mid-month; need wallet to keep working. |
| Travelers / tourists | Roaming gaps. |
| Disaster-relief contexts | Network down, but commerce must continue. |

These segments overlap heavily with the **Financial Inclusion** track's "underserved
users including unbanked users and low-income communities" definition.

## 4. Scope

### In scope (build)
- Flutter Android app with NFC HCE/reader, on-device TF Lite model, secure key storage.
- Multi-cloud backend: settlement (AWS), wallet API (Alibaba), inference (Alibaba).
- ML pipeline: synthetic data generator → SageMaker training → TF Lite export → Alibaba OSS distribution → on-device inference.
- Two-phone live demo with airplane-mode toggle.
- IaC (Terraform / ROS) for both clouds.

### Out of scope (won't build, will document)
- iOS support (HCE limitations — Android-first only).
- Production-grade KYC and AML (stub flow only).
- Real fiat clearing into bank rails.
- Merchant dashboard + analytics UI (not part of the MVP build).

## 5. Success metrics for the demo

| Metric | Target |
|---|---|
| End-to-end offline transaction (sender airplane-mode, receiver airplane-mode) → successful settlement on reconnect | ✅ live, on-stage |
| AI safe-offline balance updates after 5 demo transactions, visibly reflecting transaction velocity | ✅ visible in app UI |
| Double-spend attempt rejected at settlement | ✅ surfaced in admin view |
| Both clouds invoked during the 4-min demo (logs visible) | ≥ 3 AWS↔Alibaba boundary calls demonstrated |
| Cold-cache balance fetch p95 | < 800 ms |
| Offline NFC tap-to-confirm | < 2 s |

## 6. Mapping to FINHACK judging criteria

| Criterion | Where addressed |
|---|---|
| **1. AI & Intelligent Systems** | [docs/04-credit-score-ml.md](04-credit-score-ml.md) — AI replaces a rules-based limit; the safe offline balance is a learned function of behavior and is the *core enabling mechanism* for offline pay. |
| **2. Technical Implementation** | [docs/01-architecture.md](01-architecture.md), [docs/03-token-protocol.md](03-token-protocol.md), [docs/10-security-threat-model.md](10-security-threat-model.md). Real cryptographic non-repudiation, idempotent settlement, hardware-backed keys. |
| **3. Multi-Cloud Service Usage** | [docs/01-architecture.md](01-architecture.md) §"AWS↔Alibaba boundary calls", [docs/05-aws-services.md](05-aws-services.md), [docs/06-alibaba-services.md](06-alibaba-services.md). Each cloud carries a *purposeful* workload; not duplicated. |
| **4. Impact & Feasibility** | This doc §1–§3 plus [docs/11-demo-and-test-plan.md](11-demo-and-test-plan.md). Realistic for TNG's existing user base; modest delta to ship. |
| **5. Documentation & Teamwork** | [docs/11-demo-and-test-plan.md](11-demo-and-test-plan.md) demo storyline, [docs/12-build-tasks.md](12-build-tasks.md) execution plan, this doc set as the shared build artifact. |

## 7. Ship-first artifacts

| Artifact | Source |
|---|---|
| Product overview | This doc + `Idea.md` |
| Working demo flow | [docs/11-demo-and-test-plan.md](11-demo-and-test-plan.md) |
| Deployment path and blockers | [docs/13-deployment.md](13-deployment.md) |
| Repository and test suite | This repo |

## 8. Open questions / explicit decisions

| Topic | Decision | Rationale |
|---|---|---|
| Client platform | Flutter, Android-first | HCE works on Android; iOS HCE restricted by Apple. |
| ML deployment | On-device TF Lite + Alibaba PAI-EAS for refresh | Offline scoring requires on-device; cloud refresh keeps it tuned. |
| Token signature | Ed25519 in Android Keystore | Hardware-backed non-repudiation, small signatures, fast. |
| Settlement ledger | DynamoDB on AWS | Strong key consistency, idempotency naturally modeled. |
| User/wallet store | Tablestore on Alibaba | Regional data residency for APAC users. |
| Training data | Synthetic | Hackathon constraint; spec in [docs/04-credit-score-ml.md](04-credit-score-ml.md). |

## 9. Inspiration

- EMV offline data authentication (ODA) and offline PIN flows.
- Visa Tokenization Service & Apple Pay's signed transaction tokens.
- Project Bakong (Cambodia) for inclusive payments.
- mPesa for last-mile mobile money adoption.
- Lightning Network for trust-minimized async settlement (token chaining ideas only;
  we don't run a payment channel network).
