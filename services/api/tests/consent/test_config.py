import os
import subprocess
import sys
from pathlib import Path

import pytest

from prepvruksha_api.consent.config import ConsentSettings

TEST_CODES = {"919999900006": "123456"}


def test_prod_refuses_the_log_sender() -> None:
    with pytest.raises(RuntimeError, match="real SMS sender"):
        ConsentSettings().check_production_safety("prod")


def test_prod_refuses_test_parent_numbers() -> None:
    # "log" is the only sender today, so bypass validation to isolate the
    # test-codes check for when a real sender exists.
    settings = ConsentSettings.model_construct(
        parent_otp_sender="sms", parent_otp_test_codes=TEST_CODES
    )
    with pytest.raises(RuntimeError, match="PARENT_OTP_TEST_CODES must be empty in prod"):
        settings.check_production_safety("prod")


@pytest.mark.parametrize("app_env", ["local", "dev", "test"])
def test_other_environments_allow_test_numbers(app_env: str) -> None:
    ConsentSettings(parent_otp_test_codes=TEST_CODES).check_production_safety(app_env)


def test_test_codes_are_read_from_the_environment(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("PARENT_OTP_TEST_CODES", '{"919999900007": "123456"}')
    settings = ConsentSettings(_env_file=None)  # type: ignore[call-arg]
    assert settings.parent_otp_test_codes == {"919999900007": "123456"}


def _start_api(tmp_path: Path, **env: str) -> subprocess.CompletedProcess[str]:
    """Imports the app in a fresh process, as uvicorn does at startup."""
    return subprocess.run(
        [sys.executable, "-c", "import prepvruksha_api.main"],
        cwd=tmp_path,  # no .env here
        env={**os.environ, **env},
        capture_output=True,
        text=True,
        check=False,
        timeout=60,
    )


def test_api_refuses_to_start_in_prod_with_test_parent_numbers(tmp_path: Path) -> None:
    result = _start_api(
        tmp_path, APP_ENV="prod", PARENT_OTP_TEST_CODES='{"919999900006": "123456"}'
    )
    assert result.returncode != 0
    assert "RuntimeError" in result.stderr


def test_api_starts_in_dev_with_test_parent_numbers(tmp_path: Path) -> None:
    result = _start_api(tmp_path, APP_ENV="dev", PARENT_OTP_TEST_CODES='{"919999900006": "123456"}')
    assert result.returncode == 0, result.stderr


def _env_file(tmp_path: Path) -> Path:
    env_file = tmp_path / ".env"
    env_file.write_text('PARENT_OTP_TEST_CODES={"919999900006": "123456"}\n')
    return env_file


def test_environment_replaces_test_codes_from_env_file(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setenv("PARENT_OTP_TEST_CODES", '{"919999900007": "654321"}')
    settings = ConsentSettings(_env_file=_env_file(tmp_path))  # type: ignore[call-arg]
    assert settings.parent_otp_test_codes == {"919999900007": "654321"}


def test_empty_environment_value_clears_test_codes_from_env_file(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setenv("PARENT_OTP_TEST_CODES", "{}")
    settings = ConsentSettings(_env_file=_env_file(tmp_path))  # type: ignore[call-arg]
    assert settings.parent_otp_test_codes == {}


def test_env_file_test_codes_apply_without_an_environment_value(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.delenv("PARENT_OTP_TEST_CODES", raising=False)
    settings = ConsentSettings(_env_file=_env_file(tmp_path))  # type: ignore[call-arg]
    assert settings.parent_otp_test_codes == {"919999900006": "123456"}
