"""PDF pages: the text layer (PyMuPDF), the rendered page, and embedded figures.

"auto" mode: scanned pages (no text layer) go as the page image; text pages go
as text, plus the page image when they contain figures, so diagrams are not
lost. Each embedded figure is also cut out and numbered in reading order, so
the parser can link it to its question and it can be saved as an asset.
"""

from pathlib import Path
from typing import Literal

import pymupdf

from prepvruksha_pipeline.shared import Page, PageFigure, PageImage

PdfMode = Literal["auto", "text", "image", "both"]

# Fewer characters than this in the text layer means a scanned page.
MIN_TEXT_CHARS = 40
# Images smaller than this (points, either side) are logos or bullets, not figures.
MIN_FIGURE_SIDE = 40
# An image covering most of the page is the page itself (a scan), not a figure.
MAX_FIGURE_AREA = 0.8


def render_page_png(page: pymupdf.Page, dpi: int, clip: pymupdf.Rect | None = None) -> bytes:
    pixmap = page.get_pixmap(dpi=dpi, clip=clip)
    return bytes(pixmap.tobytes("png"))


def figure_boxes(page: pymupdf.Page) -> list[tuple[float, float, float, float]]:
    """Embedded images that are figures, top-to-bottom then left-to-right."""
    page_area = page.rect.width * page.rect.height
    boxes: list[tuple[float, float, float, float]] = []
    for info in page.get_image_info():
        x0, y0, x1, y1 = (float(v) for v in info["bbox"])
        width, height = x1 - x0, y1 - y0
        if width < MIN_FIGURE_SIDE or height < MIN_FIGURE_SIDE:
            continue
        if width * height > MAX_FIGURE_AREA * page_area:
            continue
        box = (round(x0, 1), round(y0, 1), round(x1, 1), round(y1, 1))
        if box not in boxes:
            boxes.append(box)
    return sorted(boxes, key=lambda b: (b[1], b[0]))


def extract_pdf(path: Path, mode: PdfMode = "auto", dpi: int = 150) -> list[Page]:
    pages: list[Page] = []
    with pymupdf.open(path) as document:
        for index, page in enumerate(document, start=1):
            text = str(page.get_text("text")).strip()
            scanned = len(text) < MIN_TEXT_CHARS
            boxes = [] if scanned else figure_boxes(page)
            use_text = mode in ("text", "both") or (mode == "auto" and not scanned)
            use_image = mode in ("image", "both") or (mode == "auto" and (scanned or bool(boxes)))
            if use_text and use_image:
                kind: Literal["pdf_text", "pdf_image", "pdf_both"] = "pdf_both"
            elif use_image:
                kind = "pdf_image"
            else:
                kind = "pdf_text"
            images = (PageImage("image/png", render_page_png(page, dpi)),) if use_image else ()
            figures = tuple(
                PageFigure(
                    number=number,
                    image=PageImage("image/png", render_page_png(page, dpi, pymupdf.Rect(box))),
                    bbox=box,
                )
                for number, box in enumerate(boxes, start=1)
            )
            pages.append(
                Page(
                    source_file=path.name,
                    number=index,
                    kind=kind,
                    text=text if use_text else "",
                    images=images,
                    figures=figures,
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
