from pathlib import Path

import pytest

from prepvruksha_pipeline.syllabus import SyllabusFormatError, parse, seed_sql, slugify

DOCS = Path(__file__).parents[4] / "docs" / "syllabus"

SAMPLE = """# NEET Biology (title, ignored)

Intro text.

- a bullet outside any chapter is ignored

# Botany

## [x] The Living World (`the-living-world`, XI Ch 1)

- **Diversity in the living world**
  - Characteristics of living organisms
  - Biodiversity — Check: keep?
  - Biodiversity
- **Taxonomical aids** — Check: removed in 2023?
  - Herbarium (removed)
- **Nomenclature**

# Zoology

## [ ] Animal Kingdom (`animal-kingdom`, XI Ch 4)

- **Basis of classification** (removed)
  - Symmetry
"""


def test_parses_subjects_chapters_topics_and_sub_topics() -> None:
    botany, zoology = parse(SAMPLE)
    assert (botany.subject_code, botany.slug, botany.expert_reviewed) == (
        "BOT",
        "the-living-world",
        True,
    )
    assert (zoology.subject_code, zoology.expert_reviewed) == ("ZOO", False)
    diversity, aids, _ = botany.topics
    assert diversity.slug == "diversity-in-the-living-world"
    assert [s.name for s in diversity.sub_topics] == [
        "Characteristics of living organisms",
        "Biodiversity",
        "Biodiversity",
    ]
    # Duplicate names within a topic get distinct slugs.
    assert [s.slug for s in diversity.sub_topics][1:] == ["biodiversity", "biodiversity-2"]
    # Reviewer notes are dropped from names.
    assert aids.name == "Taxonomical aids"
    assert aids.sub_topics[0].is_removed
    assert not aids.is_removed


def test_a_pinned_slug_survives_a_rename() -> None:
    (chapter,) = parse(
        "# Botany\n## [ ] X (`x`, ref)\n- **New topic name** {old-topic}\n"
        "  - Primary productivity (GPP, NPP) {primary-productivity}\n"
    )
    topic = chapter.topics[0]
    assert (topic.name, topic.slug) == ("New topic name", "old-topic")
    assert (topic.sub_topics[0].name, topic.sub_topics[0].slug) == (
        "Primary productivity (GPP, NPP)",
        "primary-productivity",
    )


def test_a_topic_without_sub_topics_gets_one_with_its_own_name() -> None:
    nomenclature = parse(SAMPLE)[0].topics[2]
    assert [(s.name, s.slug) for s in nomenclature.sub_topics] == [("Nomenclature", "nomenclature")]


def test_a_removed_topic_removes_its_sub_topics() -> None:
    basis = parse(SAMPLE)[1].topics[0]
    assert basis.is_removed
    assert basis.sub_topics[0].is_removed


@pytest.mark.parametrize(
    ("name", "slug"),
    [
        ("Newton's third law", "newtons-third-law"),
        ("Cell: The Unit of Life", "cell-the-unit-of-life"),
        ("C4 pathway and Kranz anatomy", "c4-pathway-and-kranz-anatomy"),
        ("Hardy–Weinberg principle", "hardy-weinberg-principle"),  # noqa: RUF001 (en dash on purpose)
    ],
)
def test_slugs(name: str, slug: str) -> None:
    assert slugify(name) == slug


@pytest.mark.parametrize(
    "bad",
    [
        "# Botany\n## The Living World\n",
        "# Botany\n## [ ] X (`x`, ref)\n  - sub-topic before a topic\n",
        "# Botany\n## [ ] X (`x`, ref)\n- T\n  - S\n    - too deep\n",
        "# Botany\n## [ ] X (`x`, ref)\n# Astronomy\n",
    ],
)
def test_format_errors_name_the_line(bad: str) -> None:
    with pytest.raises(SyllabusFormatError, match="line"):
        parse(bad)


def test_seed_checks_chapters_and_counts() -> None:
    sql = seed_sql(parse(SAMPLE), "docs/syllabus/sample.md")
    assert "('BOT', 'the-living-world')" in sql
    assert "chapters not in the database" in sql
    assert "expected at least 6 sub-topics" in sql
    # Quotes are escaped and the reviewer flag comes from the chapter.
    assert "'Characteristics of living organisms', false, true, 1)" in sql
    assert "on conflict (topic_id, slug) do update" in sql
    assert "expert_reviewed = excluded.expert_reviewed" in sql
    assert "in the database but not in the markdown" in sql


def test_the_biology_draft_parses() -> None:
    chapters = parse((DOCS / "biology.md").read_text(encoding="utf-8"))
    # 32 current chapters and 6 removed ones (one placeholder topic each).
    assert len(chapters) == 38
    removed = [ch for ch in chapters if ch.topics[0].name == "Whole chapter"]
    assert len(removed) == 6
    assert all(len(ch.topics) == 1 and len(ch.topics[0].sub_topics) == 1 for ch in removed)
    assert {ch.subject_code for ch in chapters} == {"BOT", "ZOO"}
    assert not any(ch.expert_reviewed for ch in chapters)
    for ch in chapters:
        assert ch.topics, ch.slug
        assert len({t.slug for t in ch.topics}) == len(ch.topics)
        for t in ch.topics:
            assert "Check" not in t.name
            assert len({s.slug for s in t.sub_topics}) == len(t.sub_topics)
