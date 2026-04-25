"""Alibaba FC: wallet-balance handler.

Per docs/08-backend-api.md §3.3:
- GET /v1/wallet/balance
- Returns authoritative balance + server-side safe_offline_balance
"""

import json
import os
import logging
import time

logger = logging.getLogger()

def handler(event, context):
    """FC handler for GET /wallet/balance"""
    try:
        # Parse JWT claims (set by API Gateway auth plugin)
        headers = event.get('headers', {})
        auth_header = headers.get('authorization', headers.get('Authorization', ''))
        
        # TODO: Verify JWT with Cognito JWKS
        # For demo, extract user_id from path or header
        user_id = event.get('pathParameters', {}).get('user_id', 'u_8412')
        
        # TODO: Read from Tablestore
        # Mock response for demo
        balance_myr = "248.50"
        safe_offline_myr = "120.00"
        
        response = {
            "user_id": user_id,
            "balance_myr": balance_myr,
            "currency": "MYR",
            "version": 4321,
            "as_of": time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
            "safe_offline_balance_myr": safe_offline_myr,
            "policy_version": "v3.2026-04-22",
        }
        
        return {
            "isBase64Encoded": False,
            "statusCode": 200,
            "headers": {"Content-Type": "application/json; charset=utf-8"},
            "body": json.dumps(response),
        }
    except Exception as e:
        logger.error(f"wallet-balance error: {e}")
        return {
            "isBase64Encoded": False,
            "statusCode": 500,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"error": {"code": "INTERNAL", "message": str(e)}}),
        }
