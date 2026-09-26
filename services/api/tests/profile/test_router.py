import pytest
from fastapi.testclient import TestClient

from prepvruksha_api.main import app
from tests.conftest import USER, FakeRpc


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
