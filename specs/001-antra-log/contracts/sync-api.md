# Contract: Sync API (AWS Lambda + API Gateway)

**Branch**: `001-antra-log` | **Date**: 2026-03-09
**Research**: [research.md](../research.md) | **Data Model**: [data-model.md](../data-model.md)

The sync API is implemented as two AWS Lambda functions (Go 1.22+, `provided.al2023`, ARM64)
fronted by AWS API Gateway (REST). Authentication is via AWS Cognito JWT bearer tokens.

All timestamps are ISO 8601 UTC strings (e.g., `2026-03-09T10:30:00Z`).
All requests MUST include `Authorization: Bearer <cognitoJwt>` header.

---

## Common Types

### SyncRecord

```typescript
interface SyncRecord {
  id: string;                 // Client UUID (matches DynamoDB entityId)
  syncId: string | null;      // Server UUID; null for new records on first push
  entityType: EntityType;
  data: string;               // JSON-serialized entity; opaque if E2E encrypted
  updatedAt: string;          // ISO 8601 UTC — LWW resolution key
  deviceId: string;           // Device that last wrote
  isDeleted: boolean;         // Soft-delete tombstone
  encryptionEnabled: boolean; // True when data is E2E ciphertext
}

type EntityType =
  | "bullet"
  | "day_log"
  | "person"
  | "tag"
  | "bullet_person_link"
  | "bullet_tag_link"
  | "collection"
  | "review";
```

### ConflictInfo

```typescript
interface ConflictInfo {
  id: string;
  entityType: EntityType;
  serverVersion: SyncRecord;  // The version that won (remote, newer updatedAt)
  clientVersion: SyncRecord;  // The client version that lost (for local conflict copy)
  resolution: "last_write_wins";
}
```

---

## POST /sync/pull

Pull all records changed on the server since the client's last sync checkpoint.

**Lambda function**: `pull_sync` (Go 1.22+, `provided.al2023`, ARM64, 512 MB, read-only DynamoDB IAM)

**Authorization**: Required — Cognito JWT

**Request body**:

```typescript
interface SyncPullRequest {
  deviceId: string;
  lastSyncTimestamp: string;   // ISO 8601 UTC; "1970-01-01T00:00:00Z" for first sync
  entityTypes: EntityType[];   // Subset to pull; omit for all types
  cursor?: string;             // Opaque pagination cursor (from previous response)
}
```

**Example request**:

```json
{
  "deviceId": "A1B2C3D4-E5F6-7890-ABCD-EF1234567890",
  "lastSyncTimestamp": "2026-03-08T18:00:00Z",
  "entityTypes": ["bullet", "person", "tag", "bullet_person_link", "bullet_tag_link"]
}
```

**Go Lambda implementation** (`cmd/pull_sync/main.go`):

```go
func handler(ctx context.Context, event events.APIGatewayProxyRequest) (
    events.APIGatewayProxyResponse, error) {

    userID, err := auth.VerifyCognitoJWT(event.Headers["Authorization"])
    if err != nil {
        return response(401, map[string]string{"error": err.Error()})
    }

    var req SyncPullRequest
    if err := json.Unmarshal([]byte(event.Body), &req); err != nil {
        return response(400, map[string]string{"error": "invalid body"})
    }

    exclusiveStartKey, err := pagination.DecodeCursor(req.Cursor)
    if err != nil {
        return response(400, map[string]string{"error": err.Error()})
    }

    result, err := dynamoClient.Query(ctx, &dynamodb.QueryInput{
        TableName:              aws.String(tableName),
        IndexName:              aws.String("GSI1"),
        KeyConditionExpression: aws.String("userId = :uid AND updatedAt > :ts"),
        ExpressionAttributeValues: map[string]types.AttributeValue{
            ":uid": &types.AttributeValueMemberS{Value: userID},
            ":ts":  &types.AttributeValueMemberS{Value: req.LastSyncTimestamp},
        },
        Limit:             aws.Int32(500),
        ExclusiveStartKey: exclusiveStartKey,
    })
    // ...
    nextCursor := pagination.EncodeCursor(result.LastEvaluatedKey)
    return response(200, SyncPullResponse{
        Records:         items,
        ServerTimestamp: time.Now().UTC().Format(time.RFC3339),
        HasMore:         result.LastEvaluatedKey != nil,
        NextCursor:      nextCursor,
    })
}
```

**Response — 200 OK**:

```typescript
interface SyncPullResponse {
  records: SyncRecord[];
  serverTimestamp: string;    // Save as new sync checkpoint ONLY on final page
  hasMore: boolean;
  nextCursor: string | null;  // Opaque; pass as cursor in next request if hasMore
}
```

**Pagination rule**: Client MUST re-call `POST /sync/pull` with the returned `cursor`
until `hasMore = false`. Save `serverTimestamp` only from the final response.

**Error responses**:

