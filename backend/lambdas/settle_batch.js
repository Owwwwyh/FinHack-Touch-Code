/**
 * settle_batch.js
 *
 * AWS Lambda handler: processes a batch of JWS tokens for settlement.
 * This is the AUTHORITATIVE settlement step — all security checks happen here.
 *
 * Invoked from: Alibaba FC → Alibaba EventBridge → AWS EventBridge → this Lambda.
 * Emits: settlement.completed event back via cross-cloud bridge.
 *
 * docs/01-architecture.md §5.3
 * docs/03-token-protocol.md §7
 * docs/08-backend-api.md §3.5
 */

import { verifyToken } from '../core/ed25519_verifier.js';
import { getNonceStore } from '../core/nonce_store.js';
import { PubkeyRegistry } from '../core/token_service.js';

// ─── In-process pubkey registry (dev) ────────────────────────────────────────
// In production this resolves from DynamoDB cache warmed from Alibaba OSS.
let _registry = null;

function getRegistry() {
  if (!_registry) {
    _registry = new PubkeyRegistry();
  }
  return _registry;
}

/**
 * Register a device pubkey into the in-process registry.
 * In production this is replaced by DynamoDB + OSS lookup.
 * @param {string} kid
 * @param {Uint8Array} pubkeyBytes
 */
export function registerPubkey(kid, pubkeyBytes) {
  getRegistry().register(kid, pubkeyBytes);
}

// ─── Settlement result codes ──────────────────────────────────────────────────

const SETTLE_STATUS = {
  SETTLED:       'SETTLED',
  REJECTED:      'REJECTED',
};

// ─── Core settlement logic ────────────────────────────────────────────────────

/**
 * Process one JWS token.
 * Returns a result object for inclusion in the batch response.
 *
 * @param {string} jws
 * @param {{ nonceStore: object, pubkeyResolver: Function, nowSec?: number }} ctx
 * @returns {Promise<{tx_id: string, status: string, reason?: string, settled_at?: string}>}
 */
async function settleOneToken(jws, ctx) {
  const { nonceStore, pubkeyResolver, nowSec } = ctx;

  // ── Step 1: Verify JWS (signature, expiry, claims) ────────────────────────
  const result = await verifyToken(jws, pubkeyResolver, { nowSec });

  if (!result.ok) {
    // Extract tx_id even from a bad token if we can (for error reporting)
    let tx_id = 'UNKNOWN';
    try {
      const payloadB64 = jws.split('.')[1];
      const payload = JSON.parse(
        Buffer.from(payloadB64.replace(/-/g, '+').replace(/_/g, '/'), 'base64').toString('utf8')
      );
      tx_id = payload.tx_id ?? 'UNKNOWN';
    } catch { /* ignore */ }

    return {
      tx_id,
      status: SETTLE_STATUS.REJECTED,
      reason: result.reason,
    };
  }

  const payload = result.payload;
  const tx_id   = payload.tx_id;

  // ── Step 2: Nonce claim (double-spend prevention) ─────────────────────────
  // This is the ATOMIC gate — only one settlement per nonce survives.
  const claimed = await nonceStore.claimNonce(payload.nonce, tx_id);
  if (!claimed) {
    return {
      tx_id,
      status: SETTLE_STATUS.REJECTED,
      reason: 'NONCE_REUSED',
    };
  }

  // ── Step 3: Write to token ledger ─────────────────────────────────────────
  // In production: DynamoDB PutItem with conditional on tx_id uniqueness.
  // For Phase 1 local mode we skip the actual write and just return SETTLED.
  const settledAt = new Date().toISOString();

  // TODO (Phase 2): write to DynamoDB token_ledger
  // await dynamoDB.putItem({ TableName: process.env.DYNAMODB_TABLE_LEDGER, ... })

  return {
    tx_id,
    status:     SETTLE_STATUS.SETTLED,
    settled_at: settledAt,
  };
}

// ─── Lambda handler ───────────────────────────────────────────────────────────

/**
 * Lambda entry point.
 * Accepts an EventBridge event wrapping a SettleBatchRequest.
 *
 * For local testing, the event can also be passed directly as
 * { device_id, batch_id, tokens: [jws, ...] }.
 *
 * @param {object} event
 * @returns {Promise<object>} SettleBatchResponse
 */
export const handler = async (event) => {
  // Unwrap EventBridge envelope if present
  const body = event['detail'] ?? event;

  const { device_id, batch_id, tokens } = body;

  if (!Array.isArray(tokens) || tokens.length === 0) {
    return {
      statusCode: 400,
      body: JSON.stringify({ error: { code: 'BAD_REQUEST', message: 'tokens array required' } }),
    };
  }

  if (tokens.length > 50) {
    return {
      statusCode: 400,
      body: JSON.stringify({ error: { code: 'BAD_REQUEST', message: 'max 50 tokens per batch' } }),
    };
  }

  const nonceStore     = getNonceStore();
  const pubkeyResolver = getRegistry().resolver();
  const nowSec         = Math.floor(Date.now() / 1000);

  // Process all tokens (sequentially to preserve nonce atomicity in in-memory mode)
  const results = [];
  for (const jws of tokens) {
    const res = await settleOneToken(jws, { nonceStore, pubkeyResolver, nowSec });
    results.push(res);
  }

  const response = {
    batch_id,
    device_id,
    results,
  };

  // In production, also emit cross-cloud settlement.completed event here (B3).
  // Omitted for Phase 1 local mode.

  return {
    statusCode: 200,
    body: JSON.stringify(response),
  };
};
