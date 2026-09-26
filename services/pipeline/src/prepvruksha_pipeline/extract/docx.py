"""Word documents: Pandoc to HTML with TeX math, split into chunks.

Word has no fixed pages, so the parse unit is a chunk of whole paragraphs.
Embedded images in formats the model reads (PNG, JPEG, GIF, WebP) travel with
their chunk; others (EMF/WMF, often old equation objects) are reported.
"""

import re
import tempfile
from dataclasses import dataclass, field
from pathlib import Path

import pypandoc

from prepvruksha_pipeline.shared import Page, PageImage

MAX_CHUNK_CHARS = 60_000
_MEDIA_TYPES = {
    ".png": "image/png",
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".gif": "image/gif",
    ".webp": "image/webp",
}
_IMG_SRC = re.compile(r'<img[^>]*\ssrc="([^"]+)"')


@dataclass
class DocxExtract:
    pages: list[Page]
    skipped_images: list[str] = field(default_factory=list)


def _split_blocks(html: str, max_chars: int) -> list[str]:
    """Split on top-level block boundaries, keeping each chunk under max_chars."""
    blocks = [b for b in re.split(r"\n(?=<(?:p|h\d|ol|ul|table|div|blockquote)\b)", html) if b]
    chunks: list[str] = []
    current = ""
    for block in blocks:
        if current and len(current) + len(block) > max_chars:
            chunks.append(current)
            current = ""
        current += block + "\n"
    if current.strip():
        chunks.append(current)
    return chunks


def extract_docx(path: Path, max_chars: int = MAX_CHUNK_CHARS) -> DocxExtract:
    with tempfile.TemporaryDirectory() as media_dir:
        html = pypandoc.convert_file(
            str(path),
            "html",
            extra_args=["--mathjax", f"--extract-media={media_dir}", "--wrap=none"],
        )
        result = DocxExtract(pages=[])
        for number, chunk in enumerate(_split_blocks(html, max_chars), start=1):
            images: list[PageImage] = []
            for src in _IMG_SRC.findall(chunk):
                image_path = Path(src)
                media_type = _MEDIA_TYPES.get(image_path.suffix.lower())
                if media_type is None or not image_path.is_file():
                    result.skipped_images.append(f"{path.name}: {image_path.name}")
                    continue
                images.append(PageImage(media_type, image_path.read_bytes()))  # type: ignore[arg-type]
            # Image paths are temporary; the model sees the image order instead.
            text = _IMG_SRC.sub(lambda m: m.group(0).replace(m.group(1), "embedded-image"), chunk)
            result.pages.append(
                Page(
                    source_file=path.name,
                    number=number,
                    kind="docx",
                    text=text.strip(),
                    images=tuple(images),
                )
            )
        return result
