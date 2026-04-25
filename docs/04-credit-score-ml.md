---
name: 04-credit-score-ml
description: Credit-scoring ML pipeline — features, model, synthetic data, training on AWS, on-device + PAI-EAS inference, OTA distribution
owner: ML
status: ready
depends-on: [00-overview, 01-architecture]
last-updated: 2026-04-25
---

# Credit Score & Safe-Offline-Balance Model

## 1. What this model decides

For every user, output **`safe_offline_balance` ∈ [0, cached_balance]** — the maximum
amount the user can spend offline without significantly elevating overdraft / fraud
risk after settlement. This is the *enabling primitive* for offline pay; without it,
the system would have to either trust the cache (unsafe) or block offline pay.

It also outputs a `confidence_score ∈ [0,1]` and a per-user `policy_class ∈
{tier_basic, tier_standard, tier_trusted}`.

## 2. Two-segment policy (per `Idea.md`)

| Segment | Behavior |
|---|---|
| `<600 lifetime txns` | Manual offline-wallet model: user pre-loads a fixed amount; AI not used (bootstrap problem — not enough data). UI: "Reload offline wallet". |
| `≥600 lifetime txns` | AI model active: outputs `safe_offline_balance` dynamically. |

The 600 threshold is a soft demo number; production would tune it from data.

## 3. Features (input vector)

All features are computed from a rolling 90-day window of transactions. On-device,
we maintain a sliding aggregate so inference doesn't require the full history.

| # | Feature | Description |
|---|---|---|
| f01 | `tx_count_30d` | Number of transactions in last 30 days |
| f02 | `tx_count_90d` | Number in last 90 days |
| f03 | `avg_tx_amount_30d` | Mean MYR amount, 30 days |
| f04 | `median_tx_amount_30d` | Median, 30 days |
| f05 | `tx_amount_p95_30d` | 95th percentile |
| f06 | `unique_payees_30d` | Count of distinct payee user/merchant ids |
| f07 | `unique_payees_90d` | Same, 90 days |
| f08 | `payee_diversity_idx` | Shannon entropy of payee distribution |
| f09 | `reload_freq_30d` | Wallet reloads in last 30 days |
| f10 | `reload_amount_avg` | Mean reload amount |
| f11 | `days_since_last_reload` | Recency feature |
| f12 | `time_of_day_primary` | Hour bucket where user transacts most (0–23) |
| f13 | `weekday_share` | Share of txns on weekdays |
| f14 | `geo_dispersion_km` | Std-dev of distance from user centroid |
| f15 | `prior_offline_count` | How many offline txns historically |
| f16 | `prior_offline_settle_rate` | Of those, % that settled clean (no dispute, no double-spend) |
| f17 | `account_age_days` | Days since onboarding |
| f18 | `kyc_tier` | 0 / 1 / 2 |
| f19 | `last_sync_age_min` | Minutes since the *current* online sync (decay feature) |
| f20 | `device_attest_ok` | 0/1, whether attestation valid |

`f19` is the only feature evaluated *at inference time*; the rest are precomputed.

## 4. Label

Supervised target: `y = clip(safe_amount_observed, 0, cached_balance)` where
`safe_amount_observed` is derived from historical actuals — for each user, in retrospect,
the largest amount they could have spent offline without overdraft after the next
settlement, given their actual cached balance and reload events. In synthetic data,
we compute this directly from the simulated truth.

## 5. Model

- **Architecture:** Gradient-boosted regressor (XGBoost) with 200 trees, depth 6.
  Trained as a regression on `y` with monotonic constraints: monotonically *decreasing*
  in `last_sync_age_min` (the older the cache, the lower we trust it) and
  monotonically *increasing* in `account_age_days`, `prior_offline_settle_rate`.
- **Distillation to TF Lite:** the XGBoost model is converted to a TensorFlow surrogate
  (Treelite → TFLite) for on-device inference, capped at ~1.5 MB.
