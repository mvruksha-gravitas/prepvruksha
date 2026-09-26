"""Slice 0 prototype: parse a local folder of sample files and measure accuracy.

    uv run prepvruksha-pipeline sheet-template C:/prepvruksha-samples/answer-sheet.csv
    uv run prepvruksha-pipeline run --samples C:/prepvruksha-samples [--pdf-mode auto]
    uv run prepvruksha-pipeline report --run <run folder> --sheet <answer-sheet.csv>

`run` calls the Claude API (needs ANTHROPIC_API_KEY in services/pipeline/.env)
and stops starting new pages once --max-usd is spent. Results are saved as it
goes; running it again on the same folder resumes and retries failed pages.
`report` makes no API calls. Nothing here touches a database.
"""

import argparse
import json
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime
from pathlib import Path
from typing import get_args

from prepvruksha_pipeline.evaluate import (
    evaluate,
    load_sheet,
    markdown,
    page_image_name,
    review_html,
    summary_json,
    write_template,
)
from prepvruksha_pipeline.extract import (
    extract_docx,
    extract_pdf,
    is_supported,
    render_pdf_page,
)
from prepvruksha_pipeline.parse import (
    Effort,
    PageParser,
    PageResult,
    append_result,
    default_messages_client,
    load_results,
)
from prepvruksha_pipeline.shared import Page, Settings, figure_asset_name

RESULTS = "results.jsonl"
RUN_INFO = "run.json"


def _extract_all(samples: Path, pdf_mode: str, out: Path) -> tuple[list[Page], list[str]]:
    pages: list[Page] = []
    warnings: list[str] = []
    (out / "pages").mkdir(parents=True, exist_ok=True)
    files = sorted(p for p in samples.iterdir() if p.is_file() and is_supported(p))
    for path in files:
        if path.suffix.lower() == ".pdf":
            pdf_pages = extract_pdf(path, mode=pdf_mode)  # type: ignore[arg-type]
            for page in pdf_pages:
                image = out / "pages" / page_image_name(path.name, page.number)
                if not image.exists():
                    image.write_bytes(render_pdf_page(path, page.number))
            pages += pdf_pages
        else:
            docx = extract_docx(path)
            pages += docx.pages
            warnings += [f"skipped image (unsupported format): {s}" for s in docx.skipped_images]
    # Figures are saved as assets; questions link to them by figure number.
    (out / "assets").mkdir(exist_ok=True)
    for page in pages:
        for figure in page.figures:
            asset = out / "assets" / figure_asset_name(page.source_file, page.number, figure.number)
            asset.write_bytes(figure.image.data)
    return pages, warnings


def cmd_run(args: argparse.Namespace) -> int:
    settings = Settings()
    if settings.anthropic_api_key is None:
        print("ANTHROPIC_API_KEY is not set (services/pipeline/.env).", file=sys.stderr)
        return 2
    # Model and effort come from settings (PARSE_MODEL / PARSE_EFFORT); the flags
    # override them for one run.
    model = args.model or settings.parse_model
    effort = args.effort or settings.parse_effort
    samples = Path(args.samples)
    out = (
        Path(args.out)
        if args.out
        else samples / "_runs" / (f"{datetime.now():%Y%m%d-%H%M}-{args.pdf_mode}-{model}-{effort}")
    )
    out.mkdir(parents=True, exist_ok=True)
    info = {
        "model": model,
        "effort": effort,
        "pdf_mode": args.pdf_mode,
        "samples": str(samples),
    }
    (out / RUN_INFO).write_text(json.dumps(info, indent=2), encoding="utf-8")

    pages, warnings = _extract_all(samples, args.pdf_mode, out)
    for warning in warnings:
        print(f"warning: {warning}")
    done = {r.page_key for r in load_results(out / RESULTS) if r.error is None}
    if args.pages:
        wanted = set(args.pages)
        pages = [p for p in pages if f"{p.source_file}#{p.number}" in wanted]
    todo = [p for p in pages if p.key not in done][: args.limit or None]
    print(f"{len(pages)} pages/chunks, {len(done)} already done, {len(todo)} to parse -> {out}")

    parser = PageParser(
        default_messages_client(settings.anthropic_api_key.get_secret_value()),
        model,
        effort,
    )
    spent = 0.0
    stopped = False
    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        pending = iter(todo)
        futures = {}
        for page in pending:
            futures[pool.submit(parser.parse_page, page)] = page
            if len(futures) >= args.workers:
                break
        while futures:
            future = next(as_completed(futures))
            futures.pop(future)
            result: PageResult = future.result()
            append_result(out / RESULTS, result)
            spent += result.cost_usd or 0.0
            status = (
                result.error or f"{len(result.parse.questions) if result.parse else 0} questions"
            )
            print(f"{result.page_key}: {status} (${result.cost_usd or 0:.4f}, total ${spent:.2f})")
            if spent >= args.max_usd:
                stopped = True
            if not stopped:
                following = next(pending, None)
                if following is not None:
                    futures[pool.submit(parser.parse_page, following)] = following
    if stopped:
        print(f"Stopped at ${spent:.2f} (--max-usd {args.max_usd}). Run again to continue.")
    print(f'Next: uv run prepvruksha-pipeline report --run "{out}" --sheet <answer-sheet.csv>')
    return 0


