"""Worker configuration, read from the environment or a local `.env` file."""

from pydantic import SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    app_env: str = "local"
    supabase_url: str = "http://127.0.0.1:54321"
    supabase_secret_key: SecretStr | None = None
