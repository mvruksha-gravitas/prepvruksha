import pytest

from prepvruksha_pipeline.shared import Settings


def test_settings_read_from_environment(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("APP_ENV", "dev")
    monkeypatch.setenv("SUPABASE_SECRET_KEY", "not-a-real-key")
    settings = Settings(_env_file=None)  # type: ignore[call-arg]
    assert settings.app_env == "dev"
    assert settings.supabase_secret_key is not None
    assert "not-a-real-key" not in repr(settings)
