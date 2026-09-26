"""Indian mobile numbers."""

import re

_MOBILE = re.compile(r"[6-9]\d{9}")


def normalize_indian_mobile(raw: str) -> str | None:
    """Return '91' + 10 digits (the format of profiles.phone), or None if invalid.

    Accepts '+91 98765 43210', '098765-43210', '9876543210' and similar.
    """
    digits = re.sub(r"[\s\-()]", "", raw)
    if digits.startswith("+"):
        digits = digits[1:]
    if not digits.isdigit():
        return None
    if len(digits) == 12 and digits.startswith("91"):
        digits = digits[2:]
    elif len(digits) == 11 and digits.startswith("0"):
        digits = digits[1:]
    if not _MOBILE.fullmatch(digits):
        return None
    return "91" + digits
