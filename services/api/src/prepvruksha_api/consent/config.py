"""Consent settings: parent consent codes. Read from the environment or `.env`.

In Cloud Run the key comes from Secret Manager. Never commit a `.env`.
"""

from functools import lru_cache
from typing import Literal

from pydantic import SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict


class ConsentSettings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # Key for hashing parent consent codes (HMAC-SHA256). Only the hash is stored.
    otp_hmac_key: SecretStr | None = None
    # How parent consent codes are delivered. "log" writes the code to the
    # service log (local/dev only) until the DLT-registered SMS provider is chosen.
    parent_otp_sender: Literal["log"] = "log"
    # Test parent numbers with fixed codes; nothing is sent to them. JSON, e.g.
    # PARENT_OTP_TEST_CODES='{"919999900006": "123456"}'. Must be empty in prod.
    parent_otp_test_codes: dict[str, str] = {}

    def check_production_safety(self, app_env: str) -> None:
        """Refuse to start prod with development-only OTP settings."""
        if app_env != "prod":
            return
        if self.parent_otp_sender == "log":
            raise RuntimeError("prod needs a real SMS sender for parent consent codes")
        if self.parent_otp_test_codes:
            raise RuntimeError("PARENT_OTP_TEST_CODES must be empty in prod")


@lru_cache
def get_consent_settings() -> ConsentSettings:
    return ConsentSettings()


def check_production_safety(app_env: str) -> None:
    get_consent_settings().check_production_safety(app_env)
