"""
JWS (JSON Web Signature) verifier for RFC 7515
Verifies Ed25519 signatures on TNG offline payment tokens
"""

import base64
import json
import time
from typing import Any, Dict, Optional, Tuple

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ed25519
from cryptography.exceptions import InvalidSignature


class JwsVerificationError(Exception):
    """Raised when JWS verification fails"""

    def __init__(self, code: str, message: str):
        self.code = code
        self.message = message
        super().__init__(f"{code}: {message}")


class JwsVerifier:
    """Verifies JWS tokens signed with Ed25519"""

    ALGORITHM = "EdDSA"
    TOKEN_TYPE = "tng-offline-tx+jws"

    @staticmethod
    def base64url_decode(data: str) -> bytes:
        """Decode base64url with optional padding"""
        # Add padding if needed
        padding = 4 - (len(data) % 4)
        if padding != 4:
            data += "=" * padding
        try:
            return base64.urlsafe_b64decode(data)
        except Exception as e:
            raise JwsVerificationError("INVALID_BASE64", f"Failed to decode base64url: {str(e)}")

    @staticmethod
    def base64url_encode(data: bytes) -> str:
        """Encode bytes to base64url without padding"""
        encoded = base64.urlsafe_b64encode(data).decode("ascii")
        return encoded.rstrip("=")

    @classmethod
    def verify_compact(cls, token: str, public_key_b64: str) -> Dict[str, Any]:
        """
        Verify a compact JWS token and extract the payload
        
        Args:
            token: Compact JWS string (header.payload.signature)
            public_key_b64: Base64url-encoded Ed25519 public key (32 bytes)
            
        Returns:
            {
                "valid": bool,
                "payload": dict (if valid),
                "error": str (if invalid),
                "message": str (error details)
            }
        """
        try:
            # Split JWS into 3 parts
            parts = token.split(".")
            if len(parts) != 3:
                return {
                    "valid": False,
                    "error": "INVALID_FORMAT",
                    "message": "JWS must have exactly 3 parts (header.payload.signature)",
                }

            header_b64, payload_b64, signature_b64 = parts

            # Decode and parse header
            try:
                header_bytes = cls.base64url_decode(header_b64)
                header = json.loads(header_bytes.decode("utf-8"))
            except Exception as e:
                return {"valid": False, "error": "INVALID_HEADER", "message": str(e)}

            # Validate header fields
            if header.get("alg") != cls.ALGORITHM:
                return {
                    "valid": False,
                    "error": "INVALID_ALG",
                    "message": f"alg must be {cls.ALGORITHM}",
                }

            if header.get("typ") != cls.TOKEN_TYPE:
                return {
                    "valid": False,
                    "error": "INVALID_TYP",
                    "message": f"typ must be {cls.TOKEN_TYPE}",
                }

            if not header.get("kid"):
                return {"valid": False, "error": "MISSING_KID", "message": "kid is required"}

            # Decode and parse payload
            try:
                payload_bytes = cls.base64url_decode(payload_b64)
                payload = json.loads(payload_bytes.decode("utf-8"))
            except Exception as e:
                return {"valid": False, "error": "INVALID_PAYLOAD", "message": str(e)}

            # Validate required payload fields
            required_fields = ["tx_id", "sender", "receiver", "amount", "nonce", "iat", "exp"]
            for field in required_fields:
                if field not in payload:
                    return {
                        "valid": False,
                        "error": "MISSING_FIELD",
                        "message": f"payload.{field} is required",
                    }

            # Check expiration
            exp = payload.get("exp")
            if not isinstance(exp, int):
                return {"valid": False, "error": "INVALID_EXP", "message": "exp must be an integer"}

            now_seconds = int(time.time())
            if now_seconds > exp:
                return {
                    "valid": False,
                    "error": "EXPIRED_TOKEN",
                    "message": f"Token expired at {exp}, now {now_seconds}",
                }

            # Decode signature
            try:
                signature = cls.base64url_decode(signature_b64)
            except Exception as e:
                return {"valid": False, "error": "INVALID_SIGNATURE", "message": str(e)}

            if len(signature) != 64:
                return {
                    "valid": False,
                    "error": "BAD_SIGNATURE",
                    "message": "Ed25519 signature must be 64 bytes",
                }

            # Decode public key
            try:
                public_key_bytes = cls.base64url_decode(public_key_b64)
                if len(public_key_bytes) != 32:
                    raise ValueError("Ed25519 public key must be 32 bytes")
                public_key = ed25519.Ed25519PublicKey.from_public_bytes(public_key_bytes)
            except Exception as e:
                return {
                    "valid": False,
                    "error": "INVALID_PUBLIC_KEY",
                    "message": f"Failed to parse public key: {str(e)}",
                }

            # Verify signature
            message = f"{header_b64}.{payload_b64}".encode("utf-8")
            try:
                public_key.verify(signature, message)
            except InvalidSignature:
                return {
                    "valid": False,
                    "error": "BAD_SIGNATURE",
                    "message": "Signature verification failed",
                }
            except Exception as e:
                return {
                    "valid": False,
                    "error": "VERIFY_ERROR",
                    "message": f"Verification error: {str(e)}",
                }

            return {"valid": True, "payload": payload}

        except Exception as e:
            return {"valid": False, "error": "UNKNOWN_ERROR", "message": str(e)}

    @classmethod
    def verify_and_extract_payload(
        cls, token: str, public_key_b64: str
    ) -> Tuple[bool, Optional[Dict[str, Any]], Optional[str]]:
        """
        Convenience method to verify token and extract payload
        
        Returns:
            (valid: bool, payload: dict | None, error_code: str | None)
        """
        result = cls.verify_compact(token, public_key_b64)
        if result["valid"]:
            return True, result.get("payload"), None
        else:
            return False, None, result.get("error")
