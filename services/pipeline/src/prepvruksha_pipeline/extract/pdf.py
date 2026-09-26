"""PDF pages: the text layer (PyMuPDF) and/or a rendered page image.

Scanned pages have (almost) no text layer; in "auto" mode they are sent to
the parser as images, text pages as text.
"""

from pathlib import Path
from typing import Literal

import pymupdf

from prepvruksha_pipeline.shared import Page, PageImage

PdfMode = Literal["auto", "text", "image", "both"]

# Fewer characters than this in the text layer means a scanned page.
MIN_TEXT_CHARS = 40


def render_page_png(page: pymupdf.Page, dpi: int) -> bytes:
    pixmap = page.get_pixmap(dpi=dpi)
    return bytes(pixmap.tobytes("png"))


def extract_pdf(path: Path, mode: PdfMode = "auto", dpi: int = 150) -> list[Page]:
    pages: list[Page] = []
    with pymupdf.open(path) as document:
        for index, page in enumerate(document, start=1):
            text = str(page.get_text("text")).strip()
            scanned = len(text) < MIN_TEXT_CHARS
            use_text = mode in ("text", "both") or (mode == "auto" and not scanned)
            use_image = mode in ("image", "both") or (mode == "auto" and scanned)
            if use_text and use_image:
                kind: Literal["pdf_text", "pdf_image", "pdf_both"] = "pdf_both"
            elif use_image:
                kind = "pdf_image"
            else:
                kind = "pdf_text"
            images = (PageImage("image/png", render_page_png(page, dpi)),) if use_image else ()
            pages.append(
                Page(
                    source_file=path.name,
                    number=index,
                    kind=kind,
                    text=text if use_text else "",
                    images=images,
                )
            )
    return pages


def page_count(path: Path) -> int:
    with pymupdf.open(path) as document:
        return int(document.page_count)


def render_pdf_page(path: Path, number: int, dpi: int = 110) -> bytes:
    """A page image for the review report (1-based page number)."""
    with pymupdf.open(path) as document:
        return render_page_png(document[number - 1], dpi)
