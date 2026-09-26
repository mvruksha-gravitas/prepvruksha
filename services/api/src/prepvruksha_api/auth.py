"""Supabase JWT verification.

Supabase signs access tokens with an asymmetric key (ES256/RS256) published
at /auth/v1/.well-known/jwks.json. Keys are cached, so most requests make no
network call.
"""

from functools import lru_cache
from typing import Annotated

import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from prepvruksha_api.settings import get_settings


class JwtVerifier:
    def __init__(self, jwks_url: str, issuer: str) -> None:
        self._jwks = jwt.PyJWKClient(jwks_url, cache_keys=True, lifespan=600)
        self._issuer = issuer

    def user_id(self, token: str) -> str:
        """Return the user id (sub) of a valid signed-in user's token, or raise jwt.PyJWTError."""
        key = self._jwks.get_signing_key_from_jwt(token)
        claims = jwt.decode(
            token,
            key.key,
            algorithms=["ES256", "RS256"],
            audience="authenticated",
            issuer=self._issuer,
            options={"require": ["exp", "sub"]},
        )
        if claims.get("role") != "authenticated" or claims.get("is_anonymous"):
            raise jwt.InvalidTokenError("not a signed-in user")
        return str(claims["sub"])


@lru_cache
def get_verifier() -> JwtVerifier:
    settings = get_settings()
    return JwtVerifier(settings.jwks_url, settings.jwt_issuer)


_bearer = HTTPBearer(auto_error=False)


def current_user_id(
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(_bearer)],
    verifier: Annotated[JwtVerifier, Depends(get_verifier)],
) -> str:
    if credentials is None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, detail={"code": "not_signed_in"})
    try:
        return verifier.user_id(credentials.credentials)
    except jwt.PyJWTError as error:
        raise HTTPException(
            status.HTTP_401_UNAUTHORIZED, detail={"code": "invalid_token"}
        ) from error
