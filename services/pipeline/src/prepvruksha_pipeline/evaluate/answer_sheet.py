"""The hand-checked answer sheet: one row per question in the sample files.

Columns:
  file         file name as in the samples folder
  number       question number as printed
  format       single_mcq | assertion_reason | match_following | multi_statement |
               numerical | other
  answer       correct option A-D as printed in the source (answer next to the
               question or in an answer key); empty if the source gives none
  has_formula  y if the question or its options contain maths/chemistry notation
  formula_ok   after looking at review.html: y if the formulas were transcribed
               correctly, n if not; empty until checked
  stem_start   optional: the first few words of the question, to catch mismatches
  notes        free text
Rows whose file is EXAMPLE are ignored.
"""

import csv
from dataclasses import dataclass
from pathlib import Path

COLUMNS = [
    "file",
    "number",
    "format",
    "answer",
    "has_formula",
    "formula_ok",
    "stem_start",
    "notes",
]
FORMATS = (
    "single_mcq",
    "assertion_reason",
    "match_following",
    "multi_statement",
    "numerical",
    "other",
)


@dataclass(frozen=True)
class SheetRow:
    file: str
    number: str
    format: str
    answer: str | None
    has_formula: bool
    formula_ok: bool | None
    stem_start: str
    notes: str


def _yes_no(value: str) -> bool | None:
    value = value.strip().lower()
    if value in ("y", "yes", "1", "true"):
        return True
    if value in ("n", "no", "0", "false"):
        return False
    return None


def write_template(path: Path) -> None:
    with path.open("w", newline="", encoding="utf-8") as file:
        writer = csv.writer(file)
        writer.writerow(COLUMNS)
        writer.writerow(
            ["EXAMPLE", "12", "single_mcq", "B", "y", "", "A body of mass 2 kg", "delete me"]
        )


def load_sheet(path: Path) -> list[SheetRow]:
    rows: list[SheetRow] = []
    problems: list[str] = []
    with path.open(newline="", encoding="utf-8-sig") as file:
        for line, raw in enumerate(csv.DictReader(file), start=2):
            record = {k.strip().lower(): (v or "").strip() for k, v in raw.items() if k}
            if not record.get("file") or record["file"] == "EXAMPLE":
                continue
            fmt = record.get("format", "").lower()
            answer = record.get("answer", "").upper() or None
            if fmt not in FORMATS:
                problems.append(f"line {line}: format '{fmt}' is not one of {', '.join(FORMATS)}")
            if answer is not None and answer not in ("A", "B", "C", "D"):
                problems.append(f"line {line}: answer '{answer}' must be A-D or empty")
            rows.append(
                SheetRow(
                    file=record["file"],
                    number=record.get("number", ""),
                    format=fmt,
                    answer=answer,
                    has_formula=_yes_no(record.get("has_formula", "")) is True,
                    formula_ok=_yes_no(record.get("formula_ok", "")),
                    stem_start=record.get("stem_start", ""),
                    notes=record.get("notes", ""),
                )
            )
    if problems:
        raise ValueError("Answer sheet problems:\n" + "\n".join(problems))
    return rows
