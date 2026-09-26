from typing import Any

import pytest
from fastapi.testclient import TestClient

from prepvruksha_api.main import app
from tests.conftest import USER, FakeRpc, FakeStorage

FILE_ID = "f0000000-0000-0000-0000-000000000001"
HASH = "ab" * 32
FILE: dict[str, Any] = {
    "id": FILE_ID,
    "original_name": "NEET 2023.pdf",
    "file_type": "pdf",
    "size_bytes": 2000,
    "sha256": HASH,
    "storage_path": f"uploads/{FILE_ID}.pdf",
    "rights_status": "official_pyq",
    "rights_note": "NTA question paper",
    "pyq_exam_code": "NEET_UG",
    "pyq_year": 2023,
    "status": "awaiting_upload",
    "error": None,
    "uploaded_by": USER,
    "created_at": "2026-09-30T10:00:00+00:00",
    "queued_at": None,
}
NEW_FILE = {
    "original_name": "NEET 2023.pdf",
    "file_type": "pdf",
    "size_bytes": 2000,
    "sha256": HASH.upper(),
    "rights_status": "official_pyq",
    "rights_note": "NTA question paper",
    "pyq_exam_code": "NEET_UG",
    "pyq_year": 2023,
}


@pytest.fixture
def admin(rpc: FakeRpc) -> FakeRpc:
    rpc.results["get_staff_roles"] = ["content_admin"]
    rpc.results["create_source_file"] = {"id": FILE_ID, "storage_path": FILE["storage_path"]}
    rpc.results["get_source_file"] = FILE
    rpc.results["list_source_files"] = [FILE]
    return rpc


def test_requires_a_token() -> None:
    assert TestClient(app).get("/content/files").status_code == 401


def test_non_staff_are_refused(client: TestClient, rpc: FakeRpc) -> None:
    rpc.results["get_staff_roles"] = []
    response = client.get("/content/files")
    assert response.status_code == 403
    assert response.json()["detail"] == {"code": "not_staff"}


def test_list_passes_the_actor_and_filters(client: TestClient, admin: FakeRpc) -> None:
    response = client.get("/content/files", params={"rights_status": "official_pyq"})
    assert response.status_code == 200
    assert response.json()[0]["pyq_exam_code"] == "NEET_UG"
    assert admin.params("list_source_files") == {
        "p_actor_id": USER,
        "p_status": None,
        "p_rights_status": "official_pyq",
    }


def test_list_filters_by_status(client: TestClient, admin: FakeRpc) -> None:
    assert client.get("/content/files", params={"status": "queued"}).status_code == 200
    assert admin.params("list_source_files")["p_status"] == "queued"
    assert client.get("/content/files", params={"status": "bogus"}).status_code == 422


def test_reviewers_can_list(client: TestClient, admin: FakeRpc) -> None:
    admin.results["get_staff_roles"] = ["reviewer"]
    assert client.get("/content/files").status_code == 200


def test_create_records_the_file_and_returns_a_signed_upload_url(
    client: TestClient, admin: FakeRpc, storage: FakeStorage
) -> None:
    response = client.post("/content/files", json=NEW_FILE)
    assert response.status_code == 201
    body = response.json()
    assert body["file"]["id"] == FILE_ID
    assert body["upload_url"].startswith("https://storage.test/upload/sign/source-files/")
    assert storage.signed == [("source-files", FILE["storage_path"])]
    assert admin.params("create_source_file") == {
        "p_actor_id": USER,
        "p_original_name": "NEET 2023.pdf",
        "p_file_type": "pdf",
        "p_size_bytes": 2000,
        "p_sha256": HASH,
        "p_rights_status": "official_pyq",
        "p_rights_note": "NTA question paper",
        "p_pyq_exam_code": "NEET_UG",
        "p_pyq_year": 2023,
    }


def test_reviewers_cannot_upload(client: TestClient, admin: FakeRpc, storage: FakeStorage) -> None:
    admin.results["get_staff_roles"] = ["reviewer"]
    response = client.post("/content/files", json=NEW_FILE)
    assert response.status_code == 403
    assert response.json()["detail"] == {"code": "not_authorised"}
    assert storage.signed == []
    assert not any(f == "create_source_file" for f, _ in admin.calls)


