"""Code shared by the pipeline features: settings and document types."""

from prepvruksha_pipeline.shared.document import (
    Page,
    PageFigure,
    PageImage,
    PageKind,
    figure_asset_name,
)
from prepvruksha_pipeline.shared.settings import Settings

__all__ = ["Page", "PageFigure", "PageImage", "PageKind", "Settings", "figure_asset_name"]
