from prepvruksha_seo.urls import question_path, slugify


def test_slugify_keeps_ascii_words() -> None:
    assert slugify("What is the SI unit of Force?") == "what-is-the-si-unit-of-force"


def test_slugify_cuts_at_word_boundary() -> None:
    assert slugify("alpha beta gamma", max_length=12) == "alpha-beta"


def test_question_path() -> None:
    assert (
        question_path("neet", "physics", "laws-of-motion", "si-unit-of-force", "k3x9q2")
        == "/neet/physics/laws-of-motion/si-unit-of-force-k3x9q2"
    )
