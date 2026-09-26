import time
from typing import Any

import jwt
import pytest
from cryptography.hazmat.primitives.asymmetric import ec

from prepvruksha_api.auth import JwtVerifier

ISSUER = "http://127.0.0.1:54321/auth/v1"
PRIVATE_KEY = ec.generate_private_key(ec.SECP256R1())


class StaticKey:
    key = PRIVATE_KEY.public_key()


class StaticJwks:
    def get_signing_key_from_jwt(self, token: str) -> StaticKey:
        return StaticKey()


def verifier() -> JwtVerifier:
    v = JwtVerifier("http://unused/jwks.json", ISSUER)
    v._jwks = StaticJwks()  # type: ignore[assignment]
    return v


def token(**overrides: Any) -> str:
    claims: dict[str, Any] = {
        "sub": "user-1",
        "aud": "authenticated",
        "iss": ISSUER,
        "role": "authenticated",
        "exp": int(time.time()) + 60,
    }
    claims.update(overrides)
    return jwt.encode({k: v for k, v in claims.items() if v is not None}, PRIVATE_KEY, "ES256")


def test_valid_token_gives_the_user_id() -> None:
    assert verifier().user_id(token()) == "user-1"


@pytest.mark.parametrize(
    "overrides",
    [
        {"exp": int(time.time()) - 10},
        {"aud": "other"},
        {"iss": "https://evil.example/auth/v1"},
        {"role": "anon"},
        {"is_anonymous": True},
        {"sub": None},
    ],
)
def test_invalid_tokens_are_rejected(overrides: dict[str, Any]) -> None:
    with pytest.raises(jwt.PyJWTError):
        verifier().user_id(token(**overrides))


def test_a_token_signed_by_another_key_is_rejected() -> None:
    other = ec.generate_private_key(ec.SECP256R1())
    forged = jwt.encode(
        {
            "sub": "u",
            "aud": "authenticated",
            "iss": ISSUER,
            "role": "authenticated",
            "exp": int(time.time()) + 60,
        },
        other,
        "ES256",
    )
    with pytest.raises(jwt.PyJWTError):
        verifier().user_id(forged)