| Status | Code | Description |
| ------ | ---- | ----------- |
| 401 | `unauthorized` | Missing, invalid, or expired Cognito JWT |
| 400 | `invalid_timestamp` | `lastSyncTimestamp` is not valid ISO 8601 |
| 429 | `rate_limited` | Retry after `Retry-After` header (60 req/min limit) |

---

## POST /sync/push

Push a batch of local changes to the server. Server applies LWW conflict resolution
and returns any conflicts detected.

**Lambda function**: `push_sync` (Go 1.22+, `provided.al2023`, ARM64, 1024 MB, read-write DynamoDB IAM)

**Authorization**: Required — Cognito JWT

**Batch limit**: Maximum 500 records per request. Client MUST split larger queues.

**Request body**:

```typescript
interface SyncPushRequest {
  deviceId: string;
  changes: SyncRecord[];      // All records from local pending_sync table
}
```

**Go Lambda LWW implementation** (`internal/conflicts/conflicts.go`):

```go
// ApplyLWW writes item only if incoming updatedAt is newer than the stored value.
// Returns (nil, nil) on success; returns (clientItem, serverItem) on conflict.
func ApplyLWW(ctx context.Context, client *dynamodb.Client, tableName, pk, sk string,
    incoming map[string]types.AttributeValue) (clientItem, serverItem map[string]types.AttributeValue, err error) {

    incoming["pk"] = &types.AttributeValueMemberS{Value: pk}
    incoming["sk"] = &types.AttributeValueMemberS{Value: sk}

    _, err = client.PutItem(ctx, &dynamodb.PutItemInput{
        TableName: aws.String(tableName),
        Item:      incoming,
        ConditionExpression: aws.String(
            "attribute_not_exists(updatedAt) OR updatedAt < :ts"),
        ExpressionAttributeValues: map[string]types.AttributeValue{
            ":ts": incoming["updatedAt"],
        },
    })
    if err == nil {
        return nil, nil, nil // applied — no conflict
    }

    var condErr *types.ConditionalCheckFailedException
    if !errors.As(err, &condErr) {
        return nil, nil, err // unexpected error
    }

    // Conflict: fetch the winning server record.
    out, getErr := client.GetItem(ctx, &dynamodb.GetItemInput{
        TableName: aws.String(tableName),
        Key: map[string]types.AttributeValue{
            "pk": &types.AttributeValueMemberS{Value: pk},
            "sk": &types.AttributeValueMemberS{Value: sk},
        },
    })
    if getErr != nil {
        return nil, nil, getErr
    }
    return incoming, out.Item, nil
}
```

**Response — 200 OK**:

```typescript
interface SyncPushResponse {
  appliedCount: number;
  conflicts: ConflictInfo[];
  syncIds: { [clientId: string]: string };  // Server-assigned syncId for new records
}
```

**Example response** (with one conflict):

```json
{
  "appliedCount": 3,
  "conflicts": [
    {
      "id": "B1B2C3D4-0000-0000-0000-000000000001",
      "entityType": "bullet",
      "serverVersion": {
        "id": "B1B2C3D4-0000-0000-0000-000000000001",
        "syncId": "S1B2C3D4-0000-0000-0000-000000000001",
        "entityType": "bullet",
        "data": "{\"content\":\"Device B version\"}",
        "updatedAt": "2026-03-09T09:30:00Z",
        "deviceId": "D9E8F7A6-0000-0000-0000-000000000002",
        "isDeleted": false,
        "encryptionEnabled": false
      },
      "clientVersion": {
        "id": "B1B2C3D4-0000-0000-0000-000000000001",
        "syncId": "S1B2C3D4-0000-0000-0000-000000000001",
        "entityType": "bullet",
        "data": "{\"content\":\"Device A version\"}",
        "updatedAt": "2026-03-09T08:45:00Z",
        "deviceId": "A1B2C3D4-E5F6-7890-ABCD-EF1234567890",
        "isDeleted": false,
        "encryptionEnabled": false
      },
      "resolution": "last_write_wins"
    }
  ],
  "syncIds": {
    "C1C2C3C4-0000-0000-0000-000000000003": "SC1C2C3-0000-0000-0000-000000000003"
  }
}
```

**Client behavior on conflicts**:

1. Apply `serverVersion.data` to local drift database (overwrite local record).
2. Insert a row into local `conflict_records` table with `clientVersion` as `local_snapshot`.
3. Mark bullet as synced in `pending_sync`; delete `pending_sync` row.
4. Update Riverpod `SyncStatusNotifier` with conflict count.

**Error responses**:

| Status | Code | Description |
| ------ | ---- | ----------- |
| 401 | `unauthorized` | Missing or invalid JWT |
| 400 | `invalid_payload` | Malformed changes array |
| 413 | `payload_too_large` | Exceeds 500 records; split into smaller batches |
| 429 | `rate_limited` | 30 req/min; retry after `Retry-After` |

---

## Authentication (AWS Cognito)

Handled directly by Cognito User Pools — no custom Lambda.

