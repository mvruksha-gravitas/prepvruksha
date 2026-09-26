"""Answer keys printed apart from the questions, matched by question number.

The key's answers were read from the source, not worked out. A number that
appears twice in a document (e.g. two sections both numbered from 1) is
ambiguous and left for the reviewer.
"""

import re
from collections import Counter
from dataclasses import dataclass
from typing import Literal

from prepvruksha_pipeline.parse.schema import AnswerKeyEntry, OptionLabel, ParsedQuestion

AnswerOrigin = Literal["with_question", "answer_key", "missing"]


def normalize_number(number: str | None) -> str | None:
    if number is None:
        return None
    digits = re.sub(r"\D", "", number)
    if not digits:
        return None
    return digits.lstrip("0") or "0"


@dataclass
class KeyedQuestion:
    question: ParsedQuestion
    answer: OptionLabel | None
    origin: AnswerOrigin


def apply_answer_key(
    questions: list[ParsedQuestion], key: list[AnswerKeyEntry]
) -> list[KeyedQuestion]:
    numbers = Counter(normalize_number(q.number) for q in questions)
    key_answers: dict[str, OptionLabel] = {}
    key_counts = Counter(normalize_number(e.number) for e in key)
    for entry in key:
        number = normalize_number(entry.number)
        if number is not None and key_counts[number] == 1:
            key_answers[number] = entry.answer

    result: list[KeyedQuestion] = []
    for question in questions:
        if question.answer is not None:
            result.append(KeyedQuestion(question, question.answer, "with_question"))
            continue
        number = normalize_number(question.number)
        if number is not None and numbers[number] == 1 and number in key_answers:
            flags = [f for f in question.flags if f != "answer_missing"]
            result.append(
                KeyedQuestion(
                    question.model_copy(update={"flags": flags}),
                    key_answers[number],
                    "answer_key",
                )
            )
        else:
            result.append(KeyedQuestion(question, None, "missing"))
    return result
