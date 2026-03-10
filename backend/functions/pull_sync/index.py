"""pull_sync Lambda — returns all records updated after a given timestamp."""
from __future__ import annotations

import json
import os
from typing import Any

import boto3

# Sync utils layer (injected at runtime via Lambda layer)
from auth import verify_cognito_jwt, AuthError
from pagination import decode_cursor, encode_cursor

_TABLE_NAME = os.environ["DYNAMODB_TABLE"]
_dynamodb = boto3.resource("dynamodb")
_PAGE_SIZE = 500


def handler(event: dict[str, Any], context: Any) -> dict[str, Any]:
    """Handle POST /sync/pull.

    Request body:
        {
          "lastSyncTimestamp": "2024-01-01T00:00:00Z",   // ISO 8601 UTC
          "cursor": null | "<base64 string>"              // for pagination
        }

    Response body:
        {
          "records": [...],
          "serverTimestamp": "2024-01-02T00:00:00Z",
          "hasMore": false,
          "nextCursor": null | "<base64 string>"
        }
    """
    # 1. Authenticate.
    try:
        auth_header = (event.get("headers") or {}).get("Authorization")
        user_id = verify_cognito_jwt(auth_header)
    except AuthError as exc:
        return _response(401, {"error": str(exc)})

    # 2. Parse request body.
    try:
        body = json.loads(event.get("body") or "{}")
        last_sync_ts: str = body.get("lastSyncTimestamp", "1970-01-01T00:00:00Z")
        cursor_str: str | None = body.get("cursor")
    except (json.JSONDecodeError, TypeError) as exc:
        return _response(400, {"error": f"Invalid request body: {exc}"})

    # 3. Decode pagination cursor.
    try:
        exclusive_start_key = decode_cursor(cursor_str)
    except ValueError as exc:
        return _response(400, {"error": str(exc)})

    # 4. Query GSI1: (userId, updatedAt > lastSyncTimestamp).
    table = _dynamodb.Table(_TABLE_NAME)
    query_kwargs: dict[str, Any] = {
        "IndexName": "GSI1",
        "KeyConditionExpression": (
            "userId = :uid AND updatedAt > :ts"
        ),
        "ExpressionAttributeValues": {
            ":uid": user_id,
            ":ts": last_sync_ts,
        },
        "Limit": _PAGE_SIZE,
    }
    if exclusive_start_key:
        query_kwargs["ExclusiveStartKey"] = exclusive_start_key

    try:
        result = table.query(**query_kwargs)
    except Exception as exc:
        return _response(500, {"error": f"DynamoDB query failed: {exc}"})

    records = result.get("Items", [])
    last_key = result.get("LastEvaluatedKey")
    next_cursor = encode_cursor(last_key)

    import datetime
    server_timestamp = datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")

    return _response(200, {
        "records": records,
        "serverTimestamp": server_timestamp,
        "hasMore": last_key is not None,
        "nextCursor": next_cursor,
    })


def _response(status_code: int, body: dict[str, Any]) -> dict[str, Any]:
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
        },
        "body": json.dumps(body, default=str),
    }
