"""Reads the syllabus tree from `docs/syllabus/<subject>.md` (format in docs/syllabus/README.md).

    # Botany                                      subject (heading 1)
    ## [ ] The Living World (`the-living-world`, XI Ch 1)   chapter: slug from the seed
    - **Diversity in the living world**           topic
      - Characteristics of living organisms       sub-topic
      - Old idea (removed)                        removed from the syllabus
      - New wording {old-wording}                 renamed: keeps the slug old-wording

`[x]` instead of `[ ]` marks a chapter the subject expert approved: its
sub-topics load with `expert_reviewed = true`. A " — Check: …" note is for
the reviewer and is dropped. A topic with no sub-topics gets one sub-topic
with the topic's own name, so every question can be tagged.
"""

import re
from dataclasses import dataclass, field

SUBJECT_CODES = {"Physics": "PHY", "Chemistry": "CHE", "Botany": "BOT", "Zoology": "ZOO"}

_CHAPTER = re.compile(r"^## \[( |x)\] (?P<name>.+?) \(`(?P<slug>[a-z0-9-]+)`, .+\)\s*$")
_TOPIC = re.compile(r"^- (?P<text>.+?)\s*$")
_SUB_TOPIC = re.compile(r"^  - (?P<text>.+?)\s*$")
_CHECK = re.compile(r"\s+—\s+Check:.*$")
_REMOVED = re.compile(r"\s*\(removed\)\s*$", re.IGNORECASE)
_SLUG = re.compile(r"\s*\{(?P<slug>[a-z0-9]+(?:-[a-z0-9]+)*)\}\s*$")


class SyllabusFormatError(ValueError):
    """A line that does not fit the format; the message names the line."""


@dataclass
class SubTopic:
    name: str
    slug: str
    is_removed: bool


@dataclass
class Topic:
    name: str
    slug: str
    is_removed: bool
    sub_topics: list[SubTopic] = field(default_factory=list)


@dataclass
class Chapter:
    subject_code: str
    slug: str
    name: str
    expert_reviewed: bool
    topics: list[Topic] = field(default_factory=list)


def slugify(name: str) -> str:
    """Lower-case words joined by hyphens, as the database requires."""
    slug = re.sub(r"[^a-z0-9]+", "-", name.lower().replace("'", "")).strip("-")
    if not slug:
        raise SyllabusFormatError(f"no slug can be made from {name!r}")
    return slug[:80].rstrip("-")


def _unique(slug: str, taken: set[str]) -> str:
    candidate, n = slug, 2
    while candidate in taken:
        candidate, n = f"{slug}-{n}", n + 1
    taken.add(candidate)
    return candidate


def _clean(text: str) -> tuple[str, bool, str | None]:
    """Name without markup or notes, whether it is marked removed, and a pinned slug."""
    text = _CHECK.sub("", text).replace("**", "").replace("`", "").strip()
    pinned = _SLUG.search(text)
    text = _SLUG.sub("", text).strip()
    removed = bool(_REMOVED.search(text))
    return _REMOVED.sub("", text).strip(), removed, pinned["slug"] if pinned else None


def parse(markdown: str) -> list[Chapter]:
    chapters: list[Chapter] = []
    subject: str | None = None
    chapter: Chapter | None = None
    topic_slugs: set[str] = set()
    sub_slugs: set[str] = set()

    for number, line in enumerate(markdown.splitlines(), start=1):
        where = f"line {number}: {line.strip()!r}"
        if line.startswith("# "):
            name = line[2:].strip()
            subject = SUBJECT_CODES.get(name)
            chapter = None
            if subject is None and chapters:
                raise SyllabusFormatError(f"{where}: unknown subject")
        elif line.startswith("## "):
            match = _CHAPTER.match(line)
            if match is None:
                raise SyllabusFormatError(f"{where}: expected '## [ ] Name (`slug`, ref)'")
            if subject is None:
                raise SyllabusFormatError(f"{where}: chapter outside a subject heading")
            chapter = Chapter(subject, match["slug"], match["name"], line[4] == "x")
            chapters.append(chapter)
            topic_slugs = set()
        elif (match := _SUB_TOPIC.match(line)) is not None:
            if chapter is None or not chapter.topics:
                raise SyllabusFormatError(f"{where}: sub-topic before any topic")
            topic = chapter.topics[-1]
            name, removed, pinned = _clean(match["text"])
            slug = _unique(pinned or slugify(name), sub_slugs)
            topic.sub_topics.append(SubTopic(name, slug, removed or topic.is_removed))
        elif (match := _TOPIC.match(line)) is not None:
            if chapter is None:
                continue  # bullet lists outside chapters (e.g. notes) are not part of the tree
            name, removed, pinned = _clean(match["text"])
            chapter.topics.append(
                Topic(name, _unique(pinned or slugify(name), topic_slugs), removed)
            )
            sub_slugs = set()
        elif line.startswith("   ") and line.strip().startswith("-"):
            raise SyllabusFormatError(f"{where}: only two levels below a chapter")

    for ch in chapters:
        for topic in ch.topics:
            if not topic.sub_topics:
                topic.sub_topics.append(SubTopic(topic.name, topic.slug, topic.is_removed))
    return chapters
