from fastapi.testclient import TestClient

from tests.conftest import USER, FakeRpc, FakeSender


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
