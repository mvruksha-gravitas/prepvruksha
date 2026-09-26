"""Worker configuration, read from the environment or a local `.env` file.

The Anthropic key comes from a local `.env` in development and from Secret
Manager in Cloud Run. Never commit a `.env`.
"""

from typing import Literal

from pydantic import SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    app_env: str = "local"
    supabase_url: str = "http://127.0.0.1:54321"
    supabase_secret_key: SecretStr | None = None

    # Claude API: question content only, never personal data (CLAUDE.md rule 3).
    anthropic_api_key: SecretStr | None = None
    # Parsing model and effort are settings, not code (PARSE_MODEL / PARSE_EFFORT).
    # Opus 5 at high until the real-file comparison with medium (docs/STATUS.md).
    parse_model: str = "claude-opus-5"
    parse_effort: Literal["low", "medium", "high", "xhigh", "max"] = "high"
