"""Parse one page or chunk with the Claude API into the fixed JSON format.

Only document content is sent: the file name, its text and page images. No
uploader or user details (CLAUDE.md rule 3).
"""

import base64
import time
from dataclasses import dataclass
from typing import Any, Literal, Protocol, cast

import anthropic

from prepvruksha_pipeline.parse.pricing import TokenUsage, cost_usd
from prepvruksha_pipeline.parse.prompt import SYSTEM_PROMPT, page_instruction
from prepvruksha_pipeline.parse.schema import PageParse
from prepvruksha_pipeline.parse.validate import check_question
from prepvruksha_pipeline.shared import Page

Effort = Literal["low", "medium", "high", "xhigh", "max"]
MAX_TOKENS = 16_000


class MessagesClient(Protocol):
    """The part of `anthropic.Anthropic().messages` the parser uses."""

    def parse(self, **kwargs: Any) -> Any: ...


@dataclass
class PageResult:
    page_key: str
    source_file: str
    page_number: int
    kind: str
    model: str
    effort: str
    parse: PageParse | None
    usage: TokenUsage
    cost_usd: float | None
    seconds: float
    error: str | None = None


def build_content(page: Page) -> list[dict[str, Any]]:
    content: list[dict[str, Any]] = [
        {
            "type": "image",
            "source": {
                "type": "base64",
                "media_type": image.media_type,
                "data": base64.standard_b64encode(image.data).decode("ascii"),
            },
        }
        for image in page.images
    ]
    text = page_instruction(page.source_file, page.number, page.kind)
    if page.text:
        text += f"\n\n<source_text>\n{page.text}\n</source_text>"
    if page.images and page.kind == "pdf_both":
        text += "\n\nThe image shows the same page; use it where the text layer is garbled."
    content.append({"type": "text", "text": text})
    return content


def _usage(raw: Any) -> TokenUsage:
    return TokenUsage(
        input_tokens=raw.input_tokens or 0,
        output_tokens=raw.output_tokens or 0,
        cache_creation_input_tokens=getattr(raw, "cache_creation_input_tokens", 0) or 0,
        cache_read_input_tokens=getattr(raw, "cache_read_input_tokens", 0) or 0,
    )


class PageParser:
    def __init__(self, messages: MessagesClient, model: str, effort: Effort = "high") -> None:
        self._messages = messages
        self._model = model
        self._effort = effort

    def parse_page(self, page: Page) -> PageResult:
        started = time.monotonic()

        def result(
            parse: PageParse | None, usage: TokenUsage, error: str | None = None
        ) -> PageResult:
            return PageResult(
                page_key=page.key,
                source_file=page.source_file,
                page_number=page.number,
                kind=page.kind,
                model=self._model,
                effort=self._effort,
                parse=parse,
                usage=usage,
                cost_usd=cost_usd(self._model, usage),
                seconds=round(time.monotonic() - started, 2),
                error=error,
            )

        try:
            response = self._messages.parse(
                model=self._model,
                max_tokens=MAX_TOKENS,
                system=SYSTEM_PROMPT,
                messages=[{"role": "user", "content": build_content(page)}],
                output_format=PageParse,
                output_config={"effort": self._effort},
            )
        except anthropic.APIStatusError as error:
            return result(None, TokenUsage(), f"API error {error.status_code}: {error.message}")
        except anthropic.APIConnectionError as error:
            return result(None, TokenUsage(), f"connection error: {error}")

        usage = _usage(response.usage)
        if response.stop_reason == "refusal":
            return result(None, usage, "refused")
        if response.stop_reason == "max_tokens":
            return result(None, usage, f"output cut off at {MAX_TOKENS} tokens")
        parsed = response.parsed_output
        if not isinstance(parsed, PageParse):
            return result(None, usage, "no structured output")
        checked = parsed.model_copy(
            update={"questions": [check_question(q) for q in parsed.questions]}
        )
        return result(checked, usage)


def default_messages_client(api_key: str) -> MessagesClient:
    client = anthropic.Anthropic(api_key=api_key, max_retries=4)
    return cast(MessagesClient, client.messages)