def cmd_report(args: argparse.Namespace) -> int:
    out = Path(args.run)
    results = load_results(out / RESULTS)
    if not results:
        print(f"No results in {out / RESULTS}", file=sys.stderr)
        return 2
    run = json.loads((out / RUN_INFO).read_text(encoding="utf-8"))
    rows = load_sheet(Path(args.sheet)) if args.sheet else []
    evaluation = evaluate(results, rows)
    (out / "report.md").write_text(markdown(evaluation, run), encoding="utf-8")
    (out / "summary.json").write_text(summary_json(evaluation, run), encoding="utf-8")
    (out / "review.html").write_text(review_html(results, out), encoding="utf-8")
    if not rows:
        print("No answer sheet given: accuracy columns are empty; cost and review.html are ready.")
    print(f"Wrote {out / 'report.md'}, summary.json and review.html")
    return 0


def cmd_sheet_template(args: argparse.Namespace) -> int:
    path = Path(args.path)
    if path.exists():
        print(f"{path} already exists; not overwriting.", file=sys.stderr)
        return 2
    write_template(path)
    print(f"Wrote {path}")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        prog="prepvruksha-pipeline",
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    commands = parser.add_subparsers(dest="command", required=True)

    run = commands.add_parser("run", help="parse the sample files with the Claude API")
    run.add_argument("--samples", required=True, help="folder with .pdf / .docx files")
    run.add_argument("--out", help="run folder (default: <samples>/_runs/<time-mode-model>)")
    run.add_argument(
        "--pdf-mode",
        choices=["auto", "text", "image", "both"],
        default="auto",
        help="auto: text layer, or the page image for scanned pages",
    )
    run.add_argument("--model", help="default: PARSE_MODEL or claude-opus-5")
    run.add_argument("--effort", choices=get_args(Effort), help="default: PARSE_EFFORT or high")
    run.add_argument("--workers", type=int, default=4)
    run.add_argument("--limit", type=int, default=0, help="parse at most N pages (0: all)")
    run.add_argument(
        "--pages", nargs="+", metavar="FILE#N", help='only these pages, e.g. "Set B.pdf#2"'
    )
    run.add_argument(
        "--max-usd",
        type=float,
        default=5.0,
        help="stop starting new pages after this much is spent",
    )
    run.set_defaults(func=cmd_run)

    report = commands.add_parser("report", help="accuracy and cost report (no API calls)")
    report.add_argument("--run", required=True, help="run folder written by `run`")
    report.add_argument("--sheet", help="hand-checked answer sheet (CSV)")
    report.set_defaults(func=cmd_report)

    template = commands.add_parser("sheet-template", help="write an empty answer sheet")
    template.add_argument("path")
    template.set_defaults(func=cmd_sheet_template)

    args = parser.parse_args(argv)
    code: int = args.func(args)
    return code


if __name__ == "__main__":
    raise SystemExit(main())
