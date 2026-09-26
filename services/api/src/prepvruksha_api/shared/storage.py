"""Supabase Storage with the secret key: signed upload URLs for private buckets.

Clients never get storage policies; they upload only through a short-lived
signed URL created here, after the API has checked the request.
"""

from functools import lru_cache
from typing import Annotated, Protocol

import httpx
from fastapi import Depends

from prepvruksha_api.shared.settings import get_settings


class Storage(Protocol):
    def create_signed_upload_url(self, bucket: str, path: str) -> str:
        """Full URL the browser PUTs the file to (valid for 2 hours, Supabase default)."""
        ...


class SupabaseStorage:
    def __init__(self, supabase_url: str, secret_key: str) -> None:
        self._base = f"{supabase_url}/storage/v1"
        self._client = httpx.Client(
            base_url=self._base,
            headers={"apikey": secret_key, "Authorization": f"Bearer {secret_key}"},
            timeout=10.0,
        )

    def create_signed_upload_url(self, bucket: str, path: str) -> str:
        # x-upsert: a retried upload (same file row) may replace a partial object.
        response = self._client.post(
            f"/object/upload/sign/{bucket}/{path}", headers={"x-upsert": "true"}
        )
        response.raise_for_status()
        return f"{self._base}{response.json()['url']}"


@lru_cache
def get_storage() -> Storage:
    settings = get_settings()
    if settings.supabase_secret_key is None:
        raise RuntimeError("SUPABASE_SECRET_KEY is not set")
    return SupabaseStorage(settings.supabase_url, settings.supabase_secret_key.get_secret_value())


StorageDep = Annotated[Storage, Depends(get_storage)]
