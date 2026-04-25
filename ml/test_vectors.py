"""
JWS test vectors generator and test suite.
Per docs/03-token-protocol.md §8.

Generates canonical test JWS tokens and their negative variants:
  - token-001.jws         → valid, ACCEPT
  - token-001-bad-sig.jws → tampered last byte of sig, BAD_SIGNATURE
  - token-001-expired.jws → exp = iat, EXPIRED
  - token-001-replayed.jws → second submission, NONCE_REUSED
  - token-001-wrong-recv.jws → receiver pub mutated, RECEIVER_MISMATCH
  - token-001-unknown-kid.jws → kid not in directory, UNKNOWN_KID
"""

import json
import os
import sys
import time
import base64

# Add parent to path for imports
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "backend"))

from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey


def base64url_encode(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def base64url_decode(s: str) -> bytes:
    padded = s + "=" * (4 - len(s) % 4) if len(s) % 4 else s
    return base64.urlsafe_b64decode(padded)


def generate_test_vectors(output_dir: str):
    """Generate all test vectors."""
    os.makedirs(output_dir, exist_ok=True)

    # Generate a test key pair
    private_key = Ed25519PrivateKey.generate()
    public_key_bytes = private_key.public_key().public_bytes_raw()

    kid = "01HW3YKQ8X2A5FR7JM6T1EE9NP"
    iat = int(time.time())
    exp = iat + 72 * 3600

    header = {
        "alg": "EdDSA",
        "typ": "tng-offline-tx+jws",
        "kid": f"did:tng:device:{kid}",
        "policy": "v3.2026-04-22",
        "ver": 1,
    }

    payload = {
        "tx_id": "01HW3YKQ8X2A5FR7JM6T1EE9NP",
        "sender": {
            "kid": f"did:tng:device:{kid}",
            "user_id": "u_8412",
            "pub": base64url_encode(public_key_bytes),
        },
        "receiver": {
            "kid": "did:tng:device:01HW4ABCD1234567890ABCDEF",
            "user_id": "u_3091",
            "pub": base64url_encode(b"\x01" * 32),
        },
        "amount": {"value": "8.50", "currency": "MYR", "scale": 2},
        "nonce": base64url_encode(os.urandom(16)),
        "iat": iat,
        "exp": exp,
        "policy_signed_balance": "120.00",
    }

    # ── token-001.jws (valid) ──
    header_b64 = base64url_encode(json.dumps(header, separators=(",", ":")).encode("utf-8"))
    payload_b64 = base64url_encode(json.dumps(payload, separators=(",", ":")).encode("utf-8"))
    signing_input = f"{header_b64}.{payload_b64}".encode("utf-8")
    signature = private_key.sign(signing_input)
    sig_b64 = base64url_encode(signature)

    valid_jws = f"{header_b64}.{payload_b64}.{sig_b64}"

    with open(os.path.join(output_dir, "token-001.jws"), "w") as f:
        f.write(valid_jws)

    # ── token-001-bad-sig.jws (tampered last byte) ──
    bad_sig = bytearray(signature)
    bad_sig[-1] ^= 0xFF  # Flip last byte
    bad_sig_b64 = base64url_encode(bytes(bad_sig))
    bad_sig_jws = f"{header_b64}.{payload_b64}.{bad_sig_b64}"

    with open(os.path.join(output_dir, "token-001-bad-sig.jws"), "w") as f:
        f.write(bad_sig_jws)

    # ── token-001-expired.jws (exp = iat) ──
    expired_payload = dict(payload)
    expired_payload["exp"] = iat  # Already expired
    expired_payload_b64 = base64url_encode(json.dumps(expired_payload, separators=(",", ":")).encode("utf-8"))
    expired_signing_input = f"{header_b64}.{expired_payload_b64}".encode("utf-8")
    expired_sig = private_key.sign(expired_signing_input)
    expired_sig_b64 = base64url_encode(expired_sig)
    expired_jws = f"{header_b64}.{expired_payload_b64}.{expired_sig_b64}"

    with open(os.path.join(output_dir, "token-001-expired.jws"), "w") as f:
        f.write(expired_jws)

    # ── token-001-replayed.jws (same as valid - second submission) ──
    with open(os.path.join(output_dir, "token-001-replayed.jws"), "w") as f:
        f.write(valid_jws)

    # ── token-001-wrong-recv.jws (receiver pub mutated) ──
    wrong_recv_payload = dict(payload)
    wrong_recv_payload["receiver"] = {
        "kid": "did:tng:device:DIFFERENT_DEVICE",
        "user_id": "u_9999",
        "pub": base64url_encode(b"\x02" * 32),
    }
    wrong_recv_payload_b64 = base64url_encode(json.dumps(wrong_recv_payload, separators=(",", ":")).encode("utf-8"))
    wrong_recv_signing_input = f"{header_b64}.{wrong_recv_payload_b64}".encode("utf-8")
    wrong_recv_sig = private_key.sign(wrong_recv_signing_input)
    wrong_recv_sig_b64 = base64url_encode(wrong_recv_sig)
    wrong_recv_jws = f"{header_b64}.{wrong_recv_payload_b64}.{wrong_recv_sig_b64}"

    with open(os.path.join(output_dir, "token-001-wrong-recv.jws"), "w") as f:
        f.write(wrong_recv_jws)

    # ── token-001-unknown-kid.jws (unknown kid) ──
    unknown_header = dict(header)
    unknown_header["kid"] = "did:tng:device:UNKNOWN_DEVICE_ID_12345"
    unknown_header_b64 = base64url_encode(json.dumps(unknown_header, separators=(",", ":")).encode("utf-8"))
    unknown_signing_input = f"{unknown_header_b64}.{payload_b64}".encode("utf-8")
    unknown_sig = private_key.sign(unknown_signing_input)
    unknown_sig_b64 = base64url_encode(unknown_sig)
    unknown_kid_jws = f"{unknown_header_b64}.{payload_b64}.{unknown_sig_b64}"

    with open(os.path.join(output_dir, "token-001-unknown-kid.jws"), "w") as f:
        f.write(unknown_kid_jws)

    # Save public key for verification
    with open(os.path.join(output_dir, "test-pubkey.bin"), "wb") as f:
        f.write(public_key_bytes)

    # Save metadata
    metadata = {
        "kid": kid,
        "public_key_b64": base64url_encode(public_key_bytes),
        "iat": iat,
        "exp": exp,
        "vectors": [
            {"file": "token-001.jws", "expected": "ACCEPT"},
            {"file": "token-001-bad-sig.jws", "expected": "bad_sig"},
            {"file": "token-001-expired.jws", "expected": "expired"},
            {"file": "token-001-replayed.jws", "expected": "nonce_reused"},
            {"file": "token-001-wrong-recv.jws", "expected": "receiver_mismatch"},
            {"file": "token-001-unknown-kid.jws", "expected": "unknown_kid"},
        ],
    }
    with open(os.path.join(output_dir, "metadata.json"), "w") as f:
        json.dump(metadata, f, indent=2)

    print(f"Test vectors generated in {output_dir}")
    for v in metadata["vectors"]:
        print(f"  {v['file']}: expected → {v['expected']}")


if __name__ == "__main__":
    output = os.path.join(os.path.dirname(__file__), "test-vectors")
    generate_test_vectors(output)
