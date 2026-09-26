"""Calls Postgres functions through Supabase's Data API (PostgREST) with the secret key.

The secret key bypasses RLS, so every function called here takes the
verified user id and does its own checks.
"""

from functools import lru_cache
from typing import Any, Protocol

import httpx

from prepvruksha_api.shared.settings import get_settings


class RuleViolationError(Exception):
    """A business rule raised by a Postgres function (SQLSTATE P0001), e.g. 'dob_already_set'."""

    def __init__(self, code: str) -> None:
        super().__init__(code)
        self.code = code


class Rpc(Protocol):
    def call(self, function: str, params: dict[str, Any]) -> Any: ...


class SupabaseRpc:
    def __init__(self, supabase_url: str, secret_key: str) -> None:
        self._client = httpx.Client(
            base_url=f"{supabase_url}/rest/v1",
            headers={"apikey": secret_key},
            timeout=10.0,
        )

    def call(self, function: str, params: dict[str, Any]) -> Any:
        response = self._client.post(f"/rpc/{function}", json=params)
        if response.is_success:
            return response.json()
        try:
            body = response.json()
        except ValueError:
            body = {}
        if isinstance(body, dict) and body.get("code") == "P0001":
            raise RuleViolationError(str(body.get("message")))
        response.raise_for_status()
        raise RuntimeError(f"unexpected response {response.status_code}")


@lru_cache
def get_rpc() -> Rpc:
    settings = get_settings()
    if settings.supabase_secret_key is None:
        raise RuntimeError("SUPABASE_SECRET_KEY is not set")
    return SupabaseRpc(settings.supabase_url, settings.supabase_secret_key.get_secret_value())
