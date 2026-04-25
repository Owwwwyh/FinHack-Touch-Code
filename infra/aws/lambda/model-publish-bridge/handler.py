"""
AWS Lambda: model-publish-bridge
Per docs/05-aws-services.md §4, docs/04-credit-score-ml.md §7.

Copies model artifacts from AWS S3 to Alibaba OSS (boundary B1).
Triggered by Step Functions during model release pipeline.
"""

import json
import os
import boto3

MODEL_BUCKET = os.environ.get("MODEL_BUCKET", "tng-finhack-aws-models")
OSS_MODEL_BUCKET = os.environ.get("OSS_MODEL_BUCKET", "tng-finhack-models")

s3 = boto3.client("s3")


def handler(event, context):
    """
    Copy model artifacts from S3 to Alibaba OSS.
    In production, this would use Alibaba OSS SDK or a presigned URL approach.
    For demo, we log the action and simulate the copy.
    """
    model_version = event.get("model_version", "v1")
    artifacts = event.get("artifacts", ["model.tflite", "model.json", "score_card.json"])

    s3_prefix = f"models/credit/{model_version}/"
    oss_prefix = f"credit/{model_version}/"

    copied = []
    for artifact in artifacts:
        s3_key = f"{s3_prefix}{artifact}"
        oss_key = f"{oss_prefix}{artifact}"

        try:
            # Verify source exists in S3
            s3.head_object(Bucket=MODEL_BUCKET, Key=s3_key)

            # In production: copy to Alibaba OSS using cross-cloud credentials
            # For demo: log the action
            print(f"Would copy s3://{MODEL_BUCKET}/{s3_key} → oss://{OSS_MODEL_BUCKET}/{oss_key}")
            copied.append({"artifact": artifact, "status": "copied"})

        except s3.exceptions.ClientError as e:
            if e.response["Error"]["Code"] == "404":
                copied.append({"artifact": artifact, "status": "not_found"})
            else:
                copied.append({"artifact": artifact, "status": "error", "reason": str(e)})

    return {
        "model_version": model_version,
        "copied": copied,
        "boundary": "B1",
    }
