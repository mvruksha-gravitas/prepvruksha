"""Deterministic checks on parsed questions; they add flags, never change content."""

import re

from prepvruksha_pipeline.parse.schema import Flag, ParsedQuestion

OPTION_FORMATS = ("single_mcq", "assertion_reason", "match_following", "multi_statement")
_UNESCAPED_DOLLAR = re.compile(r"(?<!\\)\$")


def math_is_balanced(text: str) -> bool:
    """Even number of unescaped $ and balanced braces inside math segments."""
    if len(_UNESCAPED_DOLLAR.findall(text)) % 2:
        return False
    for segment in _UNESCAPED_DOLLAR.split(text)[1::2]:
        depth = 0
        for char in segment.replace("\\{", "").replace("\\}", ""):
            depth += {"{": 1, "}": -1}.get(char, 0)
            if depth < 0:
                return False
        if depth:
            return False
    return True


def check_question(question: ParsedQuestion, figure_count: int = 0) -> ParsedQuestion:
    """figure_count: figures provided with the page; linked figures must exist."""
    flags: list[Flag] = list(question.flags)

    def add(flag: Flag) -> None:
        if flag not in flags:
            flags.append(flag)

    if question.format in OPTION_FORMATS:
        labels = [o.label for o in question.options]
        if sorted(labels) != ["A", "B", "C", "D"]:
            add("not_four_options")
    if question.answer is None:
        add("answer_missing")
    elif question.answer not in {o.label for o in question.options}:
        add("not_four_options")
    linked = [n for n in question.figure_numbers if 1 <= n <= figure_count]
    if len(linked) != len(question.figure_numbers):
        add("figure_needed")  # a figure number that was not provided
    elif linked and "figure_needed" in flags:
        flags.remove("figure_needed")  # the figure is on file, linked to the question
    texts = [question.stem, *(o.content for o in question.options)]
    if not all(math_is_balanced(t) for t in texts):
        add("broken_math")
    return question.model_copy(update={"flags": flags})