def test_super_admins_can_upload(client: TestClient, admin: FakeRpc) -> None:
    admin.results["get_staff_roles"] = ["super_admin"]
    assert client.post("/content/files", json=NEW_FILE).status_code == 201


@pytest.mark.parametrize(
    "change",
    [
        {"rights_status": None},
        {"rights_status": "public_domain"},
        {"rights_note": ""},
        {"pyq_year": None},
        {"rights_status": "owned_licensed"},
        {"file_type": "xlsx"},
        {"original_name": "paper.docx"},
        {"size_bytes": 100 * 1024 * 1024 + 1},
        {"sha256": "abc"},
    ],
)
def test_bad_requests_are_rejected_before_the_database(
    client: TestClient, admin: FakeRpc, storage: FakeStorage, change: dict[str, Any]
) -> None:
    response = client.post("/content/files", json={**NEW_FILE, **change})
    assert response.status_code == 422
    assert storage.signed == []
    assert not any(f == "create_source_file" for f, _ in admin.calls)


def test_rights_status_has_no_default(client: TestClient, admin: FakeRpc) -> None:
    body = {k: v for k, v in NEW_FILE.items() if k != "rights_status"}
    assert client.post("/content/files", json=body).status_code == 422


@pytest.mark.parametrize(
    ("code", "http_status"),
    [
        ("duplicate_file", 409),
        ("pyq_year_invalid", 422),
        ("not_authorised", 403),
        ("something_new", 500),
    ],
)
def test_rule_violations_become_http_errors(
    client: TestClient, admin: FakeRpc, storage: FakeStorage, code: str, http_status: int
) -> None:
    admin.errors["create_source_file"] = code
    response = client.post("/content/files", json=NEW_FILE)
    assert response.status_code == http_status
    assert response.json()["detail"] == {"code": code}
    assert storage.signed == []


def test_complete_queues_the_file(client: TestClient, admin: FakeRpc) -> None:
    admin.results["get_source_file"] = {**FILE, "status": "queued"}
    response = client.post(f"/content/files/{FILE_ID}/complete")
    assert response.status_code == 200
    assert response.json()["status"] == "queued"
    assert admin.params("complete_source_file_upload") == {
        "p_actor_id": USER,
        "p_file_id": FILE_ID,
    }


@pytest.mark.parametrize(
    "code", ["upload_missing", "upload_size_mismatch", "file_already_uploaded"]
)
def test_complete_reports_upload_problems(client: TestClient, admin: FakeRpc, code: str) -> None:
    admin.errors["complete_source_file_upload"] = code
    response = client.post(f"/content/files/{FILE_ID}/complete")
    assert response.status_code == 409
    assert response.json()["detail"] == {"code": code}


def test_hidden_files_are_not_found(client: TestClient, admin: FakeRpc) -> None:
    admin.errors["get_source_file"] = "file_not_found"
    admin.errors["complete_source_file_upload"] = "file_not_found"
    assert client.post(f"/content/files/{FILE_ID}/complete").status_code == 404


def test_change_rights_needs_a_reason(client: TestClient, admin: FakeRpc) -> None:
    body = {"rights_status": "reference_only", "rights_note": "Owner objected", "reason": ""}
    assert client.patch(f"/content/files/{FILE_ID}/rights", json=body).status_code == 422


def test_change_rights(client: TestClient, admin: FakeRpc) -> None:
    body = {
        "rights_status": "reference_only",
        "rights_note": "Owner objected",
        "reason": "Takedown",
    }
    response = client.patch(f"/content/files/{FILE_ID}/rights", json=body)
    assert response.status_code == 200
    assert admin.params("set_source_file_rights") == {
        "p_actor_id": USER,
        "p_file_id": FILE_ID,
        "p_rights_status": "reference_only",
        "p_rights_note": "Owner objected",
        "p_reason": "Takedown",
        "p_pyq_exam_code": None,
        "p_pyq_year": None,
    }


def test_reviewers_cannot_change_rights(client: TestClient, admin: FakeRpc) -> None:
    admin.results["get_staff_roles"] = ["reviewer"]
    body = {"rights_status": "reference_only", "rights_note": "x", "reason": "y"}
    assert client.patch(f"/content/files/{FILE_ID}/rights", json=body).status_code == 403
