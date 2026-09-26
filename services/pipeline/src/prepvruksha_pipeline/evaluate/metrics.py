"""Accuracy of a parse run against the hand-checked answer sheet, and its cost.

Parsed questions are paired with sheet rows by file and question number (in
order, when a number repeats). The most important number is `answer_invented`:
an answer returned where the source prints none. It must stay at zero.
"""

import difflib
import re
from collections import defaultdict
from dataclasses import dataclass, field

from prepvruksha_pipeline.evaluate.answer_sheet import SheetRow
from prepvruksha_pipeline.parse import (
    OPTION_FORMATS,
    KeyedQuestion,
    PageResult,
    TokenUsage,
    apply_answer_key,
    normalize_number,
)

LOW_CONFIDENCE = 0.8
STEM_MATCH = 0.8


@dataclass
class Item:
    """One parsed question, with its answer after applying the document's answer key."""

    file: str
    page: int
    kind: str
    keyed: KeyedQuestion


@dataclass
class Pair:
    row: SheetRow | None
    item: Item | None


def collect_items(results: list[PageResult]) -> list[Item]:
    items: list[Item] = []
    by_file: dict[str, list[PageResult]] = defaultdict(list)
    for result in results:
        if result.parse is not None:
            by_file[result.source_file].append(result)
    for file, pages in by_file.items():
        pages.sort(key=lambda r: r.page_number)
        origins = [(p.page_number, p.kind) for p in pages for _ in p.parse.questions]  # type: ignore[union-attr]
        questions = [q for p in pages for q in p.parse.questions]  # type: ignore[union-attr]
        key = [e for p in pages for e in p.parse.answer_key]  # type: ignore[union-attr]
        for (page, kind), keyed in zip(origins, apply_answer_key(questions, key), strict=True):
            items.append(Item(file, page, kind, keyed))
    return items


def pair_up(items: list[Item], rows: list[SheetRow]) -> list[Pair]:
    item_groups: dict[tuple[str, str | None], list[Item]] = defaultdict(list)
    for item in items:
        item_groups[(item.file, normalize_number(item.keyed.question.number))].append(item)
    pairs: list[Pair] = []
    for row in rows:
        group = item_groups.get((row.file, normalize_number(row.number)))
        pairs.append(Pair(row, group.pop(0) if group else None))
    pairs.extend(Pair(None, item) for group in item_groups.values() for item in group)
    return pairs


def _plain(text: str) -> str:
    return re.sub(r"[^a-z0-9 ]", "", re.sub(r"\s+", " ", text.lower())).strip()


def stem_matches(expected_start: str, stem: str) -> bool:
    expected = _plain(expected_start)
    actual = _plain(stem)[: len(expected)]
    return difflib.SequenceMatcher(None, expected, actual).ratio() >= STEM_MATCH


@dataclass
class Counts:
    expected: int = 0
    found: int = 0
    missed: int = 0
    extra: int = 0
    format_ok: int = 0
    options_expected: int = 0
    options_ok: int = 0
    answer_expected: int = 0
    answer_ok: int = 0
    answer_wrong: int = 0
    answer_not_found: int = 0
    no_answer_expected: int = 0
    answer_invented: int = 0
    stem_checked: int = 0
    stem_ok: int = 0
    formula_rows: int = 0
    formula_syntax_ok: int = 0
    formula_checked: int = 0
    formula_ok: int = 0
    low_confidence: int = 0

    def add(self, pair: Pair) -> None:
        row, item = pair.row, pair.item
        if row is None:
            self.extra += 1
            return
        self.expected += 1
        if item is None:
            self.missed += 1
            return
        self.found += 1
        question = item.keyed.question
        self.format_ok += question.format == row.format
        if question.confidence < LOW_CONFIDENCE:
            self.low_confidence += 1
        if row.format in OPTION_FORMATS:
            self.options_expected += 1
            self.options_ok += sorted(o.label for o in question.options) == ["A", "B", "C", "D"]
        if row.answer is None:
            self.no_answer_expected += 1
            self.answer_invented += item.keyed.answer is not None
        else:
            self.answer_expected += 1
            if item.keyed.answer is None:
                self.answer_not_found += 1
            elif item.keyed.answer == row.answer:
                self.answer_ok += 1
            else:
                self.answer_wrong += 1
        if row.stem_start:
            self.stem_checked += 1
            self.stem_ok += stem_matches(row.stem_start, question.stem)
        if row.has_formula:
            self.formula_rows += 1
            self.formula_syntax_ok += "broken_math" not in question.flags
            if row.formula_ok is not None:
                self.formula_checked += 1
                self.formula_ok += row.formula_ok


@dataclass
class Spend:
    pages: int = 0
    errors: int = 0
    questions: int = 0
    usage: TokenUsage = field(default_factory=TokenUsage)
    cost_usd: float = 0.0
    priced: bool = True
    seconds: float = 0.0

    def add(self, result: PageResult) -> None:
        self.pages += 1
        self.errors += result.error is not None
        self.questions += len(result.parse.questions) if result.parse else 0
        self.usage = self.usage + result.usage
        self.seconds += result.seconds
        if result.cost_usd is None:
            self.priced = False
        else:
            self.cost_usd += result.cost_usd


@dataclass
class Evaluation:
    overall: Counts
    by_format: dict[str, Counts]
    by_file: dict[str, Counts]
    by_kind: dict[str, Counts]
    spend: Spend
    spend_by_kind: dict[str, Spend]
    spend_by_file: dict[str, Spend]
    pairs: list[Pair]
    errors: list[PageResult]


def evaluate(results: list[PageResult], rows: list[SheetRow]) -> Evaluation:
    pairs = pair_up(collect_items(results), rows)
    overall = Counts()
    by_format: dict[str, Counts] = defaultdict(Counts)
    by_file: dict[str, Counts] = defaultdict(Counts)
    by_kind: dict[str, Counts] = defaultdict(Counts)
    for pair in pairs:
        overall.add(pair)
        file = pair.row.file if pair.row else pair.item.file  # type: ignore[union-attr]
        by_file[file].add(pair)
        if pair.row is not None:
            by_format[pair.row.format].add(pair)
        if pair.item is not None:
            by_kind[pair.item.kind].add(pair)
    spend = Spend()
    spend_by_kind: dict[str, Spend] = defaultdict(Spend)
    spend_by_file: dict[str, Spend] = defaultdict(Spend)
    for result in results:
        spend.add(result)
        spend_by_kind[result.kind].add(result)
        spend_by_file[result.source_file].add(result)
    return Evaluation(
        overall=overall,
        by_format=dict(by_format),
        by_file=dict(by_file),
        by_kind=dict(by_kind),
        spend=spend,
        spend_by_kind=dict(spend_by_kind),
        spend_by_file=dict(spend_by_file),
        pairs=pairs,
        errors=[r for r in results if r.error is not None],
    )
