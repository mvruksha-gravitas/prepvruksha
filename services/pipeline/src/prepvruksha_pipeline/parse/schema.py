"""The fixed JSON format the parser returns for each page or chunk.

It maps onto `import_items.parsed` and, after review, `questions` +
`question_options`. The correct answer is only ever copied from the source,
never worked out (CLAUDE.md rule 1).
"""

from typing import Literal

from pydantic import BaseModel, Field

QuestionFormat = Literal[
    "single_mcq",
    "assertion_reason",
    "match_following",
    "multi_statement",
    "numerical",
    "other",
]
OptionLabel = Literal["A", "B", "C", "D"]
Flag = Literal[
    "answer_missing",
    "broken_math",
    "figure_needed",
    "incomplete",
    "unclear_text",
    "not_four_options",
]


class ParsedOption(BaseModel):
    label: OptionLabel = Field(description="A-D in printed order, whatever the source used")
    content: str = Field(description="Option text; math as LaTeX in $...$")


class ParsedQuestion(BaseModel):
    number: str | None = Field(description="Question number exactly as printed, e.g. '12'")
    format: QuestionFormat
    stem: str = Field(description="Question text (Markdown); math/chemistry as LaTeX in $...$")
    options: list[ParsedOption]
    answer: OptionLabel | None = Field(
        description="Only if the correct option is printed with this question; never solved"
    )
    explanation: str | None = Field(description="Only if a solution is printed with it")
    has_figure: bool
    figure_description: str | None
    subject_hint: str | None
    chapter_hint: str | None
    confidence: float = Field(description="0-1: confidence the transcription is exact")
    flags: list[Flag]


class AnswerKeyEntry(BaseModel):
    number: str = Field(description="Question number as printed in the answer key")
    answer: OptionLabel


class PageParse(BaseModel):
    questions: list[ParsedQuestion]
    answer_key: list[AnswerKeyEntry] = Field(
        description="Answer-key table entries printed on this page, if any"
    )
    notes: str | None = Field(description="Anything a reviewer should know about this page")
