# services/pipeline

Import worker: documents to review-ready questions. Today it is the **slice 0
prototype**: a command-line tool that parses a local folder of sample files with
the Claude API and measures accuracy against a hand-checked answer sheet. No
database, no UI. The `extract` and `parse` features are what the slice 2 worker
will reuse.

## Layout

| Folder | What |
|---|---|
| `shared/` | Settings, page types |
| `extract/` | Word (Pandoc via `pypandoc-binary`, TeX math) and PDF (PyMuPDF text layer and/or page image; scanned pages go as images) |
| `parse/` | The fixed JSON format (`schema.py`), prompt, the Claude call, deterministic checks, answer-key matching, prices, results file |
| `evaluate/` | Answer sheet, accuracy metrics, report and `review.html` |
| `cli.py` | `run`, `report`, `sheet-template` |

## Rules the prototype keeps

- The correct answer is only copied from the source (next to the question, or an
  answer-key table matched by question number). The model is told never to solve
  or guess; the report's **Answer invented** column must be 0 (CLAUDE.md rule 1).
- Only document content goes to the API: the file name, its text and page images.
  No uploader or personal details (rule 3).
- Samples and run output stay outside the repository (`C:\prepvruksha-samples`,
  runs in its `_runs` folder). The API key lives only in `services/pipeline/.env`.

## Running the prototype

```
cd services/pipeline
cp .env.example .env            # then set ANTHROPIC_API_KEY (key with a monthly spend limit)
uv sync

# 1. Answer sheet to fill in by hand (one row per question in the samples)
uv run prepvruksha-pipeline sheet-template C:/prepvruksha-samples/answer-sheet.csv

# 2. Parse (costs money; stops starting new pages after --max-usd, default 5)
uv run prepvruksha-pipeline run --samples C:/prepvruksha-samples --limit 3   # try 3 pages first
uv run prepvruksha-pipeline run --samples C:/prepvruksha-samples             # everything
uv run prepvruksha-pipeline run --samples C:/prepvruksha-samples --pdf-mode image   # PDFs as page images

# 3. Report (no API calls): report.md, summary.json, review.html in the run folder
uv run prepvruksha-pipeline report --run "C:/prepvruksha-samples/_runs/<run>" --sheet C:/prepvruksha-samples/answer-sheet.csv
```

`run` saves each page's result as it goes. Running it again with the same
`--out` folder resumes and retries failed pages without paying for finished
ones. Model and effort are settings (`PARSE_MODEL`, default `claude-opus-5`;
`PARSE_EFFORT`, default `high`); `--model` / `--effort` override them for one run.
`--pages "file.pdf#2"` parses only the listed pages. Other options: `--workers`,
`--limit`, `--max-usd`.

Figures: embedded images on a PDF page, and images in Word files, are cut out,
numbered in reading order ("Figure 1", …) and sent to the model, which lists the
figures each question uses (`figure_numbers`). They are saved in the run's
`assets/` folder (`<file>-p<page>-fig<n>.png`) and shown under their question in
`review.html`. A question that needs a figure that was not found keeps the
`figure_needed` flag.

PDF modes: `auto` (text layer; the page image too when the page has figures, or
only the page image when it has no text, i.e. a scan),
`text`, `image` (every page as an image: how well Claude reads scans), `both`.

### The answer sheet

| Column | Fill in |
|---|---|
| `file` | file name as in the samples folder |
| `number` | question number as printed |
| `format` | `single_mcq`, `assertion_reason`, `match_following`, `multi_statement`, `numerical`, `other` |
| `answer` | correct option A-D **as printed in the source**; empty if the source gives none |
| `has_formula` | `y` if the question or options contain maths/chemistry notation |
| `formula_ok` | after looking at `review.html`: `y`/`n`; empty until checked, then re-run `report` |
| `stem_start` | optional: first few words, to catch mismatched pairs |
| `notes` | anything |

### The report

Per format, per source kind (`pdf_text`, `pdf_image`, `pdf_both`, `docx`) and
per file: questions found / missed / extra, format right, four options present,
answer right / wrong / not found / **invented**, stem start matches, formula
syntax (balanced `$` and braces) and formula OK (your manual check), low
confidence; then cost per page, per question and time per page. `review.html`
shows each PDF page beside the parsed questions with formulas rendered (KaTeX).

## Checks

```
uv run ruff check . && uv run ruff format --check . && uv run mypy && uv run lint-imports && uv run pytest
```
