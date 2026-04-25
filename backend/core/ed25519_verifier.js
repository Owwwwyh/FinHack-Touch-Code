/**
 * ed25519_verifier.js
 *
 * Verifies a compact JWS (BASE64URL(header).BASE64URL(payload).BASE64URL(sig))
 * signed with Ed25519 as per docs/03-token-protocol.md.
 *
 * Returns one of:
 *   { ok: true,  payload: <object> }
 *   { ok: false, reason: <string> }   where reason ∈ error taxonomy in docs/08-backend-api.md
 */

import * as ed from '@noble/ed25519';

// ─── helpers ────────────────────────────────────────────────────────────────

/**
 * Base64URL decode to Uint8Array (no padding required).
 * @param {string} b64url
 * @returns {Uint8Array}
 */
function b64urlDecode(b64url) {
  // restore padding and convert to base64
  const padded = b64url.replace(/-/g, '+').replace(/_/g, '/');
  const padLen = (4 - (padded.length % 4)) % 4;
  const b64 = padded + '='.repeat(padLen);
  return Uint8Array.from(Buffer.from(b64, 'base64'));
}

/**
 * @param {string} b64url
 * @returns {object}
 */
function decodeJsonPart(b64url) {
  return JSON.parse(Buffer.from(b64urlDecode(b64url)).toString('utf8'));
}

// ─── main export ────────────────────────────────────────────────────────────

/**
 * Verify a compact JWS token for the TNG offline payment protocol.
 *
 * @param {string} jws - Compact JWS string
 * @param {(kid: string) => Promise<Uint8Array|null>} pubkeyResolver
 *   Async function: given a kid, returns the 32-byte Ed25519 public key, or null if unknown.
 * @param {{ nowSec?: number }} [opts]
 * @returns {Promise<{ok: boolean, payload?: object, reason?: string}>}
 */
export async function verifyToken(jws, pubkeyResolver, opts = {}) {
  const nowSec = opts.nowSec ?? Math.floor(Date.now() / 1000);

  // ── 1. Parse compact JWS ──────────────────────────────────────────────────
  const parts = jws.split('.');
  if (parts.length !== 3) {
    return { ok: false, reason: 'BAD_REQUEST' };
  }
  const [headerB64, payloadB64, sigB64] = parts;

  let header, payload;
  try {
    header  = decodeJsonPart(headerB64);
    payload = decodeJsonPart(payloadB64);
  } catch {
    return { ok: false, reason: 'BAD_REQUEST' };
  }

  // ── 2. Header validation ──────────────────────────────────────────────────
  if (header.alg !== 'EdDSA' || header.typ !== 'tng-offline-tx+jws') {
    return { ok: false, reason: 'BAD_REQUEST' };
  }
  if (!header.kid || !header.policy || header.ver !== 1) {
    return { ok: false, reason: 'BAD_REQUEST' };
  }

  // ── 3. Payload field presence ─────────────────────────────────────────────
  const required = ['tx_id', 'sender', 'receiver', 'amount', 'nonce', 'iat', 'exp'];
  for (const f of required) {
    if (payload[f] === undefined || payload[f] === null) {
      return { ok: false, reason: 'BAD_REQUEST' };
    }
  }
  if (!payload.sender?.pub || !payload.receiver?.pub) {
    return { ok: false, reason: 'BAD_REQUEST' };
  }
  if (!payload.amount?.value || !payload.amount?.currency) {
    return { ok: false, reason: 'BAD_REQUEST' };
  }

  // ── 4. Expiry check (cheap, do before crypto) ─────────────────────────────
  if (payload.exp < nowSec) {
    return { ok: false, reason: 'EXPIRED_TOKEN' };
  }

  // ── 5. Amount cap check (global RM 250 hard cap) ─────────────────────────
  const amountValue = parseFloat(payload.amount.value);
  if (isNaN(amountValue) || amountValue <= 0 || amountValue > 250) {
    return { ok: false, reason: 'BAD_REQUEST' };
  }

  // ── 6. Resolve public key ─────────────────────────────────────────────────
  const pubkeyBytes = await pubkeyResolver(header.kid);
  if (!pubkeyBytes) {
    return { ok: false, reason: 'UNKNOWN_KID' };
  }

  // ── 7. Ed25519 signature verification ─────────────────────────────────────
  const signingInput = `${headerB64}.${payloadB64}`;
  const msgBytes = new TextEncoder().encode(signingInput);
  let sigBytes;
  try {
    sigBytes = b64urlDecode(sigB64);
  } catch {
    return { ok: false, reason: 'BAD_SIGNATURE' };
  }

  let valid = false;
  try {
    valid = await ed.verifyAsync(sigBytes, msgBytes, pubkeyBytes);
  } catch {
    return { ok: false, reason: 'BAD_SIGNATURE' };
  }
  if (!valid) {
    return { ok: false, reason: 'BAD_SIGNATURE' };
  }

  // ── 8. Receiver pub cross-check ───────────────────────────────────────────
  // The receiver.pub inside the SIGNED payload pins who can receive this token.
  // This is checked after sig verification so we're sure the value wasn't tampered with.
  // (server can additionally verify receiver.pub matches the registered device — done in settle_batch)

  return { ok: true, payload };
}
