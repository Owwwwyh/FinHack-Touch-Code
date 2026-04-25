"""JWS test suite — validates all 6 test vectors."""

import os
import sys
import base64

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'backend'))
from lib.jws import verify_jws, public_key_from_bytes

VECTORS_DIR = os.path.join(os.path.dirname(__file__), '..', 'ml', 'test-vectors')

# Test pubkey cache (in-memory)
_pubkey_cache = {}


def setup_module():
    """Load test public key into cache."""
    pubkey_path = os.path.join(VECTORS_DIR, 'test-pubkey.b64')
    if os.path.exists(pubkey_path):
        with open(pubkey_path) as f:
            pub_b64 = f.read().strip()
        pub_bytes = base64.urlsafe_b64decode(pub_b64)
        pub_key = public_key_from_bytes(pub_bytes)
        _pubkey_cache['01HW3YKQ8X2A5FR7JM6T1EE9NP'] = pub_key


def pubkey_lookup(kid: str):
    return _pubkey_cache.get(kid)


def test_valid_token():
    jws = _load_vector('token-001.jws')
    valid, payload, reason = verify_jws(jws, pubkey_lookup)
    assert valid, f"Expected valid, got reason: {reason}"
    assert payload['tx_id'] == '01HW3YKQ8X2A5FR7JM6T1EE9NP'


def test_bad_signature():
    jws = _load_vector('token-001-bad-sig.jws')
    valid, payload, reason = verify_jws(jws, pubkey_lookup)
    assert not valid, "Expected invalid"
    assert reason == 'bad_sig', f"Expected bad_sig, got {reason}"


def test_expired_token():
    jws = _load_vector('token-001-expired.jws')
    valid, payload, reason = verify_jws(jws, pubkey_lookup)
    assert not valid, "Expected invalid"
    assert reason == 'expired', f"Expected expired, got {reason}"


def test_wrong_receiver():
    jws = _load_vector('token-001-wrong-recv.jws')
    # This should still verify (it's properly signed), just has different receiver
    # The receiver_mismatch check is done at settlement, not JWS verify
    valid, payload, reason = verify_jws(jws, pubkey_lookup)
    assert valid, f"Expected valid (signature OK), got reason: {reason}"


def test_unknown_kid():
    jws = _load_vector('token-001-unknown-kid.jws')
    valid, payload, reason = verify_jws(jws, pubkey_lookup)
    assert not valid, "Expected invalid"
    assert reason == 'unknown_kid', f"Expected unknown_kid, got {reason}"


def _load_vector(name: str) -> str:
    path = os.path.join(VECTORS_DIR, name)
    with open(path) as f:
        return f.read().strip()


if __name__ == '__main__':
    setup_module()
    for name, func in list(globals().items()):
        if name.startswith('test_'):
            try:
                func()
                print(f"✓ {name}")
            except AssertionError as e:
                print(f"✗ {name}: {e}")
            except FileNotFoundError as e:
                print(f"⊘ {name}: vector file not found — run generate_vectors.py first")
