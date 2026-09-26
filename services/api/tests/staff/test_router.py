from fastapi.testclient import TestClient

from prepvruksha_api.main import app
from tests.conftest import USER, FakeRpc


def test_requires_a_token() -> None:
    response = TestClient(app).get("/staff/me")
    assert response.status_code == 401


def test_returns_the_roles(client: TestClient, rpc: FakeRpc) -> None:
    rpc.results["get_staff_roles"] = ["content_admin", "reviewer"]
    response = client.get("/staff/me")
    assert response.status_code == 200
    assert response.json() == {"user_id": USER, "roles": ["content_admin", "reviewer"]}
    assert rpc.params("get_staff_roles") == {"p_user_id": USER}


def test_non_staff_get_an_empty_list_not_an_error(client: TestClient, rpc: FakeRpc) -> None:
    rpc.results["get_staff_roles"] = []
    response = client.get("/staff/me")
    assert response.status_code == 200
    assert response.json()["roles"] == []
