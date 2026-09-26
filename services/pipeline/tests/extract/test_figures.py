"""Figures on text pages are not lost: page image + numbered figure crops."""

from pathlib import Path

import pymupdf
import pypandoc
import pytest

from prepvruksha_pipeline.extract import extract_docx, extract_pdf

TEXT = "13. The velocity-time graph of a body is shown in the figure. Its displacement is"


def _png(width: int, height: int) -> bytes:
    pixmap = pymupdf.Pixmap(pymupdf.csRGB, pymupdf.IRect(0, 0, width, height), False)
    pixmap.clear_with(200)
    return bytes(pixmap.tobytes("png"))


@pytest.fixture
def pdf_with_figures(tmp_path: Path) -> Path:
    path = tmp_path / "setb.pdf"
    document = pymupdf.open()
    page = document.new_page()
    page.insert_text((72, 72), TEXT)
    page.insert_image(pymupdf.Rect(300, 400, 500, 550), stream=_png(200, 150))  # lower figure
    page.insert_image(pymupdf.Rect(100, 150, 300, 300), stream=_png(200, 150))  # upper figure
    page.insert_image(pymupdf.Rect(500, 40, 520, 60), stream=_png(20, 20))  # a logo, not a figure
    document.new_page().insert_text((72, 72), "14. A page with text only and no figures at all.")
    document.save(path)
    document.close()
    return path


def test_text_page_with_figures_also_sends_the_page_image(pdf_with_figures: Path) -> None:
    first, second = extract_pdf(pdf_with_figures, mode="auto")
    assert first.kind == "pdf_both" and "velocity-time graph" in first.text
    assert len(first.images) == 1  # the whole page
    assert second.kind == "pdf_text" and second.images == () and second.figures == ()


def test_figures_are_cut_out_in_reading_order_without_logos(pdf_with_figures: Path) -> None:
    figures = extract_pdf(pdf_with_figures, mode="auto")[0].figures
    assert [f.number for f in figures] == [1, 2]
    assert [f.bbox for f in figures] == [(100.0, 150.0, 300.0, 300.0), (300.0, 400.0, 500.0, 550.0)]
    assert all(f.image.data.startswith(b"\x89PNG") for f in figures)


def test_text_mode_still_extracts_figures_without_the_page_image(pdf_with_figures: Path) -> None:
    first = extract_pdf(pdf_with_figures, mode="text")[0]
    assert first.kind == "pdf_text" and first.images == () and len(first.figures) == 2


def test_word_images_become_numbered_figures(tmp_path: Path) -> None:
    image = tmp_path / "graph.png"
    image.write_bytes(_png(40, 30))
    path = tmp_path / "seta.docx"
    pypandoc.convert_text(
        f"13. Study the graph.\n\n![graph]({image.as_posix()})\n\n(a) 20 m\n",
        "docx",
        format="md",
        outputfile=str(path),
    )
    [chunk] = extract_docx(path).pages
    assert [f.number for f in chunk.figures] == [1]
    assert chunk.figures[0].image.media_type == "image/png" and chunk.figures[0].bbox is None
    assert "[Figure 1]" in chunk.text and "<img" not in chunk.text
