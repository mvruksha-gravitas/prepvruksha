import json
from pathlib import Path

import pytest

from prepvruksha_pipeline.cli import main
from prepvruksha_pipeline.parse import append_result
from tests.helpers import page_result, question


def test_sheet_template_does_not_overwrite(tmp_path: Path) -> None:
    path = tmp_path / "answer-sheet.csv"
    assert main(["sheet-template", str(path)]) == 0
    assert path.read_text(encoding="utf-8").startswith("file,number,format")
    assert main(["sheet-template", str(path)]) == 2


def test_run_needs_an_api_key(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.chdir(tmp_path)  # no .env here
    monkeypatch.delenv("ANTHROPIC_API_KEY", raising=False)
    assert main(["run", "--samples", str(tmp_path)]) == 2


def test_report_without_api_calls(tmp_path: Path) -> None:
    (tmp_path / "run.json").write_text(
        json.dumps({"model": "claude-opus-5", "effort": "high", "pdf_mode": "auto"}),
        encoding="utf-8",
    )
    append_result(tmp_path / "results.jsonl", page_result("a.pdf", 1, [question(answer="A")]))
    assert main(["report", "--run", str(tmp_path)]) == 0
    assert "Cost per page" in (tmp_path / "report.md").read_text(encoding="utf-8")
    assert (tmp_path / "review.html").exists() and (tmp_path / "summary.json").exists()
