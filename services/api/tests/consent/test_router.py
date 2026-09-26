from collections.abc import Iterator
from typing import Any

import pytest
from fastapi.testclient import TestClient

from prepvruksha_api.auth import current_user_id
from prepvruksha_api.main import app
from prepvruksha_api.otp import ParentCodeIssuer
from prepvruksha_api.otp import get_code_issuer as get_issuer
from prepvruksha_api.supabase_rpc import RuleViolationError, get_rpc

USER = "aaaaaaaa-1111-1111-1111-111111111111"
STATE = {
    "status": "needs_parental",
    "is_minor": True,
    "terms_version": "2026-10-draft",
    "parental_version": "2026-10-draft",
    "pending_request": {
        "id": "r1",
        "parent_name": "Sunita",
        "parent_phone": "919876500002",
        "expires_at": "2026-10-01T10:10:00+00:00",
        "attempts_left": 5,
        "resend_available_at": "2026-10-01T10:01:00+00:00",
    },
}


class FakeRpc:
    def __init__(self) -> None:
        self.calls: list[tuple[str, dict[str, Any]]] = []
        self.results: dict[str, Any] = {"get_signup_state": STATE}
        self.errors: dict[str, str] = {}

    def call(self, function: str, params: dict[str, Any]) -> Any:
        self.calls.append((function, params))
        if function in self.errors:
            raise RuleViolationError(self.errors[function])
        return self.results.get(function)

    def params(self, function: str) -> dict[str, Any]:
        return next(p for f, p in self.calls if f == function)


class FakeSender:
    def __init__(self) -> None:
        self.sent: list[tuple[str, str]] = []

    def send_parent_consent_code(self, phone: str, code: str) -> None:
        self.sent.append((phone, code))


@pytest.fixture
def rpc() -> FakeRpc:
    return FakeRpc()


@pytest.fixture
def sender() -> FakeSender:
    return FakeSender()


@pytest.fixture
def client(rpc: FakeRpc, sender: FakeSender) -> Iterator[TestClient]:
    issuer = ParentCodeIssuer(b"test-key", sender, {"919999900006": "123456"})
    app.dependency_overrides[current_user_id] = lambda: USER
    app.dependency_overrides[get_rpc] = lambda: rpc
    app.dependency_overrides[get_issuer] = lambda: issuer
    yield TestClient(app)
    app.dependency_overrides.clear()


def test_requires_a_token() -> None:
    response = TestClient(app).get("/me/signup")
    assert response.status_code == 401
    assert response.json()["detail"]["code"] == "not_signed_in"


def test_state_hides_all_but_the_last_four_digits_of_the_parent_number(client: TestClient) -> None:
    body = client.get("/me/signup").json()
    assert body["status"] == "needs_parental"
    assert body["pending_request"]["parent_phone_last4"] == "0002"
    assert "919876500002" not in str(body)


def test_profile_is_passed_to_the_database(client: TestClient, rpc: FakeRpc) -> None:
    response = client.put(
        "/me/profile",
        json={"full_name": "Asha", "date_of_birth": "2010-05-15", "target_exam_year": 2027},
    )
    assert response.status_code == 200
    assert rpc.params("complete_profile") == {
        "p_user_id": USER,
        "p_full_name": "Asha",
        "p_date_of_birth": "2010-05-15",
        "p_target_exam_year": 2027,
        "p_category": None,
        "p_preferred_language": None,
    }


@pytest.mark.parametrize(
    ("code", "http_status"),
    [
        ("dob_already_set", 409),
        ("age_out_of_range", 422),
        ("resend_too_soon", 429),
        ("parent_phone_daily_limit_reached", 429),
        ("profile_not_found", 404),
        ("something_new", 500),
    ],
)
def test_rule_violations_become_http_errors(
    client: TestClient, rpc: FakeRpc, code: str, http_status: int
) -> None:
    rpc.errors["complete_profile"] = code
    response = client.put(
        "/me/profile",
        json={"full_name": "Asha", "date_of_birth": "2010-05-15", "target_exam_year": 2027},
    )
    assert response.status_code == http_status
    assert response.json()["detail"] == {"code": code}


def test_parent_code_is_hashed_normalised_and_sent(
    client: TestClient, rpc: FakeRpc, sender: FakeSender
) -> None:
    response = client.post(
        "/me/consents/parental", json={"parent_name": "Sunita", "parent_phone": "+91 98765 00002"}
    )
    assert response.status_code == 200
    params = rpc.params("start_parental_consent")
    assert params["p_parent_phone"] == "919876500002"
    [(phone, code)] = sender.sent
    assert phone == "919876500002"
    assert params["p_code_hash"] != code
    assert code not in str(rpc.calls)


def test_test_parent_numbers_get_the_fixed_code_and_no_sms(
    client: TestClient, rpc: FakeRpc, sender: FakeSender
) -> None:
    client.post("/me/consents/parental", json={"parent_name": "Test", "parent_phone": "9999900006"})
    assert sender.sent == []
    rpc.results["verify_parental_consent"] = {"result": "verified"}
    client.post("/me/consents/parental/verify", json={"code": "123456"})
    assert (
        rpc.params("verify_parental_consent")["p_code_hash"]
        == rpc.params("start_parental_consent")["p_code_hash"]
    )


def test_invalid_parent_number_is_rejected_before_the_database(
    client: TestClient, rpc: FakeRpc
) -> None:
    response = client.post(
        "/me/consents/parental", json={"parent_name": "Sunita", "parent_phone": "12345 67890"}
    )
    assert response.status_code == 422
    assert response.json()["detail"] == {"code": "parent_phone_invalid"}
    assert rpc.calls == []


def test_failed_sms_is_reported(client: TestClient, sender: FakeSender) -> None:
    def fail(phone: str, code: str) -> None:
        raise ConnectionError("provider down")

    sender.send_parent_consent_code = fail  # type: ignore[method-assign]
    response = client.post(
        "/me/consents/parental", json={"parent_name": "Sunita", "parent_phone": "9876500002"}
    )
    assert response.status_code == 502
    assert response.json()["detail"] == {"code": "code_not_sent"}


def test_wrong_code_reports_attempts_left(client: TestClient, rpc: FakeRpc) -> None:
    rpc.results["verify_parental_consent"] = {"result": "invalid", "attempts_left": 3}
    body = client.post("/me/consents/parental/verify", json={"code": "000000"}).json()
    assert body["result"] == "invalid"
    assert body["attempts_left"] == 3
    assert body["state"]["status"] == "needs_parental"


def test_code_must_be_six_digits(client: TestClient, rpc: FakeRpc) -> None:
    assert client.post("/me/consents/parental/verify", json={"code": "12ab56"}).status_code == 422
    assert rpc.calls == []


def test_withdraw(client: TestClient, rpc: FakeRpc) -> None:
    assert client.post("/me/consents/parental/withdraw").status_code == 200
    assert rpc.params("withdraw_consent") == {"p_user_id": USER, "p_type": "parental"}
    assert client.post("/me/consents/marketing/withdraw").status_code == 422
