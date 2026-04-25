"""
Alibaba Function Compute: score-policy
Per docs/08-backend-api.md §3.8 — Return current policy + signed model URL.
"""

import json
import os
import time
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

OSS_MODEL_BUCKET = os.environ.get("OSS_MODEL_BUCKET", "tng-finhack-models")
OTS_INSTANCE = os.environ.get("OTS_INSTANCE", "tng-finhack")


def handler(event, context):
    """FC handler for GET /v1/score/policy"""
    now = int(time.time())

    # Read active policy from Tablestore (stub for demo)
    policy_version = "v3.2026-04-22"
    released_at = "2026-04-22T08:00:00Z"

    # Generate signed URL for model download from OSS (stub)
    model_url = f"https://{OSS_MODEL_BUCKET}.oss-ap-southeast-3.aliyuncs.com/credit/v3/model.tflite?Signature=DEMO_SIG&Expires={now + 3600}"

    policy = {
        "policy_version": policy_version,
        "released_at": released_at,
        "model": {
            "format": "tflite",
            "url": model_url,
            "sha256": "9f1c8a3b2d7e6f4a1c0b9d8e7f6a5c4b3d2e1f0a9b8c7d6e5f4a3b2c1d0e9f",
            "sigstore_signature": "MEUCIQDxDEMO_SIGSTORE_SIGNATURE_FOR_VERIFICATION",
        },
        "limits": {
            "hard_cap_per_tier": {"0": "20.00", "1": "150.00", "2": "500.00"},
            "global_cap_per_token_myr": "250.00",
            "max_token_validity_hours": 72,
        },
    }

    logger.info(f"Score policy requested: version={policy_version}")

    return {
        "statusCode": 200,
        "body": json.dumps(policy),
    }
