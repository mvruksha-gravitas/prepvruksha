"""Extract feature: source files to parse units (pages / chunks). Public entry."""

from pathlib import Path

from prepvruksha_pipeline.extract.docx import DocxExtract, extract_docx
from prepvruksha_pipeline.extract.pdf import (
    PdfMode,
    extract_pdf,
    page_count,
    render_pdf_page,
)

SUPPORTED_SUFFIXES = (".pdf", ".docx")


def is_supported(path: Path) -> bool:
    return path.suffix.lower() in SUPPORTED_SUFFIXES


__all__ = [
    "SUPPORTED_SUFFIXES",
    "DocxExtract",
    "PdfMode",
    "extract_docx",
    "extract_pdf",
    "is_supported",
    "page_count",
    "render_pdf_page",
]
