"""Cognito JWT verification for Lambda authorisation."""
from __future__ import annotations

import json
import os
import time
import urllib.request
from functools import lru_cache
from typing import Any

import jwt  # python-jose or PyJWT — added via Lambda layer


class AuthError(Exception):
    """Raised for any authentication failure (returns 401)."""


# ---------------------------------------------------------------------------
# JWKS cache
# ---------------------------------------------------------------------------

@lru_cache(maxsize=1)
def _get_jwks(jwks_uri: str) -> dict[str, Any]:
    """Fetch and cache the Cognito JWKS (public keys)."""
    with urllib.request.urlopen(jwks_uri, timeout=5) as resp:
        return json.loads(resp.read())


def _jwks_uri() -> str:
    pool_id = os.environ["COGNITO_USER_POOL_ID"]
    region = os.environ.get("AWS_REGION", "us-east-1")
    return (
        f"https://cognito-idp.{region}.amazonaws.com/{pool_id}"
        "/.well-known/jwks.json"
    )


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def verify_cognito_jwt(auth_header: str | None) -> str:
    """Validate a Cognito Bearer token and return the ``user_id`` (``sub``).

    Raises :class:`AuthError` if the token is absent, malformed, expired,
    or fails signature verification.
    """
    if not auth_header or not auth_header.startswith("Bearer "):
        raise AuthError("Missing or malformed Authorization header")

    token = auth_header[len("Bearer "):]

    # Decode header without verification first to get the key ID.
    try:
        unverified_header = jwt.get_unverified_header(token)
    except Exception as exc:
        raise AuthError(f"Invalid token header: {exc}") from exc

    kid = unverified_header.get("kid")
    if not kid:
        raise AuthError("Token header missing 'kid'")

    # Fetch JWKS and find the matching public key.
    jwks = _get_jwks(_jwks_uri())
    key = next(
        (k for k in jwks.get("keys", []) if k.get("kid") == kid),
        None,
    )
    if key is None:
        raise AuthError(f"No matching JWKS key for kid={kid}")

    # Verify and decode.
    try:
        client_id = os.environ["COGNITO_CLIENT_ID"]
        payload = jwt.decode(
            token,
            key,
            algorithms=["RS256"],
            audience=client_id,
            options={"require": ["exp", "iat", "sub"]},
        )
    except jwt.ExpiredSignatureError as exc:
        raise AuthError("Token expired") from exc
    except Exception as exc:
        raise AuthError(f"Token verification failed: {exc}") from exc

    # Extra: reject tokens issued far in the future (clock skew guard).
    if payload.get("iat", 0) > time.time() + 300:
        raise AuthError("Token issued in the future")

    user_id: str | None = payload.get("sub")
    if not user_id:
        raise AuthError("Token missing 'sub' claim")

    return user_id