- **Calibration:** isotonic regression on a held-out set so output ≈ a conservative
  upper bound (we'd rather under-grant than over-grant).
- **Final clamp on device:** `safe_offline_balance = min(model_out, cached_balance,
  hard_cap_per_kyc_tier)` where the hard cap comes from server policy.

## 6. Synthetic data generator

Lives at `ml/synth/generate.py`. Produces `s3://tng-finhack-aws/synthetic/v1/users.parquet`
and `transactions.parquet`.

### 6.1 Schema
```python
users.parquet columns:
  user_id (str)
  signup_date (datetime)
  kyc_tier (int)
  archetype (str: "rural_merchant" | "gig_worker" | "student" | "urban_office")
  monthly_income_myr (float)
  centroid_lat, centroid_lon (float)

transactions.parquet columns:
  tx_id (str)
  user_id (str)
  ts (datetime)
  amount_myr (float)
  payee_id (str)
  is_reload (bool)
  is_offline (bool)
  settled_clean (bool)  # null if not yet settled
  lat, lon (float)
```

### 6.2 Generator design
- 10,000 synthetic users, weighted across archetypes.
- 90-day history per user, ~100 txns/month average for high-activity archetypes.
- Reload events follow archetype-conditional Poisson processes.
- Spending: log-normal amounts, archetype-conditional payee preferences.
- Offline events: 5–15% of txns, increased for `rural_merchant` archetype.
- Inject 1% adversarial cases: simulated double-spend attempts, expired tokens, forged
  signatures (these become *negative* training signal for fraud-side scoring later;
  for the safe-balance regressor we just exclude them or flag).

### 6.3 Sample command
```
python ml/synth/generate.py \
  --num-users 10000 \
  --days 90 \
  --out s3://tng-finhack-aws/synthetic/v1/
```

## 7. Training pipeline (AWS)

```
S3 (synth/v1/) ──> SageMaker Processing (feature engineering, parquet→csv)
                ──> SageMaker Training (XGBoost built-in)
                ──> Model registry entry (status=PendingApproval)
                ──> Manual approve in registry → triggers EventBridge "model.published"
                ──> Step Functions:
                       1) export to TF Lite (Treelite → TFLite converter Lambda)
                       2) sigstore sign artifact (cosign Lambda)
                       3) copy artifact to Alibaba OSS via boundary call (B1)
                       4) bump policy_version in Tablestore
                       5) fanout Mobile Push notification
```

Pipeline IaC: `infra/aws/sagemaker-pipeline/*.tf`. See [docs/05-aws-services.md](05-aws-services.md).

## 8. On-device inference

- Input: 20-element float vector (features above), built from local Drift aggregates +
  current `last_sync_age_min`.
- Library: `tflite_flutter ^0.10`.
- Model file: `assets/models/credit-v{n}.tflite` initially; later versions sideloaded
  from Alibaba OSS into app local storage.
- Inference time target: < 30 ms on a midrange Android device.
- The model file is content-addressed by sha256 + sigstore-signed; loader rejects
  on signature mismatch (defense against tampered OTA).

Pseudo-code:
```dart
final out = await tflite.run(features);
final modelOut = out[0];
final safeBalance = [modelOut, cachedBalance, hardCap].reduce(min);
state.safeOfflineBalance = safeBalance.clamp(0, cachedBalance);
```

## 9. Online refresh-score endpoint (Alibaba PAI-EAS)

Container at `ml/eas/Dockerfile`:
- Flask + xgboost + numpy.
- Loads the *original* XGBoost model (not the TF Lite one — better accuracy and we have
  network) from **Alibaba OSS** at `oss://tng-finhack-models/credit/v{n}/model.pkl`.
  OSS is the **single authoritative runtime source** for EAS; the AWS S3 path
  (`s3://tng-finhack-aws-models/...`) is the *origin* during publish but never read
  at inference time — it's mirrored to OSS by the publish pipeline (boundary B1).
  EAS fetches once at warmup and caches in-container.
- `POST /score`:
  ```json
  { "user_id": "u_8412",
    "features": { "f01": ..., "f20": ... },
    "policy": "v3.2026-04-22" }
  ```
  →
  ```json
  { "safe_offline_balance_myr": "120.00",
    "confidence": 0.87,
    "policy": "v3.2026-04-22",
    "computed_at": 1745603421 }
  ```
- Mobile calls this when online, to override the on-device estimate with a fresher one.
- Falls back to on-device estimate if endpoint times out (>800ms).

## 10. OTA distribution

Path: SageMaker → S3 model registry → boundary call B1 → Alibaba OSS bucket
`tng-finhack-models/credit/v{n}/model.tflite` and `model.json` (manifest).

Mobile flow:
1. `GET /score/policy` returns latest policy with download URL + sha256 + signature.
2. App background-downloads while on Wi-Fi.
3. Verifies sigstore signature against bundled root.
4. Atomically swaps the active model.
5. Old model retained for 7 days as rollback.

Rollout safety:
- Initial rollout to 1% of users (random shard).
- If `mismatch_rate` (on-device vs server refresh) jumps > threshold, server pulls the
  policy back to previous version.

## 11. Metrics and monitoring

| Metric | Target |
|---|---|
| RMSE on holdout | < RM 30 |
| Calibration: 95th percentile predicted ≥ actual | true |
| Inference latency on-device p95 | < 30 ms |
| Refresh-score endpoint p95 | < 250 ms |
| Mismatch rate (device vs server, same features) | < 5% |
| % of offline txns later disputed | < 1% |

CloudWatch (training pipeline) + CloudMonitor (PAI-EAS) dashboards. Demo screens show
the policy version and last training time on the AI Score Panel.

## 12. Out of scope / future work

- Personal LLMs for transaction explanation ("why did your safe balance drop?").
- Federated training across devices (privacy uplift; complexity for hackathon).
- Risk-based pricing (charging spread for risky offline spend) — explicitly avoided
  for inclusion track.
