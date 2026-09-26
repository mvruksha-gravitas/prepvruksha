"""Worker configuration, read from the environment or a local `.env` file.

The Anthropic key comes from a local `.env` in development and from Secret
Manager in Cloud Run. Never commit a `.env`.
"""

from pydantic import SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    app_env: str = "local"
    supabase_url: str = "http://127.0.0.1:54321"
    supabase_secret_key: SecretStr | None = None

    # Claude API: question content only, never personal data (CLAUDE.md rule 3).
    anthropic_api_key: SecretStr | None = None
    parse_model: str = "claude-opus-5"
