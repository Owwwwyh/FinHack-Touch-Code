# ML Pipeline: Credit-Score Safe Offline Balance Model

TNG Finhack Phase 2 machine learning pipeline for credit-scoring and safe offline balance estimation.

**Documentation**: See [docs/04-credit-score-ml.md](../docs/04-credit-score-ml.md) for model architecture, features, and training strategy.

## Overview

The model outputs a `safe_offline_balance` for each user — the maximum amount they can spend offline without significantly increasing overdraft/fraud risk. This enables the core offline-payment feature.

**Model Details**:

- **Algorithm**: XGBoost regressor (200 trees, depth 6)
- **Input**: 20 features computed from 90-day transaction history
- **Output**: `safe_offline_balance ∈ [0, cached_balance]`
- **Inference targets**:
  - On-device: TF Lite (~1.5 MB), < 30 ms latency
  - Server: PAI-EAS (Alibaba), < 250 ms latency

## Directory Structure

```
ml/
├── synth/
│   ├── generate.py              # Synthetic data generator (10k users, 90d history)
│   ├── gen_test_vectors.py      # JWS test vector generator
│   └── generate_test_vectors.py # Alternative test vector generation
├── train.py                      # XGBoost training pipeline
├── requirements.txt              # Python dependencies
├── models/                       # Trained model artifacts
│   └── credit-v1.pkl            # XGBoost model (serialized)
├── test-vectors/                # JWS test vectors
│   ├── token-001-valid.jws
│   ├── token-002-expired.jws
│   └── ... (6 total)
├── eas/                         # Alibaba PAI-EAS container
│   └── Dockerfile               # Flask + XGBoost inference
└── README.md                    # This file
```

## Quick Start

### 1. Install dependencies

```bash
pip install -r requirements.txt
```

### 2. Generate synthetic training data

```bash
python ml/synth/generate.py \
  --num-users 10000 \
  --days 90 \
  --out /tmp/ml/synthetic/v1
```

**Output**:

- `/tmp/ml/synthetic/v1/users.parquet` (10k users)
- `/tmp/ml/synthetic/v1/transactions.parquet` (~600k transactions)
- File sizes: ~50 MB each

**User archetypes**: rural_merchant, gig_worker, student, urban_office (weighted distribution)

### 3. Train model

```bash
python ml/train.py \
  --users /tmp/ml/synthetic/v1/users.parquet \
  --transactions /tmp/ml/synthetic/v1/transactions.parquet \
  --output-model /tmp/ml/models/credit-v1.pkl \
  --output-metrics /tmp/ml/metrics.json
```

**Output**:

- `/tmp/ml/models/credit-v1.pkl` (XGBoost model, ~500 KB)
- `/tmp/ml/metrics.json` (training metrics)

**Expected metrics** (on synthetic data):

- Test RMSE: ~RM 20–30
- Test R²: > 0.5
- Features: f01–f20 (20 total)

### 4. Generate test vectors

```bash
python ml/synth/gen_test_vectors.py
```

**Output**: 6 `.jws` files in `ml/test-vectors/`

- token-001-valid.jws: Valid token, exp = now + 72h
- token-002-expired.jws: Expired (exp < now)
- token-003-bad-sig.jws: Tampered signature
- token-004-missing-nonce.jws: Missing required field
- token-005-tampered-amount.jws: Amount changed after signing
- token-006-unknown-kid.jws: Unknown device key ID

## Features (f01–f20)

All computed from rolling 90-day transaction window:

| #   | Name                      | Description                                                |
| --- | ------------------------- | ---------------------------------------------------------- |
| f01 | tx_count_30d              | Transactions in last 30 days                               |
| f02 | tx_count_90d              | Transactions in last 90 days                               |
| f03 | avg_tx_amount_30d         | Mean MYR amount, 30d                                       |
| f04 | median_tx_amount_30d      | Median MYR amount, 30d                                     |
| f05 | tx_amount_p95_30d         | 95th percentile, 30d                                       |
| f06 | unique_payees_30d         | Distinct payees, 30d                                       |
| f07 | unique_payees_90d         | Distinct payees, 90d                                       |
| f08 | payee_diversity_idx       | Shannon entropy of payee distribution                      |
| f09 | reload_freq_30d           | Wallet reloads, 30d                                        |
| f10 | reload_amount_avg         | Average reload amount                                      |
| f11 | days_since_last_reload    | Recency feature                                            |
| f12 | time_of_day_primary       | Primary transaction hour (0–23)                            |
| f13 | weekday_share             | % of transactions on weekdays                              |
| f14 | geo_dispersion_km         | Geographic std-dev in km                                   |
| f15 | prior_offline_count       | Historical offline transactions                            |
| f16 | prior_offline_settle_rate | % of offline txns that settled clean                       |
| f17 | account_age_days          | Days since onboarding                                      |
| f18 | kyc_tier                  | KYC tier (1/2/3)                                           |
| f19 | last_sync_age_min         | **Minutes since last online sync** (computed at inference) |
| f20 | device_attest_ok          | Device attestation valid (0/1)                             |

