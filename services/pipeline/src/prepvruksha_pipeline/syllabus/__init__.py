"""Syllabus feature: docs/syllabus/*.md → a seed file that loads the tree. Public entry."""

from prepvruksha_pipeline.syllabus.sql import seed_sql
from prepvruksha_pipeline.syllabus.tree import (
    SUBJECT_CODES,
    Chapter,
    SubTopic,
    SyllabusFormatError,
    Topic,
    parse,
    slugify,
)

__all__ = [
    "SUBJECT_CODES",
    "Chapter",
    "SubTopic",
    "SyllabusFormatError",
    "Topic",
    "parse",
    "seed_sql",
    "slugify",
]
