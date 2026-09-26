"""Page results as JSON lines, so a run can resume and reports need no API calls."""

import json
from dataclasses import asdict
from pathlib import Path
from typing import Any

from prepvruksha_pipeline.parse.claude_parser import PageResult
from prepvruksha_pipeline.parse.pricing import TokenUsage
from prepvruksha_pipeline.parse.schema import PageParse


def to_dict(result: PageResult) -> dict[str, Any]:
    data = asdict(result)
    data["parse"] = result.parse.model_dump() if result.parse else None
    return data


def from_dict(data: dict[str, Any]) -> PageResult:
    return PageResult(
        page_key=data["page_key"],
        source_file=data["source_file"],
        page_number=data["page_number"],
        kind=data["kind"],
        model=data["model"],
        effort=data["effort"],
        parse=PageParse.model_validate(data["parse"]) if data["parse"] else None,
        usage=TokenUsage(**data["usage"]),
        cost_usd=data["cost_usd"],
        seconds=data["seconds"],
        error=data.get("error"),
    )


def append(path: Path, result: PageResult) -> None:
    with path.open("a", encoding="utf-8") as file:
        file.write(json.dumps(to_dict(result), ensure_ascii=False) + "\n")


def load(path: Path) -> list[PageResult]:
    """The latest successful result per page (failed pages are retried on resume)."""
    if not path.exists():
        return []
    latest: dict[str, PageResult] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.strip():
            result = from_dict(json.loads(line))
            if result.error is None or result.page_key not in latest:
                latest[result.page_key] = result
    return sorted(latest.values(), key=lambda r: (r.source_file, r.page_number))
