from pathlib import Path
from types import SimpleNamespace
from typing import Any

import pytest

from prepvruksha_pipeline.parse import (
    AnswerKeyEntry,
    PageParse,
    PageParser,
    TokenUsage,
    append_result,
    apply_answer_key,
    cost_usd,
    load_results,
    math_is_balanced,
    normalize_number,
)
from prepvruksha_pipeline.parse.validate import check_question
from prepvruksha_pipeline.shared import Page, PageImage
from tests.helpers import page_result, question


# --- deterministic checks -------------------------------------------------------------
@pytest.mark.parametrize(
    ("text", "ok"),
    [
        ("plain text", True),
        ("$v = u + at$ and $$E = mc^2$$", True),
        ("price \\$5 and $x^{2}$", True),
        ("$x^{2$", False),
        ("$x$ and $y", False),
        ("$\\{a\\}$", True),
    ],
)
def test_math_balance(text: str, ok: bool) -> None:
    assert math_is_balanced(text) is ok


def test_checks_add_flags_but_never_change_content() -> None:
    q = question(options=[], stem="Find $x^{2$", answer=None)
    checked = check_question(q)
    assert set(checked.flags) == {"not_four_options", "answer_missing", "broken_math"}
    assert checked.stem == q.stem and checked.answer is None


def test_a_clean_question_gets_no_flags() -> None:
    assert check_question(question(answer="B")).flags == []


# --- answer keys ----------------------------------------------------------------------
def test_answer_key_fills_only_missing_answers_by_number() -> None:
    questions = [question("Q.1", answer="A"), question("2"), question("03"), question("4")]
    key = [AnswerKeyEntry(number="1", answer="D"), AnswerKeyEntry(number="3", answer="C")]
    keyed = apply_answer_key(questions, key)
    assert [(k.answer, k.origin) for k in keyed] == [
        ("A", "with_question"),
        (None, "missing"),
        ("C", "answer_key"),
        (None, "missing"),
    ]
    assert "answer_missing" not in keyed[2].question.flags


def test_repeated_numbers_are_left_for_the_reviewer() -> None:
    questions = [question("1"), question("1")]
    keyed = apply_answer_key(questions, [AnswerKeyEntry(number="1", answer="B")])
    assert [k.answer for k in keyed] == [None, None]


def test_normalize_number() -> None:
    assert normalize_number("Q. 012") == "12"
    assert normalize_number("0") == "0"
    assert normalize_number("(iv)") is None
    assert normalize_number(None) is None


# --- pricing --------------------------------------------------------------------------
def test_cost() -> None:
    usage = TokenUsage(input_tokens=1_000_000, output_tokens=100_000)
    assert cost_usd("claude-opus-5", usage) == pytest.approx(5.0 + 2.5)
    assert cost_usd("claude-sonnet-5", usage) == pytest.approx(2.0 + 1.0)
    assert cost_usd("unknown-model", usage) is None


# --- the Claude call (fake client) ----------------------------------------------------
class FakeMessages:
    def __init__(self, stop_reason: str = "end_turn", parsed: Any = None) -> None:
        self.calls: list[dict[str, Any]] = []
        self.stop_reason = stop_reason
        self.parsed = parsed

    def parse(self, **kwargs: Any) -> Any:
        self.calls.append(kwargs)
        return SimpleNamespace(
            stop_reason=self.stop_reason,
            parsed_output=self.parsed,
            usage=SimpleNamespace(
                input_tokens=2000,
                output_tokens=800,
                cache_creation_input_tokens=0,
                cache_read_input_tokens=0,
            ),
        )


PAGE = Page(
    source_file="physics.pdf",
    number=3,
    kind="pdf_both",
    text="1. A body of mass 2 kg ...",
    images=(PageImage("image/png", b"\x89PNG fake"),),
)


def test_parser_sends_page_content_and_checks_the_result() -> None:
    parsed = PageParse(questions=[question(answer=None)], answer_key=[], notes=None)
    messages = FakeMessages(parsed=parsed)
    result = PageParser(messages, "claude-opus-5", effort="medium").parse_page(PAGE)

    [call] = messages.calls
    assert call["model"] == "claude-opus-5"
    assert call["output_format"] is PageParse
    assert call["output_config"] == {"effort": "medium"}
    content = call["messages"][0]["content"]
    assert content[0]["type"] == "image" and content[0]["source"]["media_type"] == "image/png"
    assert "physics.pdf, page 3" in content[-1]["text"]
    assert "A body of mass 2 kg" in content[-1]["text"]

    assert result.error is None and result.parse is not None
    assert "answer_missing" in result.parse.questions[0].flags
    assert result.usage == TokenUsage(input_tokens=2000, output_tokens=800)
    assert result.cost_usd == pytest.approx((2000 * 5 + 800 * 25) / 1_000_000)
    assert result.page_key == "physics.pdf#3:pdf_both"


@pytest.mark.parametrize(
    ("stop_reason", "error"), [("refusal", "refused"), ("max_tokens", "output cut off")]
)
def test_parser_reports_unusable_responses(stop_reason: str, error: str) -> None:
    result = PageParser(FakeMessages(stop_reason=stop_reason), "claude-opus-5").parse_page(PAGE)
    assert result.parse is None and result.error is not None and error in result.error
    assert result.usage.input_tokens == 2000  # still billed, still counted


# --- the results file -----------------------------------------------------------------
def test_results_round_trip_and_resume_keeps_the_last_success(tmp_path: Path) -> None:
    path = tmp_path / "results.jsonl"
    ok = page_result("a.pdf", 1, [question(answer="C")])
    append_result(path, page_result("a.pdf", 1, [], error="API error 529: overloaded"))
    append_result(path, ok)
    append_result(path, page_result("a.pdf", 1, [], error="later failure"))
    [loaded] = load_results(path)
    assert loaded.error is None and loaded.parse == ok.parse and loaded.usage == ok.usage
