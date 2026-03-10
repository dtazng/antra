"""Tests for push_sync Lambda using moto to mock DynamoDB."""
from __future__ import annotations

import json
import os
import sys
from unittest.mock import patch

import boto3
import pytest
from moto import mock_dynamodb

# ---------------------------------------------------------------------------
# Ensure the sync_utils layer and functions are importable in tests.
# ---------------------------------------------------------------------------
LAYER_PATH = os.path.join(
    os.path.dirname(__file__), "..", "layers", "sync_utils", "python"
)
PUSH_PATH = os.path.join(
    os.path.dirname(__file__), "..", "functions", "push_sync"
)
sys.path.insert(0, LAYER_PATH)
sys.path.insert(0, PUSH_PATH)

TABLE_NAME = "antra_sync"
USER_ID = "test-user-002"
TOKEN = "Bearer mock-token"

os.environ["DYNAMODB_TABLE"] = TABLE_NAME
os.environ["COGNITO_USER_POOL_ID"] = "us-east-1_test"
os.environ["COGNITO_CLIENT_ID"] = "test-client-id"
os.environ["AWS_DEFAULT_REGION"] = "us-east-1"


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _create_table(client: boto3.client) -> None:
    client.create_table(
        TableName=TABLE_NAME,
        KeySchema=[
            {"AttributeName": "pk", "KeyType": "HASH"},
            {"AttributeName": "sk", "KeyType": "RANGE"},
        ],
        AttributeDefinitions=[
            {"AttributeName": "pk",        "AttributeType": "S"},
            {"AttributeName": "sk",        "AttributeType": "S"},
            {"AttributeName": "userId",    "AttributeType": "S"},
            {"AttributeName": "updatedAt", "AttributeType": "S"},
        ],
        GlobalSecondaryIndexes=[
            {
                "IndexName": "GSI1",
                "KeySchema": [
                    {"AttributeName": "userId",    "KeyType": "HASH"},
                    {"AttributeName": "updatedAt", "KeyType": "RANGE"},
                ],
                "Projection": {"ProjectionType": "ALL"},
            }
        ],
        BillingMode="PAY_PER_REQUEST",
    )


def _invoke(records: list, token: str = TOKEN) -> dict:
    import index  # noqa: PLC0415 — push_sync/index.py
    event = {
        "headers": {"Authorization": token},
        "body": json.dumps({"records": records}),
    }
    return index.handler(event, None)


def _make_record(
    entity_id: str,
    updated_at: str,
    sync_id: str | None = None,
) -> dict:
    return {
        "entityType": "bullet",
        "entityId": entity_id,
        "operation": "create",
        "payload": {
            "content": f"Bullet {entity_id}",
            "updatedAt": updated_at,
        },
        "syncId": sync_id,
    }


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

@mock_dynamodb
def test_new_record_is_created_and_sync_id_assigned() -> None:
    client = boto3.client("dynamodb", region_name="us-east-1")
    _create_table(client)

    with patch("index.verify_cognito_jwt", return_value=USER_ID):
        response = _invoke([_make_record("bullet-new-1", "2024-03-01T10:00:00Z")])

    assert response["statusCode"] == 200
    body = json.loads(response["body"])
    assert body["appliedCount"] == 1
    assert len(body["conflicts"]) == 0
    assert "bullet-new-1" in body["syncIds"]
    assert body["syncIds"]["bullet-new-1"] is not None


@mock_dynamodb
def test_conflict_when_server_record_is_newer() -> None:
    """When the server record has a later updatedAt, the push should conflict."""
    client = boto3.client("dynamodb", region_name="us-east-1")
    _create_table(client)

    resource = boto3.resource("dynamodb", region_name="us-east-1")
    table = resource.Table(TABLE_NAME)

    entity_id = "bullet-conflict-1"
    server_ts = "2024-03-01T12:00:00Z"

    # Pre-seed a newer server record.
    table.put_item(Item={
        "pk": f"USER#{USER_ID}",
        "sk": f"ENTITY#bullet#{entity_id}",
        "userId": USER_ID,
        "entityType": "bullet",
        "entityId": entity_id,
        "updatedAt": server_ts,
        "content": "Server version",
        "syncId": "server-sync-id",
    })

    # Client sends an older version.
    client_ts = "2024-03-01T10:00:00Z"
    with patch("index.verify_cognito_jwt", return_value=USER_ID):
        response = _invoke([_make_record(entity_id, client_ts)])

    assert response["statusCode"] == 200
    body = json.loads(response["body"])
    assert body["appliedCount"] == 0
    assert len(body["conflicts"]) == 1

    conflict = body["conflicts"][0]
    assert conflict["serverItem"]["updatedAt"] == server_ts
    assert conflict["clientItem"]["payload"]["updatedAt"] == client_ts


@mock_dynamodb
def test_returns_401_for_missing_auth() -> None:
    client = boto3.client("dynamodb", region_name="us-east-1")
    _create_table(client)

    import index  # noqa: PLC0415
    event = {"headers": {}, "body": json.dumps({"records": []})}
    response = index.handler(event, None)
    assert response["statusCode"] == 401


@mock_dynamodb
def test_batch_exceeding_limit_returns_400() -> None:
    client = boto3.client("dynamodb", region_name="us-east-1")
    _create_table(client)

    records = [_make_record(f"id-{i}", "2024-01-01T00:00:00Z") for i in range(501)]
    with patch("index.verify_cognito_jwt", return_value=USER_ID):
        response = _invoke(records)

    assert response["statusCode"] == 400
