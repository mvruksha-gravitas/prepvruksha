"""FastAPI application entry point.

Run locally: `uv run uvicorn prepvruksha_api.main:app --reload`
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from prepvruksha_api import consent, profile
from prepvruksha_api.shared import get_settings

consent.check_production_safety(get_settings().app_env)

app = FastAPI(title="PrepVruksha API", version="0.1.0")
app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=get_settings().cors_origin_regex,
    allow_methods=["GET", "POST", "PUT"],
    allow_headers=["Authorization", "Content-Type"],
)
app.include_router(profile.router)
app.include_router(consent.router)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "env": get_settings().app_env}
