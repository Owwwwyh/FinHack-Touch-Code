/**
 * token_verify.test.js
 *
 * Implements the 6 canonical test vectors from docs/03-token-protocol.md §8,
 * plus settle_batch double-spend tests.
 *
 * Run: npm test
 */

import { generateKeypair, buildSignedToken, PubkeyRegistry } from '../core/token_service.js';
import { verifyToken } from '../core/ed25519_verifier.js';
import { getNonceStore, _resetNonceStore } from '../core/nonce_store.js';
import { handler as settleBatch, registerPubkey } from '../lambdas/settle_batch.js';

// ─── Shared test fixtures ─────────────────────────────────────────────────────

let senderKey, receiverKey;
let registry;

const SENDER_KID   = 'did:tng:device:TEST_SENDER_01';
const RECEIVER_KID = 'did:tng:device:TEST_RECEIVER_01';

beforeAll(async () => {
  senderKey   = await generateKeypair();
  receiverKey = await generateKeypair();

  registry = new PubkeyRegistry();
  registry.register(SENDER_KID,   senderKey.publicKey);
  registry.register(RECEIVER_KID, receiverKey.publicKey);

  // Also register in global settle registry
  registerPubkey(SENDER_KID,   senderKey.publicKey);
  registerPubkey(RECEIVER_KID, receiverKey.publicKey);
});

beforeEach(() => {
  _resetNonceStore(); // fresh nonce store per test
});

/** Build a default valid token */
async function makeValidToken(overrides = {}) {
  return buildSignedToken({
    privateKey:    senderKey.privateKey,
    kid:           SENDER_KID,
    senderUserId:  'u_sender',
    senderPub:     senderKey.publicKey,
    receiverKid:   RECEIVER_KID,
    receiverUserId:'u_receiver',
    receiverPub:   receiverKey.publicKey,
    amountMyr:     '8.50',
    ...overrides,
  });
}

// ─── Test vectors ─────────────────────────────────────────────────────────────

