"""Service configuration, read from the environment or a local `.env` file.

In Cloud Run the values come from Secret Manager. Never commit a `.env`.
"""

from functools import lru_cache
from typing import Literal

from pydantic import SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    app_env: Literal["local", "dev", "prod", "test"] = "local"
    supabase_url: str = "http://127.0.0.1:54321"
    # Secret (service role) key: bypasses RLS. Only ever used inside services/*.
    supabase_secret_key: SecretStr | None = None

    # Browser origins allowed to call the API (Flutter web). Local runs use a
    # random localhost port.
    cors_origin_regex: str = r"^http://(localhost|127\.0\.0\.1)(:\d+)?$"

    # Key for hashing parent consent codes (HMAC-SHA256). Only the hash is stored.
    otp_hmac_key: SecretStr | None = None
    # How parent consent codes are delivered. "log" writes the code to the
    # service log (local/dev only) until the DLT-registered SMS provider is chosen.
    parent_otp_sender: Literal["log"] = "log"
    # Test parent numbers with fixed codes; nothing is sent to them. JSON, e.g.
    # PARENT_OTP_TEST_CODES='{"919999900006": "123456"}'. Must be empty in prod.
    parent_otp_test_codes: dict[str, str] = {}

    @property
    def jwks_url(self) -> str:
        return f"{self.supabase_url}/auth/v1/.well-known/jwks.json"

    @property
    def jwt_issuer(self) -> str:
        return f"{self.supabase_url}/auth/v1"

    def check_production_safety(self) -> None:
        """Refuse to start prod with development-only OTP settings."""
        if self.app_env != "prod":
            return
        if self.parent_otp_sender == "log":
            raise RuntimeError("prod needs a real SMS sender for parent consent codes")
        if self.parent_otp_test_codes:
            raise RuntimeError("PARENT_OTP_TEST_CODES must be empty in prod")


@lru_cache
def get_settings() -> Settings:
    return Settings()