| Method | Cognito Endpoint | Description |
| ------ | ---------------- | ----------- |
| `POST` | `/oauth2/token` (grant_type=password) | Email + password sign-in |
| `POST` | `/oauth2/token` (grant_type=refresh_token) | Silent token refresh |
| `POST` | `/oauth2/token` (grant_type=authorization_code) | Sign in with Apple / Google PKCE |
| `GET` | `/oauth2/userInfo` | Fetch user profile |
| `POST` | `/oauth2/revoke` | Sign out / revoke refresh token |

**Token lifetimes**:

- Access token: 1 hour (passed as `Authorization: Bearer` to Lambda)
- Refresh token: 30 days (stored in `flutter_secure_storage`)
- ID token: 1 hour (not sent to Lambda)

---

## AWS Infrastructure (CDK Stack overview)

Defined in `backend/lib/antra-stack.ts` using AWS CDK v2 (TypeScript).
Go binaries are pre-built by `make build` before `cdk deploy`.

```typescript
import * as cdk from 'aws-cdk-lib';
import * as dynamodb from 'aws-cdk-lib/aws-dynamodb';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as apigateway from 'aws-cdk-lib/aws-apigateway';
import * as cognito from 'aws-cdk-lib/aws-cognito';

export class AntraStack extends cdk.Stack {
  constructor(scope: cdk.App, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // ── DynamoDB: single-table sync store ───────────────────────────────
    const syncTable = new dynamodb.Table(this, 'AntraSyncTable', {
      tableName: 'antra_sync',
      partitionKey: { name: 'pk', type: dynamodb.AttributeType.STRING },
      sortKey:      { name: 'sk', type: dynamodb.AttributeType.STRING },
      billingMode:  dynamodb.BillingMode.PAY_PER_REQUEST,
      timeToLiveAttribute: 'ttl',
      removalPolicy: cdk.RemovalPolicy.RETAIN,
    });
    syncTable.addGlobalSecondaryIndex({
      indexName: 'GSI1',
      partitionKey: { name: 'userId',    type: dynamodb.AttributeType.STRING },
      sortKey:      { name: 'updatedAt', type: dynamodb.AttributeType.STRING },
      projectionType: dynamodb.ProjectionType.ALL,
    });

    // ── Cognito User Pool ────────────────────────────────────────────────
    const userPool = new cognito.UserPool(this, 'AntraUserPool', { ... });
    const userPoolClient = userPool.addClient('AntraFlutterClient', { ... });

    // ── Lambda: pull_sync (Go, provided.al2023, ARM64) ───────────────────
    // Requires: make build → dist/pull_sync/bootstrap
    const pullFn = new lambda.Function(this, 'SyncPullFunction', {
      runtime:      lambda.Runtime.PROVIDED_AL2023,
      architecture: lambda.Architecture.ARM_64,
      handler:      'bootstrap',
      code:         lambda.Code.fromAsset('dist/pull_sync'),
      memorySize:   512,
      timeout:      cdk.Duration.seconds(10),
      environment:  { TABLE_NAME: syncTable.tableName, ... },
    });
    syncTable.grantReadData(pullFn);

    // ── Lambda: push_sync (Go, provided.al2023, ARM64) ───────────────────
    // Requires: make build → dist/push_sync/bootstrap
    const pushFn = new lambda.Function(this, 'SyncPushFunction', {
      runtime:      lambda.Runtime.PROVIDED_AL2023,
      architecture: lambda.Architecture.ARM_64,
      handler:      'bootstrap',
      code:         lambda.Code.fromAsset('dist/push_sync'),
      memorySize:   1024,
      timeout:      cdk.Duration.seconds(10),
      environment:  { TABLE_NAME: syncTable.tableName, ... },
    });
    syncTable.grantReadWriteData(pushFn);

    // ── API Gateway REST API with Cognito authorizer ─────────────────────
    const api = new apigateway.RestApi(this, 'AntraSyncApi', { ... });
    const authorizer = new apigateway.CognitoUserPoolsAuthorizer(
      this, 'CognitoAuthorizer', { cognitoUserPools: [userPool] }
    );
    const sync = api.root.addResource('sync');
    sync.addResource('pull').addMethod('POST',
      new apigateway.LambdaIntegration(pullFn), { authorizer, ... });
    sync.addResource('push').addMethod('POST',
      new apigateway.LambdaIntegration(pushFn), { authorizer, ... });

    new cdk.CfnOutput(this, 'ApiGatewayUrl',           { value: api.url });
    new cdk.CfnOutput(this, 'CognitoUserPoolId',       { value: userPool.userPoolId });
    new cdk.CfnOutput(this, 'CognitoUserPoolClientId', { value: userPoolClient.userPoolClientId });
  }
}
```

---

## Rate Limits

| Endpoint | Limit | Window |
| -------- | ----- | ------ |
| `POST /sync/pull` | 60 requests | per minute per user |
| `POST /sync/push` | 30 requests | per minute per user |
| Cognito auth endpoints | 5 requests | per minute per IP |

Clients MUST implement exponential backoff (1s, 2s, 4s, 8s, max 5 retries) on 429.
