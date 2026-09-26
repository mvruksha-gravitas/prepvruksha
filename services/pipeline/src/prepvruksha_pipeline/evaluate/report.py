"""Write the accuracy report (Markdown + JSON) and review.html for checking formulas."""

import html
import json
from collections.abc import Mapping
from dataclasses import asdict
from pathlib import Path

from prepvruksha_pipeline.evaluate.metrics import Counts, Evaluation, Item, Spend, collect_items
from prepvruksha_pipeline.parse import PageResult
from prepvruksha_pipeline.shared import figure_asset_name


def _pct(part: int, whole: int) -> str:
    return f"{100 * part / whole:.0f}% ({part}/{whole})" if whole else "-"


def _counts_row(name: str, c: Counts) -> str:
    return (
        f"| {name} | {c.expected} | {_pct(c.found, c.expected)} | {c.extra} "
        f"| {_pct(c.format_ok, c.found)} | {_pct(c.options_ok, c.options_expected)} "
        f"| {_pct(c.answer_ok, c.answer_expected)} | {c.answer_wrong} | {c.answer_not_found} "
        f"| **{c.answer_invented}** | {_pct(c.stem_ok, c.stem_checked)} "
        f"| {_pct(c.formula_syntax_ok, c.formula_rows)} | {_pct(c.formula_ok, c.formula_checked)} "
        f"| {c.low_confidence} |"
    )


_COUNTS_HEADER = (
    "| | Expected | Found | Extra | Format right | 4 options | Answer right | Answer wrong "
    "| Answer not found | **Answer invented** | Stem matches | Formula syntax OK "
    "| Formula OK (manual) | Low confidence |\n"
    "|---|---|---|---|---|---|---|---|---|---|---|---|---|---|"
)


def _money(spend: Spend) -> str:
    return f"${spend.cost_usd:.4f}" if spend.priced else "unknown (model not in price list)"


def _spend_row(name: str, s: Spend) -> str:
    per_page = f"${s.cost_usd / s.pages:.4f}" if s.pages and s.priced else "-"
    per_question = f"${s.cost_usd / s.questions:.4f}" if s.questions and s.priced else "-"
    return (
        f"| {name} | {s.pages} | {s.errors} | {s.questions} | {s.usage.input_tokens:,} "
        f"| {s.usage.output_tokens:,} | {_money(s)} | {per_page} | {per_question} "
        f"| {s.seconds / s.pages if s.pages else 0:.1f} s |"
    )


_SPEND_HEADER = (
    "| | Pages/chunks | Errors | Questions | Input tokens | Output tokens | Cost "
    "| Cost per page | Cost per question | Time per page |\n"
    "|---|---|---|---|---|---|---|---|---|---|"
)


def markdown(evaluation: Evaluation, run: Mapping[str, object]) -> str:
    e = evaluation
    lines = [
        "# Import prototype: accuracy report",
        "",
        f"Model `{run.get('model')}`, effort `{run.get('effort')}`, "
        f"PDF mode `{run.get('pdf_mode')}`.",
        "",
        "Answers are only copied from the source; **Answer invented** (an answer returned "
        "where the source prints none) must be 0.",
        "Formula OK (manual) comes from the `formula_ok` column after checking review.html.",
        "By source kind counts only questions that were found.",
        "",
        "## Overall",
        "",
        _COUNTS_HEADER,
        _counts_row("All", e.overall),
        "",
        "## By question format",
        "",
        _COUNTS_HEADER,
        *(_counts_row(k, v) for k, v in sorted(e.by_format.items())),
        "",
        "## By source kind",
        "",
        _COUNTS_HEADER,
        *(_counts_row(k, v) for k, v in sorted(e.by_kind.items())),
        "",
        "## By file",
        "",
        _COUNTS_HEADER,
        *(_counts_row(k, v) for k, v in sorted(e.by_file.items())),
        "",
        "## Cost",
        "",
        _SPEND_HEADER,
        _spend_row("All", e.spend),
        *(_spend_row(k, v) for k, v in sorted(e.spend_by_kind.items())),
        "",
        _SPEND_HEADER,
        *(_spend_row(k, v) for k, v in sorted(e.spend_by_file.items())),
        "",
    ]
    missed = [p.row for p in e.pairs if p.item is None and p.row is not None]
    extra = [p.item for p in e.pairs if p.row is None and p.item is not None]
    wrong = [p for p in e.pairs if p.row and p.item and p.row.answer != p.item.keyed.answer]
    lines += ["## Details", ""]
    lines += ["### Missed (in the sheet, not parsed)", ""]
    lines += [f"- {r.file} #{r.number} ({r.format})" for r in missed] or ["None."]
    lines += ["", "### Extra (parsed, not in the sheet)", ""]
    lines += [
        f"- {i.file} p{i.page} #{i.keyed.question.number}: {i.keyed.question.stem[:80]!r}"
        for i in extra
    ] or ["None."]
    lines += ["", "### Answer differs from the sheet", ""]
    lines += [
        f"- {p.row.file} #{p.row.number}: sheet {p.row.answer or 'none'}, "  # type: ignore[union-attr]
        f"parsed {p.item.keyed.answer or 'none'} ({p.item.keyed.origin})"  # type: ignore[union-attr]
        for p in wrong
    ] or ["None."]
    lines += ["", "### Pages with errors", ""]
    lines += [f"- {r.page_key}: {r.error}" for r in e.errors] or ["None."]
    return "\n".join(lines) + "\n"


