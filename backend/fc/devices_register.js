/**
 * devices_register.js
 *
 * Alibaba Function Compute handler: POST /v1/devices/register
 *
 * Stores device pubkey + attestation, returns kid + policy.
 * docs/08-backend-api.md §3.1
 */

import { registerPubkey } from '../lambdas/settle_batch.js';

// In-memory device store (Phase 1 local; replace with Tablestore in Phase 2)
const deviceStore = new Map();

/**
 * @param {object} req  - { user_id, device_label, public_key (base64url 32B), alg }
 * @returns {object}    - { device_id, kid, policy_version, initial_safe_offline_balance_myr }
 */
export async function devicesRegister(req) {
  const { user_id, device_label, public_key, alg = 'EdDSA' } = req;

  if (!user_id || !public_key) {
    return { statusCode: 400, error: { code: 'BAD_REQUEST', message: 'user_id and public_key required' } };
  }

  // Generate a deterministic kid from user_id + timestamp
  const kid = `did:tng:device:${Date.now().toString(36).toUpperCase()}`;

  // Decode and register pubkey into the in-process registry (for Phase 1 settlement)
  const pubkeyBytes = Buffer.from(
    public_key.replace(/-/g, '+').replace(/_/g, '/'),
    'base64'
  );
  registerPubkey(kid, new Uint8Array(pubkeyBytes));

  // Store device record
  const device = {
    kid,
    user_id,
    device_label,
    alg,
    public_key,
    status: 'ACTIVE',
    registered_at: new Date().toISOString(),
  };
  deviceStore.set(kid, device);

  return {
    statusCode: 200,
    device_id:                       kid,
    kid,
    policy_version:                  'v1.demo',
    initial_safe_offline_balance_myr: '50.00',
    registered_at:                   device.registered_at,
  };
}

export { deviceStore };
