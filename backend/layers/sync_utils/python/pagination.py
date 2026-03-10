"""DynamoDB pagination cursor helpers."""
from __future__ import annotations

import base64
import json
from typing import Any


def encode_cursor(last_evaluated_key: dict[str, Any] | None) -> str | None:
    """Encode a DynamoDB ``LastEvaluatedKey`` to a URL-safe base64 string.

    Returns ``None`` when *last_evaluated_key* is ``None`` (no more pages).
    """
    if last_evaluated_key is None:
        return None
    return base64.urlsafe_b64encode(
        json.dumps(last_evaluated_key, default=str).encode()
    ).decode()


def decode_cursor(cursor_str: str | None) -> dict[str, Any] | None:
    """Decode a base64 cursor string back to a DynamoDB ``ExclusiveStartKey``.

    Returns ``None`` when *cursor_str* is absent or empty.

    Raises:
        ValueError: if the string is not valid base64 JSON.
    """
    if not cursor_str:
        return None
    try:
        decoded = base64.urlsafe_b64decode(cursor_str.encode())
        return json.loads(decoded)
    except Exception as exc:
        raise ValueError(f"Invalid pagination cursor: {exc}") from exc
