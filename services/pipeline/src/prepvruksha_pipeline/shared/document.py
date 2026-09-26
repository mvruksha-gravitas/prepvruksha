"""A source document split into units the parser reads one at a time."""

from dataclasses import dataclass, field
from typing import Literal

# pdf_text: a PDF page's text layer. pdf_image: a rendered PDF page (scans).
# pdf_both: text layer plus the rendered page (pages with figures, or on request).
# docx: a chunk of a Word document.
PageKind = Literal["pdf_text", "pdf_image", "pdf_both", "docx"]


@dataclass(frozen=True)
class PageImage:
    media_type: Literal["image/png", "image/jpeg", "image/gif", "image/webp"]
    data: bytes


@dataclass(frozen=True)
class PageFigure:
    """A figure on the page (embedded image), numbered in reading order from 1."""

    number: int
    image: PageImage
    # PDF points (x0, y0, x1, y1) on the page; None for Word images.
    bbox: tuple[float, float, float, float] | None = None


@dataclass(frozen=True)
class Page:
    """One parse unit: a PDF page or a Word chunk, with its text, page image and figures."""

    source_file: str  # file name only; no paths or uploader details reach the model
    number: int  # 1-based page (PDF) or chunk (Word) number
    kind: PageKind
    text: str = ""
    images: tuple[PageImage, ...] = field(default=())  # the rendered page, if sent
    figures: tuple[PageFigure, ...] = field(default=())

    @property
    def key(self) -> str:
        return f"{self.source_file}#{self.number}:{self.kind}"


def figure_asset_name(source_file: str, page: int, figure: int) -> str:
    """File name of a saved figure; the link between a question and its figure."""
    safe = "".join(c if c.isalnum() else "_" for c in source_file)
    return f"{safe}-p{page}-fig{figure}.png"
