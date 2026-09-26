"""FastAPI application entry point.

Run locally: `uv run uvicorn prepvruksha_api.main:app --reload`
"""

from fastapi import FastAPI

from prepvruksha_api.settings import get_settings

app = FastAPI(title="PrepVruksha API", version="0.1.0")


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "env": get_settings().app_env}
