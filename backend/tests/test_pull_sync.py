"""Tests for pull_sync Lambda using moto to mock DynamoDB."""
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
PULL_PATH = os.path.join(
    os.path.dirname(__file__), "..", "functions", "pull_sync"
)
sys.path.insert(0, LAYER_PATH)
sys.path.insert(0, PULL_PATH)

TABLE_NAME = "antra_sync"
USER_ID = "test-user-001"
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


def _seed_record(
    table: boto3.resource,
    entity_id: str,
    entity_type: str,
    updated_at: str,
) -> None:
    table.put_item(Item={
        "pk": f"USER#{USER_ID}",
        "sk": f"ENTITY#{entity_type}#{entity_id}",
        "userId": USER_ID,
        "entityType": entity_type,
        "entityId": entity_id,
        "updatedAt": updated_at,
        "content": f"Bullet {entity_id}",
    })


def _invoke(body: dict, token: str = TOKEN) -> dict:
    import index  # noqa: PLC0415 — pull_sync/index.py
    event = {
        "headers": {"Authorization": token},
        "body": json.dumps(body),
    }
    return index.handler(event, None)


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

@mock_dynamodb
def test_returns_only_records_after_last_sync_timestamp() -> None:
    client = boto3.client("dynamodb", region_name="us-east-1")
    _create_table(client)

    resource = boto3.resource("dynamodb", region_name="us-east-1")
    table = resource.Table(TABLE_NAME)

    # Seed 5 records across two timestamps.
    _seed_record(table, "id-1", "bullet", "2024-01-01T10:00:00Z")
    _seed_record(table, "id-2", "bullet", "2024-01-01T11:00:00Z")
    _seed_record(table, "id-3", "bullet", "2024-01-02T09:00:00Z")
    _seed_record(table, "id-4", "bullet", "2024-01-02T10:00:00Z")
    _seed_record(table, "id-5", "bullet", "2024-01-03T08:00:00Z")

    with patch("index.verify_cognito_jwt", return_value=USER_ID):
        response = _invoke({"lastSyncTimestamp": "2024-01-02T00:00:00Z"})

    assert response["statusCode"] == 200
    body = json.loads(response["body"])
    returned_ids = {r["entityId"] for r in body["records"]}

    assert "id-1" not in returned_ids
    assert "id-2" not in returned_ids
    assert "id-3" in returned_ids
    assert "id-4" in returned_ids
    assert "id-5" in returned_ids
    assert body["hasMore"] is False


@mock_dynamodb
def test_pagination_cursor_works_across_two_pages() -> None:
    client = boto3.client("dynamodb", region_name="us-east-1")
    _create_table(client)

    resource = boto3.resource("dynamodb", region_name="us-east-1")
    table = resource.Table(TABLE_NAME)

    # Seed 6 records so we can page with Limit=3.
    for i in range(6):
        _seed_record(table, f"page-{i}", "bullet", f"2024-06-01T0{i}:00:00Z")

    # Monkey-patch _PAGE_SIZE to 3 for this test.
    import index as pull_index  # noqa: PLC0415
    original = pull_index._PAGE_SIZE
    pull_index._PAGE_SIZE = 3

    try:
        with patch("index.verify_cognito_jwt", return_value=USER_ID):
            # First page
            resp1 = _invoke({"lastSyncTimestamp": "2024-01-01T00:00:00Z"})
        body1 = json.loads(resp1["body"])
        assert resp1["statusCode"] == 200
        assert len(body1["records"]) == 3
        assert body1["hasMore"] is True
        assert body1["nextCursor"] is not None

        # Second page
        with patch("index.verify_cognito_jwt", return_value=USER_ID):
            resp2 = _invoke({
                "lastSyncTimestamp": "2024-01-01T00:00:00Z",
                "cursor": body1["nextCursor"],
            })
        body2 = json.loads(resp2["body"])
        assert resp2["statusCode"] == 200
        assert len(body2["records"]) == 3
        assert body2["hasMore"] is False

        # All 6 unique IDs across both pages.
        all_ids = (
            {r["entityId"] for r in body1["records"]}
            | {r["entityId"] for r in body2["records"]}
        )
        assert len(all_ids) == 6
    finally:
        pull_index._PAGE_SIZE = original


@mock_dynamodb
def test_returns_401_for_missing_auth() -> None:
    client = boto3.client("dynamodb", region_name="us-east-1")
    _create_table(client)

    import index  # noqa: PLC0415
    event = {"headers": {}, "body": json.dumps({"lastSyncTimestamp": "1970-01-01T00:00:00Z"})}
    response = index.handler(event, None)
    assert response["statusCode"] == 401
