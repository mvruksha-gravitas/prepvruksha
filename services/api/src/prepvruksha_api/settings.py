"""Service configuration, read from the environment or a local `.env` file.

In Cloud Run the values come from Secret Manager. Never commit a `.env`.
"""

from functools import lru_cache

from pydantic import SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    app_env: str = "local"
    supabase_url: str = "http://127.0.0.1:54321"
    # Secret (service role) key: bypasses RLS. Only ever used inside services/*.
    supabase_secret_key: SecretStr | None = None


@lru_cache
def get_settings() -> Settings:
    return Settings()