describe('Token verification — 6 canonical test vectors', () => {

  /**
   * Vector 1: token-001 — valid → ACCEPT
   */
  test('token-001: valid token → ACCEPT', async () => {
    const jws = await makeValidToken();
    const result = await verifyToken(jws, registry.resolver());
    expect(result.ok).toBe(true);
    expect(result.payload.amount.value).toBe('8.50');
    expect(result.payload.amount.currency).toBe('MYR');
  });

  /**
   * Vector 2: token-001-bad-sig — tampered last byte of sig → bad_sig
   */
  test('token-001-bad-sig: tampered signature → BAD_SIGNATURE', async () => {
    const jws = await makeValidToken();
    const parts = jws.split('.');

    // Decode the raw signature bytes, flip byte at position 16, re-encode
    const sigBytes = Buffer.from(
      parts[2].replace(/-/g, '+').replace(/_/g, '/'),
      'base64'
    );
    sigBytes[16] ^= 0xFF; // flip all bits at byte 16 of the 64-byte Ed25519 sig
    parts[2] = sigBytes.toString('base64')
      .replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');

    const tamperedJws = parts.join('.');
    const result = await verifyToken(tamperedJws, registry.resolver());
    expect(result.ok).toBe(false);
    expect(result.reason).toBe('BAD_SIGNATURE');
  });

  /**
   * Vector 3: token-001-expired — exp = iat → expired
   */
  test('token-001-expired: expired token → EXPIRED_TOKEN', async () => {
    const pastIat = Math.floor(Date.now() / 1000) - 3600;
    const jws = await makeValidToken({
      iatOverride:   pastIat,
      validityHours: 0, // exp = iat → already expired
    });

    const result = await verifyToken(jws, registry.resolver());
    expect(result.ok).toBe(false);
    expect(result.reason).toBe('EXPIRED_TOKEN');
  });

  /**
   * Vector 4: token-001-replayed — second submission of same nonce → nonce_reused
   * (tested via settleBatch which has the nonce store)
   */
  test('token-001-replayed: second settle of same nonce → NONCE_REUSED', async () => {
    const fixedNonce = 'AAAAAAAAAAAAAAAAAAAAAA'; // stable base64url value
    const jws = await makeValidToken({ nonce: fixedNonce });

    const batch1 = await settleBatch({
      batch_id: 'batch-replay-1',
      tokens:   [jws],
    });
    const res1 = JSON.parse(batch1.body);
    expect(res1.results[0].status).toBe('SETTLED');

    // Same token submitted again
    const batch2 = await settleBatch({
      batch_id: 'batch-replay-2',
      tokens:   [jws],
    });
    const res2 = JSON.parse(batch2.body);
    expect(res2.results[0].status).toBe('REJECTED');
    expect(res2.results[0].reason).toBe('NONCE_REUSED');
  });

  /**
   * Vector 5: token-001-wrong-recv — receiver pub mutated → receiver_mismatch
   * The token is signed correctly but the receiver.pub in the payload doesn't
   * match a third party's pub (verified via signature: tampered payload → bad_sig).
   * Since receiver_pub is IN the signed payload, mutating it = BAD_SIGNATURE.
   */
  test('token-001-wrong-recv: mutated receiver pub → BAD_SIGNATURE', async () => {
    const jws = await makeValidToken();
    const parts = jws.split('.');

    // Decode payload, swap receiver pub, re-encode WITHOUT re-signing
    const payloadJson = JSON.parse(
      Buffer.from(parts[1].replace(/-/g, '+').replace(/_/g, '/'), 'base64').toString()
    );
    payloadJson.receiver.pub = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'; // wrong pub
    parts[1] = Buffer.from(JSON.stringify(payloadJson))
      .toString('base64')
      .replace(/\+/g, '-')
      .replace(/\//g, '_')
      .replace(/=/g, '');

    const tamperedJws = parts.join('.');
    const result = await verifyToken(tamperedJws, registry.resolver());
    expect(result.ok).toBe(false);
    expect(result.reason).toBe('BAD_SIGNATURE'); // tampering payload = sig mismatch
  });

  /**
   * Vector 6: token-001-unknown-kid — kid not in directory → unknown_kid
   */
  test('token-001-unknown-kid: unknown kid → UNKNOWN_KID', async () => {
    const unknownKey = await generateKeypair();
    const jws = await buildSignedToken({
      privateKey:     unknownKey.privateKey,
      kid:            'did:tng:device:UNKNOWN_DEVICE_999',
      senderUserId:   'u_hacker',
      senderPub:      unknownKey.publicKey,
      receiverKid:    RECEIVER_KID,
      receiverUserId: 'u_receiver',
      receiverPub:    receiverKey.publicKey,
      amountMyr:      '1.00',
    });

    // Registry does NOT know this kid
    const result = await verifyToken(jws, registry.resolver());
    expect(result.ok).toBe(false);
    expect(result.reason).toBe('UNKNOWN_KID');
  });

});

// ─── Additional settle_batch tests ────────────────────────────────────────────

describe('settle_batch — batch processing', () => {

  test('batch with mix of valid and duplicate tokens', async () => {
    const nonce1 = 'nonce_uniq_1111111111111';
    const nonce2 = 'nonce_uniq_2222222222222';

    const jws1 = await makeValidToken({ nonce: nonce1 });
    const jws2 = await makeValidToken({ nonce: nonce2 });

    // Settle both
    const result = await settleBatch({
      batch_id: 'batch-mix-1',
      tokens: [jws1, jws2],
    });
    const body = JSON.parse(result.body);
    expect(body.results).toHaveLength(2);
    expect(body.results.every(r => r.status === 'SETTLED')).toBe(true);

    // Re-settle jws1 (duplicate), jws2 should still settle fresh in theory,
    // but here we replay both to show only the duplicates get rejected.
    const result2 = await settleBatch({
      batch_id: 'batch-mix-2',
      tokens: [jws1, jws2],
    });
    const body2 = JSON.parse(result2.body);
    expect(body2.results[0].reason).toBe('NONCE_REUSED');
    expect(body2.results[1].reason).toBe('NONCE_REUSED');
  });

  test('batch exceeding 50 tokens is rejected', async () => {
    const tokens = Array(51).fill('dummy.jws.token');
    const result = await settleBatch({ batch_id: 'big', tokens });
    expect(result.statusCode).toBe(400);
  });

  test('amount > RM 250 rejected as BAD_REQUEST', async () => {
    const jws = await makeValidToken({ amountMyr: '300.00' });
    const result = await verifyToken(jws, registry.resolver());
    expect(result.ok).toBe(false);
    expect(result.reason).toBe('BAD_REQUEST');
  });

});
