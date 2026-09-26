"""Parent consent codes: generation, hashing and delivery.

Only an HMAC of the code is stored in the database; the raw code exists only
in memory here and in the SMS.
"""

import hashlib
import hmac
import logging
import secrets
from functools import lru_cache
from typing import Protocol

from prepvruksha_api.settings import get_settings

logger = logging.getLogger(__name__)


def generate_code() -> str:
    return f"{secrets.randbelow(1_000_000):06d}"


def hash_code(key: bytes, user_id: str, code: str) -> str:
    """Keyed hash bound to the user, so a leaked hash cannot be brute-forced offline."""
    return hmac.new(key, f"{user_id}:{code}".encode(), hashlib.sha256).hexdigest()


def mask_phone(phone: str) -> str:
    return f"+{phone[:2]} ******{phone[-4:]}"


class OtpSender(Protocol):
    def send_parent_consent_code(self, phone: str, code: str) -> None: ...


class LogOtpSender:
    """Development only: writes the code to the service log instead of sending an SMS."""

    def send_parent_consent_code(self, phone: str, code: str) -> None:
        logger.warning("DEV parent consent code for %s: %s", mask_phone(phone), code)


class ParentCodeIssuer:
    """Creates a code for a parent number; test numbers get their fixed code and no SMS."""

    def __init__(self, key: bytes, sender: OtpSender, test_codes: dict[str, str]) -> None:
        self._key = key
        self._sender = sender
        self._test_codes = test_codes

    def new_code(self, parent_phone: str) -> str:
        return self._test_codes.get(parent_phone) or generate_code()

    def hash(self, user_id: str, code: str) -> str:
        return hash_code(self._key, user_id, code)

    def send(self, parent_phone: str, code: str) -> None:
        if parent_phone in self._test_codes:
            return
        self._sender.send_parent_consent_code(parent_phone, code)


@lru_cache
def get_code_issuer() -> ParentCodeIssuer:
    settings = get_settings()
    if settings.otp_hmac_key is None:
        raise RuntimeError("OTP_HMAC_KEY is not set")
    return ParentCodeIssuer(
        settings.otp_hmac_key.get_secret_value().encode(),
        LogOtpSender(),
        settings.parent_otp_test_codes,
    )
