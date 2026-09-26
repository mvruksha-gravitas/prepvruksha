"""Environment configuration shared by all features, read from the environment or `.env`.

Feature-specific settings live in the feature (e.g. `consent/config.py`).

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

    @property
    def jwks_url(self) -> str:
        return f"{self.supabase_url}/auth/v1/.well-known/jwks.json"

    @property
    def jwt_issuer(self) -> str:
        return f"{self.supabase_url}/auth/v1"


@lru_cache
def get_settings() -> Settings:
    return Settings()