## Model Monotonic Constraints

The model enforces:

- **f19_last_sync_age_min**: monotonically decreasing (older cache → lower balance)
- **f17_account_age_days**: monotonically increasing (older account → higher balance)
- **f16_prior_offline_settle_rate**: monotonically increasing (better history → higher balance)

## Inference Paths

### On-Device (Flutter + TF Lite)

```dart
// Compute 19 local features + current sync age
features = computeLocalFeatures(user, txHistory);
features[19] = (now - lastSyncTime).inMinutes;

// Load TF Lite model from local storage
final output = await tflite.run(features); // < 30ms

// Safe balance = min(model_output, cached_balance, tier_hard_cap)
safeBalance = min(output[0], cachedBalance, hardCapPerTier);
```

### Server Refresh (PAI-EAS Alibaba)

```json
POST https://eas-endpoint.alibaba.com/score
{
  "user_id": "u_8412",
  "features": { "f01": 25, "f02": 45, ..., "f20": 1 },
  "policy": "v3.2026-04-22"
}

Response:
{
  "safe_offline_balance_myr": "120.00",
  "confidence": 0.87,
  "policy": "v3.2026-04-22",
  "computed_at": 1745603421
}
```

Mobile uses this to override on-device estimate when online. Falls back to on-device if timeout > 800 ms.

## AWS SageMaker Training Pipeline

(Placeholder — would run in AWS SageMaker)

```
1. S3: synthetic/v1/users.parquet + transactions.parquet
2. SageMaker Processing: Feature engineering, normalize
3. SageMaker Training: XGBoost built-in container
4. Model Registry: PendingApproval → Manual approve → ModelPublished event
5. Step Functions:
   - Export to TF Lite (Lambda)
   - Sign artifact (cosign Lambda)
   - Copy to Alibaba OSS (boundary B1, Lambda)
   - Bump policy_version in Tablestore
   - Push mobile notification
```

## Model Conversion (XGBoost → TF Lite)

(Not yet implemented; placeholder)

```bash
python ml/convert_tflite.py \
  --input /tmp/ml/models/credit-v1.pkl \
  --output ml/assets/models/credit-v1.tflite
```

Uses Treelite + tf.lite.TFLiteConverter. Target: ≤ 1.5 MB, < 30 ms inference.

## Testing

### Unit Tests

```bash
pytest ml/ -v
```

### Validation

```bash
# Check synthetic data
python -c "
import pandas as pd
df = pd.read_parquet('/tmp/ml/synthetic/v1/users.parquet')
print(f'Users: {len(df)}')
print(f'Archetypes: {df.groupby(\"archetype\").size()}')
"

# Check trained model
python -c "
import xgboost as xgb
model = xgb.XGBRegressor()
model.load_model('/tmp/ml/models/credit-v1.pkl')
print(f'Trees: {model.n_estimators}')
print(f'Features: {model.n_features_in_}')
"
```

## Cost (AWS SageMaker Demo)

| Step                                       | Cost (3 days) |
| ------------------------------------------ | ------------- |
| Data generation                            | free (local)  |
| SageMaker training (ml.m5.xlarge, ~30 min) | ~$0.30        |
| S3 storage                                 | ~$0.10        |
| **Total**                                  | **~$0.50**    |

## Integration with Phases

**Track A (Crypto)** ✅ JWS signing/verification, test vectors
**Track B** ✅ AWS + Alibaba infrastructure
**Track C** 🔲 ML pipeline (this track)
**Track D** (Mobile): Imports TF Lite model, calls on-device inference
**Track E** (Backend): PAI-EAS endpoint for online refresh, Lambda stores in Tablestore
**Track F** (E2E): Tests offline pay with safe balance enforcement

## Next Steps

1. **C2: XGBoost → TF Lite conversion** (Treelite, size ≤ 1.5 MB)
2. **C3: PAI-EAS endpoint** (Flask + XGBoost, Alibaba OSS model fetch)
3. **D2**: Mobile integration (load TF Lite, on-device inference)
4. **E3**: Refresh-score Lambda (calls PAI-EAS, caches result)

---

**Questions?** See [docs/04-credit-score-ml.md](../docs/04-credit-score-ml.md) for architecture and feature definitions.
