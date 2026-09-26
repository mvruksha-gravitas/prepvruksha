"""A source document split into units the parser reads one at a time."""

from dataclasses import dataclass, field
from typing import Literal

# pdf_text: a PDF page's text layer. pdf_image: a rendered PDF page (scans,
# or to compare with the text layer). docx: a chunk of a Word document.
PageKind = Literal["pdf_text", "pdf_image", "pdf_both", "docx"]


@dataclass(frozen=True)
class PageImage:
    media_type: Literal["image/png", "image/jpeg", "image/gif", "image/webp"]
    data: bytes


@dataclass(frozen=True)
class Page:
    """One parse unit: a PDF page or a Word chunk, with its text and images."""

    source_file: str  # file name only; no paths or uploader details reach the model
    number: int  # 1-based page (PDF) or chunk (Word) number
    kind: PageKind
    text: str = ""
    images: tuple[PageImage, ...] = field(default=())

    @property
    def key(self) -> str:
        return f"{self.source_file}#{self.number}:{self.kind}"
