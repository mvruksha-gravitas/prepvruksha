from pathlib import Path

import pytest

from prepvruksha_pipeline.evaluate import (
    evaluate,
    load_sheet,
    markdown,
    review_html,
    summary_json,
    write_template,
)
from prepvruksha_pipeline.parse import AnswerKeyEntry, ParsedOption
from tests.helpers import LABELS, page_result, question

SHEET = """\
file,number,format,answer,has_formula,formula_ok,stem_start,notes
EXAMPLE,12,single_mcq,B,y,,A body of mass 2 kg,delete me
a.pdf,1,single_mcq,A,y,y,A body of mass,
a.pdf,2,single_mcq,B,n,,,
a.pdf,3,assertion_reason,,n,,,no answer printed
a.pdf,4,match_following,C,y,n,,
b.docx,1,single_mcq,D,n,,,
"""


@pytest.fixture
def sheet(tmp_path: Path) -> Path:
    path = tmp_path / "answer-sheet.csv"
    path.write_text(SHEET, encoding="utf-8")
    return path


def results() -> list:  # type: ignore[type-arg]
    three_options = [ParsedOption(label=label, content=label) for label in LABELS[:3]]
    return [
        page_result(
            "a.pdf",
            1,
            [
                question("1", answer="A"),
                question("2", answer=None),  # answer comes from the key on page 2
                question("3", format="assertion_reason", answer="A"),  # invented!
            ],
        ),
        page_result(
            "a.pdf",
            2,
            [question("4", format="single_mcq", options=three_options, flags=["broken_math"])],
            key=[AnswerKeyEntry(number="2", answer="B")],
            kind="pdf_image",
            cost=0.02,
        ),
        page_result("a.pdf", 3, [question("99")]),  # not in the sheet
        page_result("b.docx", 1, [], kind="docx", error="refused"),
    ]


def test_accuracy_counts(sheet: Path) -> None:
    e = evaluate(results(), load_sheet(sheet))
    o = e.overall
    assert (o.expected, o.found, o.missed, o.extra) == (5, 4, 1, 1)
    assert o.format_ok == 3  # #4 parsed as single_mcq, sheet says match_following
    # b.docx #1 was missed, so its answer is not compared.
    assert (o.answer_expected, o.answer_ok, o.answer_not_found) == (3, 2, 1)
    assert o.answer_invented == 1
    assert (o.options_expected, o.options_ok) == (4, 3)
    assert (o.stem_checked, o.stem_ok) == (1, 1)
    assert (o.formula_rows, o.formula_syntax_ok) == (2, 1)
    assert (o.formula_checked, o.formula_ok) == (2, 1)
    assert e.by_format["assertion_reason"].answer_invented == 1
    assert e.by_kind["pdf_image"].found == 1
    assert e.by_file["b.docx"].missed == 1


def test_cost_summary(sheet: Path) -> None:
    e = evaluate(results(), load_sheet(sheet))
    assert e.spend.pages == 4 and e.spend.errors == 1 and e.spend.questions == 5
    assert e.spend.cost_usd == pytest.approx(0.05)
    assert e.spend_by_kind["pdf_image"].cost_usd == pytest.approx(0.02)
    assert [r.page_key for r in e.errors] == ["b.docx#1:docx"]


def test_reports(sheet: Path, tmp_path: Path) -> None:
    e = evaluate(results(), load_sheet(sheet))
    run = {"model": "claude-opus-5", "effort": "high", "pdf_mode": "auto"}
    text = markdown(e, run)
    assert "**1**" in text  # answer invented is shown in bold
    assert "a.pdf #3: sheet none, parsed A" in text
    assert "b.docx#1:docx: refused" in text
    assert '"answer_invented": 1' in summary_json(e, run)
    page = review_html(results(), tmp_path)
    assert "katex" in page and "a.pdf" in page and "Error: refused" in page
    assert "&lt;" not in "".join(q.stem for q in [question()])  # stems are escaped in HTML


def test_sheet_problems_are_reported(tmp_path: Path) -> None:
    path = tmp_path / "bad.csv"
    path.write_text("file,number,format,answer\na.pdf,1,mcq,E\n", encoding="utf-8")
    with pytest.raises(ValueError, match="line 2"):
        load_sheet(path)


def test_template_loads_as_empty(tmp_path: Path) -> None:
    path = tmp_path / "answer-sheet.csv"
    write_template(path)
    assert load_sheet(path) == []
