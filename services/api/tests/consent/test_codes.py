from prepvruksha_api.consent.codes import generate_code, hash_code, mask_phone


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
