import pytest

from prepvruksha_api.shared import normalize_indian_mobile


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
