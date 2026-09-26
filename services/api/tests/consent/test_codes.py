import pytest

from prepvruksha_api.otp import generate_code, hash_code, mask_phone
from prepvruksha_api.phone import normalize_indian_mobile
from prepvruksha_api.settings import Settings


@pytest.mark.parametrize(
    ("raw", "expected"),
    [
        ("9876543210", "919876543210"),
        ("+91 98765 43210", "919876543210"),
        ("919876543210", "919876543210"),
        ("098765-43210", "919876543210"),
        ("(+91) 6123456789", "916123456789"),
        ("5876543210", None),
        ("987654321", None),
        ("+1 9876543210", None),
        ("98765abcde", None),
        ("", None),
    ],
)
def test_normalize_indian_mobile(raw: str, expected: str | None) -> None:
    assert normalize_indian_mobile(raw) == expected


def test_codes_are_six_digits() -> None:
    codes = {generate_code() for _ in range(200)}
    assert all(len(c) == 6 and c.isdigit() for c in codes)
    assert len(codes) > 150


def test_hash_is_keyed_and_bound_to_the_user() -> None:
    h = hash_code(b"k1", "user-1", "123456")
    assert h == hash_code(b"k1", "user-1", "123456")
    assert h != hash_code(b"k2", "user-1", "123456")
    assert h != hash_code(b"k1", "user-2", "123456")
    assert "123456" not in h


def test_mask_phone() -> None:
    assert mask_phone("919876543210") == "+91 ******3210"


def test_prod_refuses_development_otp_settings() -> None:
    with pytest.raises(RuntimeError):
        Settings(app_env="prod").check_production_safety()
    Settings(
        app_env="dev", parent_otp_test_codes={"919999900006": "123456"}
    ).check_production_safety()
