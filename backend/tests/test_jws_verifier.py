"""
Unit tests for JWS verifier
Tests all 6 test vectors against the verifier
"""

import json
import os
import sys
import time
from pathlib import Path

import pytest

# Add backend to path
sys.path.insert(0, str(Path(__file__).parent.parent / "lib"))

from jws_verifier import JwsVerifier


class TestJwsVerifier:
    """Test suite for JWS verification"""

    @pytest.fixture(scope="class")
    def test_vectors_dir(self):
        """Return path to test vectors directory"""
        return Path(__file__).parent.parent / "test-vectors"

    @pytest.fixture(scope="class")
    def public_key_b64(self):
        """Return base64url-encoded public key for test tokens"""
        # This should match the public key used to sign test vectors
        # For now, we'll extract it from a known-good token
        return "5rqObn-fi31cOhudfyXDwJt9XDo5t9XDI5t9XDo5t9XDo"

    def test_token_001_valid(self, test_vectors_dir, public_key_b64):
        """Test that valid token passes verification"""
        token_path = test_vectors_dir / "token-001-valid.jws"
        if not token_path.exists():
            pytest.skip("Test vector file not found; run generate_test_vectors.py first")

        with open(token_path, "r") as f:
            token = f.read().strip()

        # Extract public key from token payload
        parts = token.split(".")
        payload_json = JwsVerifier.base64url_decode(parts[1])
        payload = json.loads(payload_json)
        public_key_from_token = payload["sender"]["pub"]

        result = JwsVerifier.verify_compact(token, public_key_from_token)

        assert result["valid"] is True, f"Valid token should verify: {result}"
        assert result.get("payload") is not None
        assert result["payload"]["tx_id"] == "01HW3YKQ8X2A5FR7JM6T1EE9NP"
        assert result["payload"]["amount"]["value"] == "8.50"

    def test_token_002_expired(self, test_vectors_dir):
        """Test that expired token is rejected"""
        token_path = test_vectors_dir / "token-002-expired.jws"
        if not token_path.exists():
            pytest.skip("Test vector file not found")

        with open(token_path, "r") as f:
            token = f.read().strip()

        parts = token.split(".")
        payload_json = JwsVerifier.base64url_decode(parts[1])
        payload = json.loads(payload_json)
        public_key_from_token = payload["sender"]["pub"]

        result = JwsVerifier.verify_compact(token, public_key_from_token)

        assert result["valid"] is False
        assert result["error"] == "EXPIRED_TOKEN"

    def test_token_003_bad_sig(self, test_vectors_dir):
        """Test that tampered signature is rejected"""
        token_path = test_vectors_dir / "token-003-bad-sig.jws"
        if not token_path.exists():
            pytest.skip("Test vector file not found")

        with open(token_path, "r") as f:
            token = f.read().strip()

        parts = token.split(".")
        payload_json = JwsVerifier.base64url_decode(parts[1])
        payload = json.loads(payload_json)
        public_key_from_token = payload["sender"]["pub"]

        result = JwsVerifier.verify_compact(token, public_key_from_token)

        assert result["valid"] is False
        assert result["error"] == "BAD_SIGNATURE"

    def test_token_004_missing_nonce(self, test_vectors_dir):
        """Test that missing required field is rejected"""
        token_path = test_vectors_dir / "token-004-missing-nonce.jws"
        if not token_path.exists():
            pytest.skip("Test vector file not found")

        with open(token_path, "r") as f:
            token = f.read().strip()

        parts = token.split(".")
        payload_json = JwsVerifier.base64url_decode(parts[1])
        payload = json.loads(payload_json)
        public_key_from_token = payload["sender"]["pub"]

        result = JwsVerifier.verify_compact(token, public_key_from_token)

        assert result["valid"] is False
        assert result["error"] == "MISSING_FIELD"
        assert "nonce" in result.get("message", "")

    def test_token_005_tampered_amount(self, test_vectors_dir):
        """Test that tampered payload is rejected"""
        token_path = test_vectors_dir / "token-005-tampered-amount.jws"
        if not token_path.exists():
            pytest.skip("Test vector file not found")

        with open(token_path, "r") as f:
            token = f.read().strip()

        parts = token.split(".")
        payload_json = JwsVerifier.base64url_decode(parts[1])
        payload = json.loads(payload_json)
        public_key_from_token = payload["sender"]["pub"]

        result = JwsVerifier.verify_compact(token, public_key_from_token)

        assert result["valid"] is False
        assert result["error"] == "BAD_SIGNATURE"

    def test_malformed_jws_wrong_parts(self):
        """Test that malformed JWS (wrong number of parts) is rejected"""
        malformed = "header.payload"  # Missing signature

        result = JwsVerifier.verify_compact(malformed, "dummy_key")

        assert result["valid"] is False
        assert result["error"] == "INVALID_FORMAT"

    def test_invalid_base64(self):
        """Test that invalid base64 is rejected"""
        malformed = "!!!invalid!!!.payload.signature"

        result = JwsVerifier.verify_compact(malformed, "dummy_key")

        assert result["valid"] is False
        assert result["error"] == "INVALID_HEADER"

    def test_convenience_method(self, test_vectors_dir):
        """Test the convenience method verify_and_extract_payload"""
        token_path = test_vectors_dir / "token-001-valid.jws"
        if not token_path.exists():
            pytest.skip("Test vector file not found")

        with open(token_path, "r") as f:
            token = f.read().strip()

        parts = token.split(".")
        payload_json = JwsVerifier.base64url_decode(parts[1])
        payload = json.loads(payload_json)
        public_key_from_token = payload["sender"]["pub"]

        valid, extracted_payload, error_code = JwsVerifier.verify_and_extract_payload(
            token, public_key_from_token
        )

        assert valid is True
        assert error_code is None
        assert extracted_payload is not None
        assert extracted_payload["tx_id"] == "01HW3YKQ8X2A5FR7JM6T1EE9NP"


if __name__ == "__main__":
    # Run tests
    pytest.main([__file__, "-v"])
