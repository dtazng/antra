"""Last-Write-Wins (LWW) conflict resolution for DynamoDB sync."""
from __future__ import annotations

from typing import Any

import boto3
from botocore.exceptions import ClientError

_dynamodb = boto3.resource("dynamodb")


ConflictTuple = tuple[dict[str, Any], dict[str, Any]]
"""(client_item, server_item) when a conflict is detected."""


def apply_lww(
    table_name: str,
    pk: str,
    sk: str,
    incoming: dict[str, Any],
) -> ConflictTuple | None:
    """Write *incoming* to DynamoDB only if its ``updatedAt`` is newer.

    Uses a conditional ``put_item`` so that concurrent writers can't
    silently overwrite a more-recent server record.

    Returns:
        ``None`` if the write succeeded (no conflict).
        ``(incoming, server_item)`` if the server record is newer
        (LWW: server wins; client item is the loser).

    Raises:
        Any unexpected DynamoDB error (re-raised).
    """
    table = _dynamodb.Table(table_name)
    condition = (
        "attribute_not_exists(updatedAt) OR updatedAt < :ts"
    )

    try:
        table.put_item(
            Item={**incoming, "pk": pk, "sk": sk},
            ConditionExpression=condition,
            ExpressionAttributeValues={":ts": incoming["updatedAt"]},
        )
        return None  # Success — no conflict.

    except ClientError as exc:
        if exc.response["Error"]["Code"] != "ConditionalCheckFailedException":
            raise

    # Conflict: fetch the winning server record.
    response = table.get_item(Key={"pk": pk, "sk": sk})
    server_item = response.get("Item", {})
    return (incoming, server_item)
