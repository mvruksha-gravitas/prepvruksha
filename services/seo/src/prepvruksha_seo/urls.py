"""URL helpers for public question pages: `/neet/{subject}/{chapter}/{slug}-{short_id}`.

Slugs never change once a question is published.
"""

import re
import unicodedata


def slugify(text: str, max_length: int = 80) -> str:
    """Lowercase ASCII slug with hyphens, cut at a word boundary."""
    ascii_text = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode()
    slug = re.sub(r"[^a-z0-9]+", "-", ascii_text.lower()).strip("-")
    if len(slug) <= max_length:
        return slug
    cut = slug[:max_length]
    return cut.rsplit("-", 1)[0] if "-" in cut else cut


def question_path(exam: str, subject_slug: str, chapter_slug: str, slug: str, short_id: str) -> str:
    return f"/{exam}/{subject_slug}/{chapter_slug}/{slug}-{short_id}"
