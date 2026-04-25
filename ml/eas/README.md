# PAI-EAS Score Service

This folder contains the missing server-side refresh-score container described in the
architecture docs.

## What it does

- Serves `POST /score` for the Alibaba online score-refresh path
- Accepts the same feature names the current FC caller sends
- Supports optional bearer-token auth via `EAS_TOKEN`
- Tries to load a model from `MODEL_PATH` or Alibaba OSS
- Falls back to the repo's existing heuristic scorer when no model is configured

## Request

```json
{
  "user_id": "demo_user",
  "policy": "v3.2026-04-22",
  "features": {
    "tx_count_30d": 10,
    "tx_count_90d": 25,
    "tx_amount_p95_30d": 40,
    "prior_offline_count": 12,
    "prior_offline_settle_rate": 0.96,
    "account_age_days": 400,
    "kyc_tier": 2,
    "last_sync_age_min": 3,
    "device_attest_ok": 1
  }
}
```

## Response

```json
{
  "safe_offline_balance_myr": "120.00",
  "confidence": 0.87,
  "policy": "v3.2026-04-22",
  "computed_at": "2026-04-26T00:00:00+00:00"
}
```

## Local run

```bash
pip install -r ml/eas/requirements.txt
python ml/eas/app.py
```

The service listens on `http://localhost:8080`.

## Docker build

```bash
docker build -f ml/eas/Dockerfile -t tng-credit-score-refresh .
docker run --rm -p 8080:8080 tng-credit-score-refresh
```

## Environment

- `EAS_TOKEN`: optional bearer token required by `/score`
- `MODEL_PATH`: optional local `.pkl`, `.json`, or `.ubj` model file
- `MODEL_OSS_BUCKET`: optional OSS bucket for model download
- `MODEL_OSS_KEY`: optional OSS object key for model download
- `OSS_ENDPOINT`: required when loading from OSS
- `OSS_ACCESS_KEY_ID`: required when loading from OSS
- `OSS_ACCESS_KEY_SECRET`: required when loading from OSS