def summary_json(evaluation: Evaluation, run: Mapping[str, object]) -> str:
    e = evaluation
    return json.dumps(
        {
            "run": dict(run),
            "overall": asdict(e.overall),
            "by_format": {k: asdict(v) for k, v in e.by_format.items()},
            "by_kind": {k: asdict(v) for k, v in e.by_kind.items()},
            "by_file": {k: asdict(v) for k, v in e.by_file.items()},
            "spend": asdict(e.spend),
            "spend_by_kind": {k: asdict(v) for k, v in e.spend_by_kind.items()},
            "errors": [{"page": r.page_key, "error": r.error} for r in e.errors],
        },
        indent=2,
        ensure_ascii=False,
    )


def page_image_name(file: str, page: int) -> str:
    safe = "".join(c if c.isalnum() else "_" for c in file)
    return f"{safe}-p{page}.png"


_HTML_HEAD = """<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Import review</title>
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/katex.min.css">
<script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/katex.min.js"></script>
<script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/contrib/auto-render.min.js"
  onload="renderMathInElement(document.body, {delimiters: [
    {left: '$$', right: '$$', display: true}, {left: '$', right: '$', display: false},
    {left: '\\\\(', right: '\\\\)', display: false}]})"></script>
<style>
body { font: 15px/1.5 system-ui, sans-serif; margin: 16px; color: #1b1b1b; background: #fff; }
.page { display: grid; grid-template-columns: minmax(0, 1fr) minmax(0, 1fr); gap: 16px;
  border-top: 2px solid #ccc; padding: 12px 0; }
.page img { width: 100%; border: 1px solid #ddd; }
.q img.figure { max-width: 100%; width: auto; margin-top: 6px; }
.q { border: 1px solid #ddd; border-radius: 6px; padding: 8px 10px; margin-bottom: 10px; }
.stem { white-space: pre-wrap; }
.meta { color: #555; font-size: 13px; }
.flag { background: #fde2e1; color: #8a1c14; border-radius: 4px;
  padding: 0 4px; margin-right: 4px; }
@media (max-width: 800px) { .page { grid-template-columns: 1fr; } }
</style></head><body>
<h1>Import review</h1>
<p>Parsed questions beside the source page. Check the formulas, then fill the
<code>formula_ok</code> column in the answer sheet.</p>
"""


def _question_html(item: Item) -> str:
    q = item.keyed.question
    options = "".join(f"<li><b>{o.label}</b> {html.escape(o.content)}</li>" for o in q.options)
    flags = "".join(f'<span class="flag">{html.escape(f)}</span>' for f in q.flags)
    answer = item.keyed.answer or "none"
    return (
        f'<div class="q"><div class="meta">#{html.escape(q.number or "?")} · {q.format} · '
        f"answer {answer} ({item.keyed.origin}) · confidence {q.confidence:.2f} {flags}</div>"
        f'<div class="stem">{html.escape(q.stem)}</div><ol type="A">{options}</ol>'
        + (
            f'<div class="meta">Figure: {html.escape(q.figure_description)}</div>'
            if q.figure_description
            else ""
        )
        + "".join(
            f'<img class="figure" src="assets/{figure_asset_name(item.file, item.page, n)}" '
            f'alt="Figure {n} linked to question {html.escape(q.number or "?")}">'
            for n in q.figure_numbers
        )
        + "</div>"
    )


def review_html(results: list[PageResult], out_dir: Path) -> str:
    items = collect_items(results)
    parts = [_HTML_HEAD]
    for result in results:
        page_items = [
            i for i in items if i.file == result.source_file and i.page == result.page_number
        ]
        image = out_dir / "pages" / page_image_name(result.source_file, result.page_number)
        left = (
            f'<img src="pages/{image.name}" alt="Source page {result.page_number}">'
            if image.exists()
            else '<p class="meta">No page image (Word chunk).</p>'
        )
        body = "".join(_question_html(i) for i in page_items) or '<p class="meta">No questions.</p>'
        if result.error:
            body = f'<p class="flag">Error: {html.escape(result.error)}</p>'
        parts.append(
            f"<h2>{html.escape(result.source_file)} — "
            f"{'section' if result.kind == 'docx' else 'page'} {result.page_number} "
            f'<span class="meta">({result.kind})</span></h2>'
            f'<div class="page"><div>{left}</div><div>{body}</div></div>'
        )
    parts.append("</body></html>\n")
    return "".join(parts)
