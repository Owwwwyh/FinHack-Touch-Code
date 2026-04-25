/**
 * token_service.js
 *
 * Build and sign JWS tokens (Ed25519).
 * In production the PRIVATE KEY stays in Android Keystore and never leaves the device.
 * This module is used by:
 *   - Tests: to generate valid/invalid test vectors
 *   - Backend demo: to mint tokens server-side for demo purposes only
 *
 * docs/03-token-protocol.md
 */

import * as ed from '@noble/ed25519';
import { createHash } from 'node:crypto';
import { randomBytes } from 'node:crypto';

// Configure noble/ed25519 to use Node.js sha512
ed.etc.sha512Sync = (...m) => {
  const buf = Buffer.concat(m.map(x => Buffer.from(x)));
  return new Uint8Array(createHash('sha512').update(buf).digest());
};

// ─── helpers ────────────────────────────────────────────────────────────────

function b64urlEncode(bytes) {
  return Buffer.from(bytes)
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=/g, '');
}

function encodeJsonPart(obj) {
  return b64urlEncode(Buffer.from(JSON.stringify(obj), 'utf8'));
}

/**
 * Generate a UUIDv7-like tx_id (time-ordered).
 * 48-bit ms timestamp + 80 random bits, formatted as UUID.
 * @returns {string}
 */
function uuidv7() {
  const ts = BigInt(Date.now());
  // Allocate 8 bytes, write full uint64, then use only the top 6 bytes
  const tsBuf = Buffer.alloc(8);
  tsBuf.writeBigUInt64BE(ts);
  const rand = randomBytes(10);
  const hex =
    tsBuf.slice(2, 6).toString('hex') +   // 4 bytes (ms high)
    tsBuf.slice(6, 8).toString('hex') +   // 2 bytes (ms low)
    rand.toString('hex');                   // 10 bytes random
  return [
    hex.slice(0,  8),
    hex.slice(8,  12),
    hex.slice(12, 16),
    hex.slice(16, 20),
    hex.slice(20, 32),
  ].join('-');
}

// ─── Key management (test / demo) ────────────────────────────────────────────

/**
 * Generate a fresh Ed25519 keypair for testing.
 * @returns {{ privateKey: Uint8Array, publicKey: Uint8Array }}
 */
export async function generateKeypair() {
  const privateKey = ed.utils.randomPrivateKey();
  const publicKey  = await ed.getPublicKeyAsync(privateKey);
  return { privateKey, publicKey };
}

// ─── Token builder ────────────────────────────────────────────────────────────

/**
 * Build and sign a compact JWS token.
 *
 * @param {{
 *   privateKey: Uint8Array,
 *   kid: string,
 *   senderUserId: string,
 *   senderPub: Uint8Array,
 *   receiverKid: string,
 *   receiverUserId: string,
 *   receiverPub: Uint8Array,
 *   amountMyr: string,          // decimal string e.g. "8.50"
 *   policyVersion?: string,
 *   validityHours?: number,     // default 72
 *   nonce?: string,             // base64url 16 bytes; auto-generated if omitted
 *   iatOverride?: number,       // unix seconds; defaults to now
 * }} params
 * @returns {Promise<string>} compact JWS
 */
export async function buildSignedToken(params) {
  const {
    privateKey,
    kid,
    senderUserId,
    senderPub,
    receiverKid,
    receiverUserId,
    receiverPub,
    amountMyr,
    policyVersion = 'v1.demo',
    validityHours = 72,
    nonce,
    iatOverride,
  } = params;

  const iat = iatOverride ?? Math.floor(Date.now() / 1000);
  const exp = iat + validityHours * 3600;
  const txNonce = nonce ?? b64urlEncode(randomBytes(16));

  const header = {
    alg:    'EdDSA',
    typ:    'tng-offline-tx+jws',
    kid,
    policy: policyVersion,
    ver:    1,
  };

  const payload = {
    tx_id:  uuidv7(),
    sender: {
      kid,
      user_id: senderUserId,
      pub:     b64urlEncode(senderPub),
    },
    receiver: {
      kid:     receiverKid,
      user_id: receiverUserId,
      pub:     b64urlEncode(receiverPub),
    },
    amount: {
      value:    amountMyr,
      currency: 'MYR',
      scale:    2,
    },
    nonce: txNonce,
    iat,
    exp,
    policy_signed_balance: '120.00', // demo value
  };

  const headerB64  = encodeJsonPart(header);
  const payloadB64 = encodeJsonPart(payload);
  const signingInput = `${headerB64}.${payloadB64}`;
  const msgBytes   = new TextEncoder().encode(signingInput);
  const sigBytes   = await ed.signAsync(msgBytes, privateKey);
  const sigB64     = b64urlEncode(sigBytes);

  return `${headerB64}.${payloadB64}.${sigB64}`;
}

/**
 * In-memory pubkey registry for demo / tests.
 * Maps kid → Uint8Array (32-byte Ed25519 pub).
 */
export class PubkeyRegistry {
  constructor() {
    this._store = new Map();
  }

  register(kid, pubkeyBytes) {
    this._store.set(kid, pubkeyBytes);
  }

  /** @returns {(kid: string) => Promise<Uint8Array|null>} */
  resolver() {
    return async (kid) => this._store.get(kid) ?? null;
  }
}
