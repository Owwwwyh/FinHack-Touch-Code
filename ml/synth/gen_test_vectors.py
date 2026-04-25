#!/usr/bin/env python3
"""
Generate 6 JWS test vectors for crypto validation
Outputs to ml/test-vectors/ directory
"""

import base64
import json
import time
from pathlib import Path

from cryptography.hazmat.primitives.asymmetric import ed25519
from cryptography.hazmat.primitives import serialization


def base64url_encode(data: bytes) -> str:
    """Encode bytes to base64url without padding"""
    encoded = base64.urlsafe_b64encode(data).decode("ascii")
    return encoded.rstrip("=")


def base64url_decode(data: str) -> bytes:
    """Decode base64url with optional padding"""
    padding = 4 - (len(data) % 4)
    if padding != 4:
        data += "=" * padding
    return base64.urlsafe_b64decode(data)


def create_jws(payload_dict: dict, private_key_bytes: bytes) -> str:
    """Create a compact JWS token"""
    header = {
        "alg": "EdDSA",
        "typ": "tng-offline-tx+jws",
        "kid": "did:tng:device:01HW3YKQ8X2A5FR7JM6T1EE9NP",
        "policy": "v3.2026-04-22",
        "ver": 1,
    }

    header_json = json.dumps(header, separators=(",", ":"), sort_keys=True)
    payload_json = json.dumps(payload_dict, separators=(",", ":"), sort_keys=True)

    header_b64 = base64url_encode(header_json.encode("utf-8"))
    payload_b64 = base64url_encode(payload_json.encode("utf-8"))

    message = f"{header_b64}.{payload_b64}".encode("utf-8")

    # Sign with private key
    private_key = ed25519.Ed25519PrivateKey.from_private_bytes(private_key_bytes)
    signature = private_key.sign(message)
    signature_b64 = base64url_encode(signature)

    return f"{header_b64}.{payload_b64}.{signature_b64}"


# Generate Ed25519 key pair for testing
private_key_obj = ed25519.Ed25519PrivateKey.generate()
private_key_bytes = private_key_obj.private_bytes(
    encoding=serialization.Encoding.Raw,
    format=serialization.PrivateFormat.Raw,
    encryption_algorithm=serialization.NoEncryption(),
)
public_key_obj = private_key_obj.public_key()
public_key_bytes = public_key_obj.public_bytes(
    encoding=serialization.Encoding.Raw, format=serialization.PublicFormat.Raw
)

# Ensure output directory exists
output_dir = Path("/Users/mkfoo/Desktop/FinHack-Touch-Code/ml/test-vectors")
output_dir.mkdir(parents=True, exist_ok=True)

print(f"Test key pair generated")
print(f"  Private (hex): {private_key_bytes.hex()}")
print(f"  Public (hex):  {public_key_bytes.hex()}")

now = int(time.time())

# token-001-valid.jws
payload_valid = {
    "tx_id": "01HW3YKQ8X2A5FR7JM6T1EE9NP",
    "sender": {
        "kid": "did:tng:device:01HW3YKQ8X2A5FR7JM6T1EE9NP",
        "user_id": "u_8412",
        "pub": base64url_encode(public_key_bytes),
    },
    "receiver": {
        "kid": "did:tng:device:01HW4YKQ8X2A5FR7JM6T1EE9NQ",
        "user_id": "u_3091",
        "pub": base64url_encode(public_key_bytes),
    },
    "amount": {"value": "8.50", "currency": "MYR", "scale": 2},
    "nonce": base64url_encode(b"random16bytenonce1"),
    "iat": now,
    "exp": now + 72 * 3600,  # 72 hours from now
    "policy_signed_balance": "120.00",
}

token_001 = create_jws(payload_valid, private_key_bytes)
with open(output_dir / "token-001-valid.jws", "w") as f:
    f.write(token_001)
print(f"✓ token-001-valid.jws")

# token-002-expired.jws
payload_expired = payload_valid.copy()
payload_expired["iat"] = now - 100000
payload_expired["exp"] = now - 1000  # Expired in the past

token_002 = create_jws(payload_expired, private_key_bytes)
with open(output_dir / "token-002-expired.jws", "w") as f:
    f.write(token_002)
print(f"✓ token-002-expired.jws")

# token-003-bad-sig.jws
token_003 = create_jws(payload_valid, private_key_bytes)
parts = token_003.split(".")
# Corrupt the signature by changing first char
corrupted_sig = "Z" + parts[2][1:]
token_003_corrupted = f"{parts[0]}.{parts[1]}.{corrupted_sig}"
with open(output_dir / "token-003-bad-sig.jws", "w") as f:
    f.write(token_003_corrupted)
print(f"✓ token-003-bad-sig.jws")

# token-004-missing-nonce.jws
payload_no_nonce = payload_valid.copy()
del payload_no_nonce["nonce"]  # Remove nonce field

token_004 = create_jws(payload_no_nonce, private_key_bytes)
with open(output_dir / "token-004-missing-nonce.jws", "w") as f:
    f.write(token_004)
print(f"✓ token-004-missing-nonce.jws")

# token-005-tampered-amount.jws
# First, create a properly signed token with original amount
payload_orig = payload_valid.copy()
token_005_orig = create_jws(payload_orig, private_key_bytes)

# Now modify the payload but keep the original signature
# This simulates someone changing the amount after signing
parts = token_005_orig.split(".")
header_b64 = parts[0]

payload_modified = payload_valid.copy()
payload_modified["amount"] = {"value": "1000.00", "currency": "MYR", "scale": 2}
payload_json = json.dumps(payload_modified, separators=(",", ":"), sort_keys=True)
payload_modified_b64 = base64url_encode(payload_json.encode("utf-8"))

# Use original signature with modified payload (will fail verification)
original_sig_b64 = parts[2]
token_005_tampered = f"{header_b64}.{payload_modified_b64}.{original_sig_b64}"
with open(output_dir / "token-005-tampered-amount.jws", "w") as f:
    f.write(token_005_tampered)
print(f"✓ token-005-tampered-amount.jws")

# token-006-unknown-kid.jws
payload_unknown_kid = payload_valid.copy()
payload_unknown_kid["sender"]["kid"] = "did:tng:device:UNKNOWN_KID_12345"

token_006 = create_jws(payload_unknown_kid, private_key_bytes)
with open(output_dir / "token-006-unknown-kid.jws", "w") as f:
    f.write(token_006)
print(f"✓ token-006-unknown-kid.jws")

print("\n✅ All 6 test vectors generated!")
print(f"Location: {output_dir}")
