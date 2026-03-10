"""push_sync Lambda — accepts client writes and resolves conflicts via LWW."""
from __future__ import annotations

import json
import os
import uuid
from typing import Any

# Sync utils layer
from auth import verify_cognito_jwt, AuthError
from conflicts import apply_lww

_TABLE_NAME = os.environ["DYNAMODB_TABLE"]
_MAX_RECORDS = 500


def handler(event: dict[str, Any], context: Any) -> dict[str, Any]:
    """Handle POST /sync/push.

    Request body:
        {
          "records": [
            {
              "entityType": "bullet",
              "entityId":   "<uuid>",
              "operation":  "create" | "update" | "delete",
              "payload":    { ...entity fields... },
              "syncId":     null | "<uuid>"   // client assigns for new records
            },
            ...
          ]
        }

    Response body:
        {
          "appliedCount": 3,
          "conflicts": [
            {
              "clientItem": {...},
              "serverItem": {...}
            }
          ],
          "syncIds": { "<entityId>": "<syncId>", ... }
        }
    """
    # 1. Authenticate.
    try:
        auth_header = (event.get("headers") or {}).get("Authorization")
        user_id = verify_cognito_jwt(auth_header)
    except AuthError as exc:
        return _response(401, {"error": str(exc)})

    # 2. Parse request.
    try:
        body = json.loads(event.get("body") or "{}")
        records: list[dict[str, Any]] = body.get("records", [])
    except (json.JSONDecodeError, TypeError) as exc:
        return _response(400, {"error": f"Invalid request body: {exc}"})

    if len(records) > _MAX_RECORDS:
        return _response(400, {"error": f"Batch exceeds {_MAX_RECORDS} records"})

    # 3. Apply each record with LWW.
    applied_count = 0
    conflicts: list[dict[str, Any]] = []
    sync_ids: dict[str, str] = {}

    for record in records:
        entity_type: str = record.get("entityType", "")
        entity_id: str = record.get("entityId", "")
        payload: dict[str, Any] = record.get("payload", {})
        sync_id: str = record.get("syncId") or str(uuid.uuid4())

        pk = f"USER#{user_id}"
        sk = f"ENTITY#{entity_type}#{entity_id}"

        item = {
            **payload,
            "userId": user_id,
            "entityType": entity_type,
            "entityId": entity_id,
            "syncId": sync_id,
        }

        conflict = apply_lww(_TABLE_NAME, pk, sk, item)
        if conflict is None:
            applied_count += 1
            sync_ids[entity_id] = sync_id
        else:
            client_item, server_item = conflict
            conflicts.append({
                "clientItem": client_item,
                "serverItem": server_item,
            })

    return _response(200, {
        "appliedCount": applied_count,
        "conflicts": conflicts,
        "syncIds": sync_ids,
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
