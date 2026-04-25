/**
 * server.js
 *
 * Local development server that mounts all Function Compute handlers
 * as Express routes. NOT for production — Lambda/FC have their own runtimes.
 *
 * Run: node fc/server.js
 * Base URL: http://localhost:3000
 */

import http from 'node:http';
import { devicesRegister, deviceStore } from './devices_register.js';
import { handler as settleBatch } from '../lambdas/settle_batch.js';
import { registerPubkey } from '../lambdas/settle_batch.js';
import { getNonceStore, _resetNonceStore } from '../core/nonce_store.js';

const PORT = process.env.PORT ?? 3000;

// ─── Minimal JSON router ──────────────────────────────────────────────────────

async function readBody(req) {
  return new Promise((resolve, reject) => {
    let data = '';
    req.on('data', chunk => data += chunk);
    req.on('end',  () => {
      try { resolve(data ? JSON.parse(data) : {}); }
      catch (e) { reject(e); }
    });
    req.on('error', reject);
  });
}

function respond(res, statusCode, body) {
  const json = JSON.stringify(body);
  res.writeHead(statusCode, {
    'Content-Type': 'application/json; charset=utf-8',
    'X-API-Version': 'v1',
  });
  res.end(json);
}

// ─── Route handlers ───────────────────────────────────────────────────────────

async function handleDevicesRegister(req, res) {
  if (req.method !== 'POST') return respond(res, 405, { error: { code: 'METHOD_NOT_ALLOWED' } });
  const body = await readBody(req);
  const result = await devicesRegister(body);
  const { statusCode, ...rest } = result;
  respond(res, statusCode, rest);
}

async function handleWalletBalance(req, res) {
  if (req.method !== 'GET') return respond(res, 405, { error: { code: 'METHOD_NOT_ALLOWED' } });
  // Stub: return demo balance
  respond(res, 200, {
    user_id:                  'u_demo',
    balance_myr:              '248.50',
    currency:                 'MYR',
    version:                  1,
    as_of:                    new Date().toISOString(),
    safe_offline_balance_myr: '120.00',
    policy_version:           'v1.demo',
  });
}

async function handleTokensSettle(req, res) {
  if (req.method !== 'POST') return respond(res, 405, { error: { code: 'METHOD_NOT_ALLOWED' } });
  const body = await readBody(req);
  const lambdaResult = await settleBatch(body);
  respond(res, lambdaResult.statusCode, JSON.parse(lambdaResult.body));
}

async function handleScoreRefresh(req, res) {
  if (req.method !== 'POST') return respond(res, 405, { error: { code: 'METHOD_NOT_ALLOWED' } });
  const body = await readBody(req);
  const cachedBalance = 248.50;
  const kycTier = body?.features?.kyc_tier ?? 1;
  const tierCap = kycTier === 0 ? 20 : kycTier === 2 ? 500 : 150;
  const safeBalance = Math.min(cachedBalance * 0.6, tierCap, 250).toFixed(2);
  respond(res, 200, {
    safe_offline_balance_myr: safeBalance,
    confidence:               0.82,
    policy_version:           body?.policy_version ?? 'v1.demo',
    computed_at:              new Date().toISOString(),
  });
}

async function handlePublicKey(req, res, kid) {
  if (req.method !== 'GET') return respond(res, 405, { error: { code: 'METHOD_NOT_ALLOWED' } });
  // Look up in device store
  let found = null;
  for (const [k, d] of deviceStore.entries()) {
    if (k === kid || d.kid === kid) { found = d; break; }
  }
  if (!found) return respond(res, 404, { error: { code: 'NOT_FOUND' } });
  respond(res, 200, {
    kid:           found.kid,
    alg:           found.alg,
    public_key:    found.public_key,
    status:        found.status,
    registered_at: found.registered_at,
    revoked_at:    null,
  });
}

// ─── HTTP server ──────────────────────────────────────────────────────────────

const server = http.createServer(async (req, res) => {
  const url = req.url.split('?')[0]; // strip query string
  try {
    if (url === '/v1/devices/register')    return await handleDevicesRegister(req, res);
    if (url === '/v1/wallet/balance')      return await handleWalletBalance(req, res);
    if (url === '/v1/tokens/settle')       return await handleTokensSettle(req, res);
    if (url === '/v1/score/refresh')       return await handleScoreRefresh(req, res);
    if (url.startsWith('/v1/publickeys/')) {
      const kid = url.replace('/v1/publickeys/', '');
      return await handlePublicKey(req, res, kid);
    }
    respond(res, 404, { error: { code: 'NOT_FOUND', message: `No route for ${url}` } });
  } catch (err) {
    console.error('Unhandled error:', err);
    respond(res, 500, { error: { code: 'INTERNAL', message: err.message } });
  }
});

server.listen(PORT, () => {
  console.log(`TNG Offline Wallet backend running on http://localhost:${PORT}`);
  console.log('Routes:');
  console.log('  POST /v1/devices/register');
  console.log('  GET  /v1/wallet/balance');
  console.log('  POST /v1/tokens/settle');
  console.log('  POST /v1/score/refresh');
  console.log('  GET  /v1/publickeys/:kid');
});

export default server;
