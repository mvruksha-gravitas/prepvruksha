from pathlib import Path

import pymupdf
import pypandoc
import pytest

from prepvruksha_pipeline.extract import extract_docx, extract_pdf, is_supported, page_count
from prepvruksha_pipeline.extract.docx import _split_blocks

TEXT = "1. A body of mass 2 kg moves with a speed of 3 m/s. Its kinetic energy is (a) 9 J (b) 6 J"


@pytest.fixture
def pdf(tmp_path: Path) -> Path:
    """Page 1 has a text layer; page 2 is 'scanned' (a drawing, no text)."""
    path = tmp_path / "sample.pdf"
    document = pymupdf.open()
    document.new_page().insert_text((72, 72), TEXT)
    document.new_page().draw_rect(pymupdf.Rect(72, 72, 300, 200))
    document.save(path)
    document.close()
    return path


def test_auto_mode_sends_text_pages_as_text_and_scans_as_images(pdf: Path) -> None:
    first, second = extract_pdf(pdf, mode="auto")
    assert (first.kind, second.kind) == ("pdf_text", "pdf_image")
    assert "kinetic energy" in first.text and first.images == ()
    assert second.text == ""
    assert second.images[0].media_type == "image/png"
    assert second.images[0].data.startswith(b"\x89PNG")
    assert first.source_file == "sample.pdf" and second.number == 2


@pytest.mark.parametrize(("mode", "kind"), [("text", "pdf_text"), ("image", "pdf_image")])
def test_forced_modes(pdf: Path, mode: str, kind: str) -> None:
    pages = extract_pdf(pdf, mode=mode)  # type: ignore[arg-type]
    assert {p.kind for p in pages} == {kind}


def test_both_mode_sends_text_and_image(pdf: Path) -> None:
    first = extract_pdf(pdf, mode="both")[0]
    assert first.kind == "pdf_both" and first.text and len(first.images) == 1
    assert page_count(pdf) == 2


def test_word_math_becomes_tex(tmp_path: Path) -> None:
    path = tmp_path / "sample.docx"
    pypandoc.convert_text(
        "1. The kinetic energy is $\\frac{1}{2}mv^2$.\n\n(a) 9 J\n\n(b) 6 J\n",
        "docx",
        format="md",
        outputfile=str(path),
    )
    extract = extract_docx(path)
    [chunk] = extract.pages
    assert chunk.kind == "docx" and chunk.number == 1 and chunk.source_file == "sample.docx"
    assert "\\frac{1}{2}" in chunk.text
    assert extract.skipped_images == []


def test_chunks_keep_whole_blocks() -> None:
    html = "\n".join(f"<p>paragraph {i} " + "x" * 40 + "</p>" for i in range(10))
    chunks = _split_blocks(html, max_chars=120)
    assert len(chunks) > 1
    assert all(c.strip().startswith("<p>") and c.strip().endswith("</p>") for c in chunks)
    assert "".join(chunks).count("<p>") == 10


def test_supported_files() -> None:
    assert is_supported(Path("a.PDF")) and is_supported(Path("b.docx"))
    assert not is_supported(Path("c.doc")) and not is_supported(Path("answer-sheet.csv"))
