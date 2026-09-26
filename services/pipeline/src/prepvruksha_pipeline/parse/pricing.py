"""Claude API list prices (USD per million tokens), for cost-per-page reports."""

from dataclasses import dataclass

# (input, output). Cache writes cost 1.25x input, cache reads 0.1x input.
PRICES_PER_MTOK: dict[str, tuple[float, float]] = {
    "claude-opus-5": (5.00, 25.00),
    "claude-opus-5-5": (4.00, 20.00),
    "claude-sonnet-5": (2.00, 10.00),
    "claude-haiku-4-5": (1.00, 5.00),
    "claude-fable-5-1": (10.00, 50.00),
}


@dataclass(frozen=True)
class TokenUsage:
    input_tokens: int = 0
    output_tokens: int = 0
    cache_creation_input_tokens: int = 0
    cache_read_input_tokens: int = 0

    def __add__(self, other: "TokenUsage") -> "TokenUsage":
        return TokenUsage(
            self.input_tokens + other.input_tokens,
            self.output_tokens + other.output_tokens,
            self.cache_creation_input_tokens + other.cache_creation_input_tokens,
            self.cache_read_input_tokens + other.cache_read_input_tokens,
        )


def cost_usd(model: str, usage: TokenUsage) -> float | None:
    """None for a model without a known price (the report says so)."""
    prices = PRICES_PER_MTOK.get(model)
    if prices is None:
        return None
    input_price, output_price = prices
    return (
        usage.input_tokens * input_price
        + usage.cache_creation_input_tokens * input_price * 1.25
        + usage.cache_read_input_tokens * input_price * 0.1
        + usage.output_tokens * output_price
    ) / 1_000_000
