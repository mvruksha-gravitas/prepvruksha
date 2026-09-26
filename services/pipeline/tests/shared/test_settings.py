import pytest

from prepvruksha_pipeline.shared import Settings


def test_settings_read_from_environment(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("APP_ENV", "dev")
    monkeypatch.setenv("SUPABASE_SECRET_KEY", "not-a-real-key")
    settings = Settings(_env_file=None)  # type: ignore[call-arg]
    assert settings.app_env == "dev"
    assert settings.supabase_secret_key is not None
    assert "not-a-real-key" not in repr(settings)


def test_model_and_effort_are_settings(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("PARSE_MODEL", raising=False)
    monkeypatch.delenv("PARSE_EFFORT", raising=False)
    defaults = Settings(_env_file=None)  # type: ignore[call-arg]
    assert (defaults.parse_model, defaults.parse_effort) == ("claude-opus-5", "high")
    monkeypatch.setenv("PARSE_EFFORT", "medium")
    assert Settings(_env_file=None).parse_effort == "medium"  # type: ignore[call-arg]
