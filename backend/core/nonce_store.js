/**
 * nonce_store.js
 *
 * Replay protection via a "first-write-wins" nonce store.
 * In production this maps to DynamoDB `nonce_seen` with:
 *   - Partition key: nonce (string)
 *   - Attribute: tx_id (string), first_seen (number TTL epoch)
 *   - Conditional put: attribute_not_exists(nonce)
 *
 * For local development / tests the in-memory store is used automatically
 * unless DYNAMODB_TABLE_NONCE env var is set.
 *
 * docs/03-token-protocol.md §6.1 / docs/09-data-model.md
 */

// ─── In-memory store (dev/test) ──────────────────────────────────────────────

class InMemoryNonceStore {
  constructor() {
    /** @type {Map<string, {txId: string, firstSeen: number}>} */
    this._map = new Map();
  }

  /**
   * Try to claim a nonce for a given txId.
   * Returns true if this is the first time the nonce is seen (claim succeeded).
   * Returns false if the nonce was already seen (double-spend attempt).
   *
   * @param {string} nonce - Base64URL-encoded 128-bit random value
   * @param {string} txId  - UUIDv7 of the token
   * @returns {Promise<boolean>}
   */
  async claimNonce(nonce, txId) {
    if (this._map.has(nonce)) {
      return false; // already seen — reject
    }
    this._map.set(nonce, { txId, firstSeen: Math.floor(Date.now() / 1000) });
    return true;
  }

  /**
   * For testing: release a nonce.
   * @param {string} nonce
   */
  _release(nonce) {
    this._map.delete(nonce);
  }
}

// ─── DynamoDB store (production) ─────────────────────────────────────────────

class DynamoNonceStore {
  constructor(tableName, dynamoClient) {
    this._table = tableName;
    this._dynamo = dynamoClient;
    // TTL = 30 days (exceeds max token validity of 72h with generous margin)
    this._ttlSecs = 30 * 24 * 60 * 60;
  }

  /**
   * Conditional put: attribute_not_exists(nonce) — DynamoDB's atomic first-write-wins.
   * @param {string} nonce
   * @param {string} txId
   * @returns {Promise<boolean>}
   */
  async claimNonce(nonce, txId) {
    const ttl = Math.floor(Date.now() / 1000) + this._ttlSecs;
    try {
      await this._dynamo.putItem({
        TableName: this._table,
        Item: {
          nonce:      { S: nonce },
          tx_id:      { S: txId },
          first_seen: { N: String(Math.floor(Date.now() / 1000)) },
          ttl:        { N: String(ttl) },
        },
        ConditionExpression: 'attribute_not_exists(nonce)',
      }).promise();
      return true; // put succeeded → first seen
    } catch (err) {
      if (err.code === 'ConditionalCheckFailedException') {
        return false; // nonce already exists → double-spend
      }
      throw err; // propagate unexpected errors
    }
  }
}

// ─── Factory ─────────────────────────────────────────────────────────────────

let _defaultStore = null;

/**
 * Get the singleton nonce store.
 * Uses DynamoDB if DYNAMODB_TABLE_NONCE env var is set, otherwise in-memory.
 *
 * @param {{ dynamoClient?: object }} [opts]
 * @returns {InMemoryNonceStore | DynamoNonceStore}
 */
export function getNonceStore(opts = {}) {
  if (_defaultStore) return _defaultStore;

  const tableName = process.env.DYNAMODB_TABLE_NONCE;
  if (tableName && opts.dynamoClient) {
    _defaultStore = new DynamoNonceStore(tableName, opts.dynamoClient);
  } else {
    _defaultStore = new InMemoryNonceStore();
  }
  return _defaultStore;
}

/** Reset singleton — useful in tests. */
export function _resetNonceStore() {
  _defaultStore = null;
}

export { InMemoryNonceStore, DynamoNonceStore };
