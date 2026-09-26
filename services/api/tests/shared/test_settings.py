import pytest

from prepvruksha_api.shared import Settings


def test_prod_refuses_development_otp_settings() -> None:
    with pytest.raises(RuntimeError):
        Settings(app_env="prod").check_production_safety()
    Settings(
        app_env="dev", parent_otp_test_codes={"919999900006": "123456"}
    ).check_production_safety()
