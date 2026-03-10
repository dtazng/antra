package tests

import (
	"context"
	"encoding/json"
	"testing"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb/types"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"antra/backend/internal/pushhandler"
	"antra/backend/internal/syncrecord"
)

// ─── Mock DynamoDB for PutItem / GetItem ─────────────────────────────────────

// mockDynamo implements conflicts.DynamoDBAPI.
// putErr controls whether PutItem returns a ConditionalCheckFailedException.
type mockDynamo struct {
	putErr     error
	serverItem map[string]types.AttributeValue
}

func (m *mockDynamo) PutItem(_ context.Context, _ *dynamodb.PutItemInput, _ ...func(*dynamodb.Options)) (*dynamodb.PutItemOutput, error) {
	return &dynamodb.PutItemOutput{}, m.putErr
}

func (m *mockDynamo) GetItem(_ context.Context, _ *dynamodb.GetItemInput, _ ...func(*dynamodb.Options)) (*dynamodb.GetItemOutput, error) {
	return &dynamodb.GetItemOutput{Item: m.serverItem}, nil
}

func makeConditionalCheckErr() error {
	return &types.ConditionalCheckFailedException{
		Message: aws.String("conditional check failed"),
	}
}

func makeChange(id, updatedAt string, syncID *string) syncrecord.SyncRecord {
	return syncrecord.SyncRecord{
		ID:         id,
		SyncID:     syncID,
		EntityType: "bullet",
		Data:       `{"content":"test"}`,
		UpdatedAt:  updatedAt,
		DeviceID:   "device-1",
	}
}

func invokeHandler(t *testing.T, h *pushhandler.Handler, changes []syncrecord.SyncRecord) pushhandler.SyncPushResponse {
	t.Helper()
	body, _ := json.Marshal(pushhandler.SyncPushRequest{
		DeviceID: "device-1",
		Changes:  changes,
	})
	resp, err := h.Handle(context.Background(), events.APIGatewayProxyRequest{
		Headers: map[string]string{"Authorization": makeTestToken("user-1")},
		Body:    string(body),
	})
	require.NoError(t, err)
	require.Equal(t, 200, resp.StatusCode)

	var parsed pushhandler.SyncPushResponse
	require.NoError(t, json.Unmarshal([]byte(resp.Body), &parsed))
	return parsed
}

// ─── Tests ────────────────────────────────────────────────────────────────────

func TestPushSync_NewRecordCreatedAndSyncIDAssigned(t *testing.T) {
	h := &pushhandler.Handler{
		Dynamo:    &mockDynamo{putErr: nil}, // PutItem succeeds
		TableName: "antra_sync",
	}

	parsed := invokeHandler(t, h, []syncrecord.SyncRecord{
		makeChange("bullet-new-1", "2026-03-09T10:00:00Z", nil), // nil syncId = new record
	})

	assert.Equal(t, 1, parsed.AppliedCount)
	assert.Empty(t, parsed.Conflicts)
	syncID, ok := parsed.SyncIDs["bullet-new-1"]
	assert.True(t, ok, "syncId should be assigned for new record")
	assert.NotEmpty(t, syncID)
}

func TestPushSync_ConflictWhenServerRecordIsNewer(t *testing.T) {
	serverTS := "2026-03-09T12:00:00Z"
	clientTS := "2026-03-09T10:00:00Z"
	entityID := "bullet-conflict-1"

	serverItem := map[string]types.AttributeValue{
		"entityId":  &types.AttributeValueMemberS{Value: entityID},
		"syncId":    &types.AttributeValueMemberS{Value: "server-sync-id"},
		"entityType": &types.AttributeValueMemberS{Value: "bullet"},
		"data":      &types.AttributeValueMemberS{Value: `{"content":"Server version"}`},
		"updatedAt": &types.AttributeValueMemberS{Value: serverTS},
		"deviceId":  &types.AttributeValueMemberS{Value: "device-2"},
		"isDeleted": &types.AttributeValueMemberBOOL{Value: false},
		"encryptionEnabled": &types.AttributeValueMemberBOOL{Value: false},
	}

	h := &pushhandler.Handler{
		Dynamo: &mockDynamo{
			putErr:     makeConditionalCheckErr(), // server is newer → conflict
			serverItem: serverItem,
		},
		TableName: "antra_sync",
	}

	existingSyncID := "existing-sync-id"
	parsed := invokeHandler(t, h, []syncrecord.SyncRecord{
		makeChange(entityID, clientTS, &existingSyncID),
	})

	assert.Equal(t, 0, parsed.AppliedCount)
	require.Len(t, parsed.Conflicts, 1)

	conflict := parsed.Conflicts[0]
	assert.Equal(t, entityID, conflict.ID)
	assert.Equal(t, "last_write_wins", conflict.Resolution)
	assert.Equal(t, serverTS, conflict.ServerVersion.UpdatedAt)
	assert.Equal(t, clientTS, conflict.ClientVersion.UpdatedAt)
}

func TestPushSync_Returns401ForMissingAuth(t *testing.T) {
	h := &pushhandler.Handler{Dynamo: &mockDynamo{}, TableName: "antra_sync"}

	body, _ := json.Marshal(pushhandler.SyncPushRequest{DeviceID: "d", Changes: nil})
	resp, err := h.Handle(context.Background(), events.APIGatewayProxyRequest{
		Headers: map[string]string{},
		Body:    string(body),
	})

	require.NoError(t, err)
	assert.Equal(t, 401, resp.StatusCode)
}

func TestPushSync_Returns413ForOversizedBatch(t *testing.T) {
	h := &pushhandler.Handler{Dynamo: &mockDynamo{}, TableName: "antra_sync"}

	changes := make([]syncrecord.SyncRecord, 501)
	for i := range changes {
		changes[i] = makeChange("id", "2026-01-01T00:00:00Z", nil)
	}
	body, _ := json.Marshal(pushhandler.SyncPushRequest{DeviceID: "d", Changes: changes})
	resp, err := h.Handle(context.Background(), events.APIGatewayProxyRequest{
		Headers: map[string]string{"Authorization": makeTestToken("user-1")},
		Body:    string(body),
	})

	require.NoError(t, err)
	assert.Equal(t, 413, resp.StatusCode)
}

func TestPushSync_BatchAppliesMultipleRecords(t *testing.T) {
	h := &pushhandler.Handler{
		Dynamo:    &mockDynamo{putErr: nil},
		TableName: "antra_sync",
	}

	parsed := invokeHandler(t, h, []syncrecord.SyncRecord{
		makeChange("b1", "2026-03-09T10:00:00Z", nil),
		makeChange("b2", "2026-03-09T10:01:00Z", nil),
		makeChange("b3", "2026-03-09T10:02:00Z", nil),
	})

	assert.Equal(t, 3, parsed.AppliedCount)
	assert.Empty(t, parsed.Conflicts)
	assert.Len(t, parsed.SyncIDs, 3)
}

// Ensure mockDynamo satisfies conflicts.DynamoDBAPI at compile time.
// (Imported via pushhandler which embeds conflicts.DynamoDBAPI.)
var _ pushhandler.SyncPushResponse = pushhandler.SyncPushResponse{}
