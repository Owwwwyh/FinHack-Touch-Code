"""JWS test vector generator.

Per docs/03-token-protocol.md §8:
- token-001.jws: valid → ACCEPT
- token-001-bad-sig.jws: tampered last byte → bad_sig
- token-001-expired.jws: exp = iat → expired
- token-001-replayed.jws: same nonce second time → nonce_reused
- token-001-wrong-recv.jws: receiver pub mutated → receiver_mismatch
- token-001-unknown-kid.jws: kid not in directory → unknown_kid
"""

import json
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..', 'backend'))
from lib.jws import generate_test_keypair, sign_jws, b64url_decode


def generate_test_vectors():
    private_key, public_key = generate_test_keypair()
    kid = "01HW3YKQ8X2A5FR7JM6T1EE9NP"
    
    base_payload = {
        "tx_id": "01HW3YKQ8X2A5FR7JM6T1EE9NP",
        "sender": {
            "kid": f"did:tng:device:{kid}",
            "user_id": "u_8412",
            "pub": "BASE64URL_PLACEHOLDER_32_BYTES_SENDER",
        },
        "receiver": {
            "kid": "did:tng:device:01HW4ABCD",
            "user_id": "u_3091",
            "pub": "BASE64URL_PLACEHOLDER_32_BYTES_RECEIVER",
        },
        "amount": {
            "value": "8.50",
            "currency": "MYR",
            "scale": 2,
        },
        "nonce": "BASE64URL_16_RANDOM_BYTES",
        "iat": 1745603421,
        "exp": 1745862621,
        "policy_signed_balance": "120.00",
    }

    out_dir = os.path.join(os.path.dirname(__file__))
    os.makedirs(out_dir, exist_ok=True)

    # Vector 1: Valid token
    valid_jws = sign_jws(private_key, base_payload, kid=kid)
    with open(os.path.join(out_dir, 'token-001.jws'), 'w') as f:
        f.write(valid_jws)
    print(f"✓ token-001.jws (valid)")

    # Vector 2: Bad signature (tamper last byte)
    parts = valid_jws.split('.')
    tampered_sig = parts[2][:-2] + chr(ord(parts[2][-1]) ^ 0xFF)
    bad_sig_jws = f"{parts[0]}.{parts[1]}.{tampered_sig}"
    with open(os.path.join(out_dir, 'token-001-bad-sig.jws'), 'w') as f:
        f.write(bad_sig_jws)
    print(f"✓ token-001-bad-sig.jws (bad_sig)")

    # Vector 3: Expired token
    expired_payload = dict(base_payload)
    expired_payload['exp'] = expired_payload['iat']  # exp = iat → already expired
    expired_jws = sign_jws(private_key, expired_payload, kid=kid)
    with open(os.path.join(out_dir, 'token-001-expired.jws'), 'w') as f:
        f.write(expired_jws)
    print(f"✓ token-001-expired.jws (expired)")

    # Vector 4: Replayed (same JWS — test is submitting twice)
    with open(os.path.join(out_dir, 'token-001-replayed.jws'), 'w') as f:
        f.write(valid_jws)
    print(f"✓ token-001-replayed.jws (nonce_reused)")

    # Vector 5: Wrong receiver
    wrong_recv_payload = dict(base_payload)
    wrong_recv_payload['receiver'] = {
        "kid": "did:tng:device:01HW4HACKED",
        "user_id": "u_hacked",
        "pub": "BASE64URL_TAMPERED_RECEIVER_KEY",
    }
    wrong_recv_jws = sign_jws(private_key, wrong_recv_payload, kid=kid)
    with open(os.path.join(out_dir, 'token-001-wrong-recv.jws'), 'w') as f:
        f.write(wrong_recv_jws)
    print(f"✓ token-001-wrong-recv.jws (receiver_mismatch)")

    # Vector 6: Unknown kid
    unknown_kid_jws = sign_jws(private_key, base_payload, kid="UNKNOWN_KID_12345")
    with open(os.path.join(out_dir, 'token-001-unknown-kid.jws'), 'w') as f:
        f.write(unknown_kid_jws)
    print(f"✓ token-001-unknown-kid.jws (unknown_kid)")

    # Save public key for verification tests
    pub_bytes = public_key.public_bytes(
        encoding=__import__('cryptography').hazmat.primitives.serialization.Encoding.Raw,
        format=__import__('cryptography').hazmat.primitives.serialization.PublicFormat.Raw,
    )
    import base64
    with open(os.path.join(out_dir, 'test-pubkey.b64'), 'w') as f:
        f.write(base64.urlsafe_b64encode(pub_bytes).decode())

    print(f"\nPublic key saved to test-pubkey.b64")
    print(f"Kid: {kid}")


if __name__ == '__main__':
    generate_test_vectors()
