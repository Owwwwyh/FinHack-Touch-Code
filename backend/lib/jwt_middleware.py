"""
JWT verification middleware for Cognito-issued tokens.
Verifies RS256 JWTs, caches JWKS for up to 1 hour.
"""
import logging
import os
import time
from typing import Dict, Optional

import requests

logger = logging.getLogger(__name__)

_DEMO_MODE_WARNING_LOGGED = False


class JwtVerificationError(Exception):
    def __init__(self, code: str, message: str):
        self.code = code
        super().__init__(message)


class JwtMiddleware:
    def __init__(self, jwks_url: str, issuer: str, cache_ttl: int = 3600):
        self._jwks_url = jwks_url
        self._issuer = issuer
        self._cache_ttl = cache_ttl
        self._jwks_cache: Dict[str, dict] = {}
        self._jwks_fetched_at: float = 0

    def _get_jwks(self) -> Dict[str, dict]:
        now = time.time()
        if now - self._jwks_fetched_at > self._cache_ttl:
            resp = requests.get(self._jwks_url, timeout=5)
            resp.raise_for_status()
            data = resp.json()
            self._jwks_cache = {k["kid"]: k for k in data["keys"]}
            self._jwks_fetched_at = now
        return self._jwks_cache

    def verify(self, token: str) -> dict:
        if not token:
            raise JwtVerificationError("UNAUTHENTICATED", "Missing token")

        import jwt
        from jwt.algorithms import RSAAlgorithm

        try:
            header = jwt.get_unverified_header(token)
        except Exception as e:
            raise JwtVerificationError("UNAUTHENTICATED", f"Malformed token: {e}")

        kid = header.get("kid")
        jwks = self._get_jwks()
        if kid not in jwks:
            # Retry once in case of key rotation
            self._jwks_fetched_at = 0
            jwks = self._get_jwks()
            if kid not in jwks:
                raise JwtVerificationError("UNAUTHENTICATED", f"Unknown kid: {kid}")

        public_key = RSAAlgorithm.from_jwk(jwks[kid])
        try:
            claims = jwt.decode(
                token,
                public_key,
                algorithms=["RS256"],
                issuer=self._issuer,
            )
        except jwt.ExpiredSignatureError:
            raise JwtVerificationError("UNAUTHENTICATED", "Token expired")
        except jwt.InvalidIssuerError:
            raise JwtVerificationError("UNAUTHENTICATED", "Invalid issuer")
        except Exception as e:
            raise JwtVerificationError("UNAUTHENTICATED", str(e))

        return claims


class _DemoJwtMiddleware:
    """Pass-through middleware for local demo when Cognito is not configured."""

    def verify(self, token: str) -> dict:
        global _DEMO_MODE_WARNING_LOGGED
        if not _DEMO_MODE_WARNING_LOGGED:
            logger.warning("DEMO MODE: JWT verification disabled (COGNITO_JWKS_URL not set)")
            _DEMO_MODE_WARNING_LOGGED = True
        return {"sub": "demo_user", "cognito:username": "demo"}


_middleware_instance: Optional[JwtMiddleware] = None


def get_jwt_middleware():
    global _middleware_instance
    jwks_url = os.environ.get("COGNITO_JWKS_URL", "")
    issuer = os.environ.get("COGNITO_ISSUER", "")
    if not jwks_url:
        return _DemoJwtMiddleware()
    if _middleware_instance is None:
        _middleware_instance = JwtMiddleware(jwks_url, issuer)
    return _middleware_instance
