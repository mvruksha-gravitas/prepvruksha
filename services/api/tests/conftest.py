"""Fakes and fixtures shared by the feature tests."""

from collections.abc import Iterator
from typing import Any

import pytest
from fastapi.testclient import TestClient

from prepvruksha_api.auth import current_user_id
from prepvruksha_api.consent import ParentCodeIssuer, get_code_issuer
from prepvruksha_api.main import app
from prepvruksha_api.shared import RuleViolationError, get_rpc

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
    app.dependency_overrides[get_code_issuer] = lambda: issuer
    yield TestClient(app)
    app.dependency_overrides.clear()
