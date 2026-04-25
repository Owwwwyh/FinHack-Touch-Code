"""Focused tests for the AWS settle-batch Lambda."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))
sys.path.insert(0, str(Path(__file__).parent))

from aws_lambda.settle_batch import handler as mod
from settlement_test_utils import build_signed_token


class TestSettleBatchLambda:
    def setup_method(self):
        mod.reset_demo_state()

    def test_settles_token_and_records_audit_fields(self):
        token = build_signed_token()
        completion = mod.handler(
            {
                "detail": {
                    "batch_id": "batch_001",
                    "tokens": [token["token"]],
                    "ack_signatures": [
                        {
                            "tx_id": token["tx_id"],
                            "ack_sig": "ack-signature",
                            "ack_kid": "did:tng:device:MERCHANT001",
                        },
                    ],
                },
            },
            None,
        )

        result = completion["detail"]["results"][0]
        ledger = mod.get_demo_ledger()

        assert completion["detail-type"] == "settlement.completed"
        assert result["status"] == "SETTLED"
        assert result["amount_cents"] == 850
        assert ledger[token["tx_id"]]["ack_kid"] == "did:tng:device:MERCHANT001"
        assert ledger[token["tx_id"]]["ack_signature"] == "ack-signature"

    def test_rejects_replayed_nonce(self):
        token = build_signed_token(nonce="cmVwbGF5LW5vbmNlLTAwMQ")

        first = mod.process_settlement_request(
            {
                "batch_id": "batch_001",
                "tokens": [token["token"]],
                "ack_signatures": [],
            },
        )
        second = mod.process_settlement_request(
            {
                "batch_id": "batch_002",
                "tokens": [token["token"]],
                "ack_signatures": [],
            },
        )

        assert first["detail"]["results"][0]["status"] == "SETTLED"
        assert second["detail"]["results"][0] == {
            "status": "REJECTED",
            "reason": "NONCE_REUSED",
            "tx_id": token["tx_id"],
        }
