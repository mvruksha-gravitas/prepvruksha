"""Builders for parsed questions and page results used across the tests."""

from typing import Any

from prepvruksha_pipeline.parse import (
    AnswerKeyEntry,
    OptionLabel,
    PageParse,
    PageResult,
    ParsedOption,
    ParsedQuestion,
    TokenUsage,
)

LABELS: tuple[OptionLabel, ...] = ("A", "B", "C", "D")


def question(number: str | None = "1", **overrides: Any) -> ParsedQuestion:
    data: dict[str, Any] = {
        "number": number,
        "format": "single_mcq",
        "stem": "A body of mass $2\\,\\mathrm{kg}$ moves with speed $v$.",
        "options": [ParsedOption(label=label, content=f"option {label}") for label in LABELS],
        "answer": None,
        "explanation": None,
        "has_figure": False,
        "figure_numbers": [],
        "figure_description": None,
        "subject_hint": "Physics",
        "chapter_hint": None,
        "confidence": 0.95,
        "flags": [],
    }
    data.update(overrides)
    return ParsedQuestion(**data)


def page_result(
    file: str,
    page: int,
    questions: list[ParsedQuestion],
    key: list[AnswerKeyEntry] | None = None,
    kind: str = "pdf_text",
    cost: float | None = 0.01,
    error: str | None = None,
) -> PageResult:
    return PageResult(
        page_key=f"{file}#{page}:{kind}",
        source_file=file,
        page_number=page,
        kind=kind,
        model="claude-opus-5",
        effort="high",
        parse=None if error else PageParse(questions=questions, answer_key=key or [], notes=None),
        usage=TokenUsage(input_tokens=1000, output_tokens=500),
        cost_usd=cost,
        seconds=2.0,
        error=error,
    )
