package tests

import (
	"context"
	"encoding/json"
	"testing"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb/types"
	"github.com/golang-jwt/jwt/v5"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	internalauth "antra/backend/internal/auth"
	"antra/backend/internal/pagination"
	"antra/backend/internal/pullhandler"
)

// ─── JWT test helper ──────────────────────────────────────────────────────────

// staticKeyProvider always validates any token and returns a fixed signing key.
type staticKeyProvider struct{}

func (s *staticKeyProvider) Keyfunc(_ *jwt.Token) (any, error) {
	return []byte("test-secret"), nil
}

// makeTestToken creates a HS256-signed JWT with the given sub claim.
func makeTestToken(sub string) string {
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"sub": sub,
		"iss": "test",
	})
	signed, _ := token.SignedString([]byte("test-secret"))
	return "Bearer " + signed
}

func init() {
	internalauth.SetKeyProvider(&staticKeyProvider{})
}

// ─── Mock DynamoDB for Query ──────────────────────────────────────────────────

type mockQueryClient struct {
	pages [][]map[string]types.AttributeValue // one slice per page
	call  int
}

func (m *mockQueryClient) Query(_ context.Context, _ *dynamodb.QueryInput, _ ...func(*dynamodb.Options)) (*dynamodb.QueryOutput, error) {
	defer func() { m.call++ }()
	if m.call >= len(m.pages) {
		return &dynamodb.QueryOutput{Items: nil}, nil
	}
	page := m.pages[m.call]
	var lastKey map[string]types.AttributeValue
	if m.call < len(m.pages)-1 {
		// Simulate more pages: return a fake LastEvaluatedKey.
		lastKey = map[string]types.AttributeValue{
			"pk": &types.AttributeValueMemberS{Value: "cursor"},
		}
	}
	return &dynamodb.QueryOutput{
		Items:            page,
		LastEvaluatedKey: lastKey,
	}, nil
}

func makeItem(entityID, updatedAt string) map[string]types.AttributeValue {
	return map[string]types.AttributeValue{
		"entityId":  &types.AttributeValueMemberS{Value: entityID},
		"syncId":    &types.AttributeValueMemberS{Value: "sync-" + entityID},
		"entityType": &types.AttributeValueMemberS{Value: "bullet"},
		"data":      &types.AttributeValueMemberS{Value: `{"content":"test"}`},
		"updatedAt": &types.AttributeValueMemberS{Value: updatedAt},
		"deviceId":  &types.AttributeValueMemberS{Value: "device-1"},
		"isDeleted": &types.AttributeValueMemberBOOL{Value: false},
		"encryptionEnabled": &types.AttributeValueMemberBOOL{Value: false},
	}
}

// ─── Tests ────────────────────────────────────────────────────────────────────

func TestPullSync_ReturnsOnlyRecordsAfterLastSyncTimestamp(t *testing.T) {
	// The mock returns 2 items (filtered by the handler's KeyConditionExpression).
	mock := &mockQueryClient{
		pages: [][]map[string]types.AttributeValue{
			{
				makeItem("bullet-1", "2026-03-09T10:00:00Z"),
				makeItem("bullet-2", "2026-03-09T11:00:00Z"),
			},
		},
	}
	h := &pullhandler.Handler{Dynamo: mock, TableName: "antra_sync"}

	body, _ := json.Marshal(map[string]any{
		"deviceId":          "device-1",
		"lastSyncTimestamp": "2026-03-09T09:00:00Z",
	})
	resp, err := h.Handle(context.Background(), events.APIGatewayProxyRequest{
		Headers: map[string]string{"Authorization": makeTestToken("user-1")},
		Body:    string(body),
	})

	require.NoError(t, err)
	assert.Equal(t, 200, resp.StatusCode)

	var parsed pullhandler.SyncPullResponse
	require.NoError(t, json.Unmarshal([]byte(resp.Body), &parsed))
	assert.Len(t, parsed.Records, 2)
	assert.False(t, parsed.HasMore)
	assert.Empty(t, parsed.NextCursor)
}

func TestPullSync_PaginationCursorThreadsThroughTwoPages(t *testing.T) {
	// Two pages: page 1 returns a cursor, page 2 is the final page.
	page1 := []map[string]types.AttributeValue{makeItem("bullet-a", "2026-03-09T10:00:00Z")}
	page2 := []map[string]types.AttributeValue{makeItem("bullet-b", "2026-03-09T11:00:00Z")}
	mock := &mockQueryClient{pages: [][]map[string]types.AttributeValue{page1, page2}}
	h := &pullhandler.Handler{Dynamo: mock, TableName: "antra_sync"}

	// ── Page 1 ────────────────────────────────────────────────────────────────
	body1, _ := json.Marshal(map[string]any{
		"deviceId":          "device-1",
		"lastSyncTimestamp": "1970-01-01T00:00:00Z",
	})
	resp1, _ := h.Handle(context.Background(), events.APIGatewayProxyRequest{
		Headers: map[string]string{"Authorization": makeTestToken("user-1")},
		Body:    string(body1),
	})
	var parsed1 pullhandler.SyncPullResponse
	require.NoError(t, json.Unmarshal([]byte(resp1.Body), &parsed1))
	assert.True(t, parsed1.HasMore)
	assert.NotEmpty(t, parsed1.NextCursor)
	assert.Len(t, parsed1.Records, 1)
	assert.Equal(t, "bullet-a", parsed1.Records[0].ID)

	// ── Page 2 (using cursor from page 1) ────────────────────────────────────
	body2, _ := json.Marshal(map[string]any{
		"deviceId":          "device-1",
		"lastSyncTimestamp": "1970-01-01T00:00:00Z",
		"cursor":            parsed1.NextCursor,
	})
	resp2, _ := h.Handle(context.Background(), events.APIGatewayProxyRequest{
		Headers: map[string]string{"Authorization": makeTestToken("user-1")},
		Body:    string(body2),
	})
	var parsed2 pullhandler.SyncPullResponse
	require.NoError(t, json.Unmarshal([]byte(resp2.Body), &parsed2))
	assert.False(t, parsed2.HasMore)
	assert.Len(t, parsed2.Records, 1)
	assert.Equal(t, "bullet-b", parsed2.Records[0].ID)
}

func TestPullSync_Returns401ForMissingAuth(t *testing.T) {
	h := &pullhandler.Handler{Dynamo: &mockQueryClient{}, TableName: "antra_sync"}

	body, _ := json.Marshal(map[string]any{"deviceId": "d", "lastSyncTimestamp": "1970-01-01T00:00:00Z"})
	resp, err := h.Handle(context.Background(), events.APIGatewayProxyRequest{
		Headers: map[string]string{},
		Body:    string(body),
	})

	require.NoError(t, err)
	assert.Equal(t, 401, resp.StatusCode)
}

func TestPullSync_Returns400ForInvalidCursor(t *testing.T) {
	h := &pullhandler.Handler{Dynamo: &mockQueryClient{}, TableName: "antra_sync"}

	body, _ := json.Marshal(map[string]any{
		"deviceId":          "d",
		"lastSyncTimestamp": "1970-01-01T00:00:00Z",
		"cursor":            "!!!not-base64!!!",
	})
	resp, err := h.Handle(context.Background(), events.APIGatewayProxyRequest{
		Headers: map[string]string{"Authorization": makeTestToken("user-1")},
		Body:    string(body),
	})

	require.NoError(t, err)
	assert.Equal(t, 400, resp.StatusCode)
}

func TestPaginationRoundTrip(t *testing.T) {
	original := map[string]types.AttributeValue{
		"pk": &types.AttributeValueMemberS{Value: "USER#abc"},
		"sk": &types.AttributeValueMemberS{Value: "ENTITY#bullet#xyz"},
	}
	encoded := pagination.EncodeCursor(original)
	assert.NotEmpty(t, encoded)

	decoded, err := pagination.DecodeCursor(encoded)
	require.NoError(t, err)

	pkOrig := original["pk"].(*types.AttributeValueMemberS).Value
	pkDecoded := decoded["pk"].(*types.AttributeValueMemberS).Value
	assert.Equal(t, pkOrig, pkDecoded)

	skOrig := original["sk"].(*types.AttributeValueMemberS).Value
	skDecoded := decoded["sk"].(*types.AttributeValueMemberS).Value
	assert.Equal(t, skOrig, skDecoded)
}

func TestPaginationEmptyCursor(t *testing.T) {
	assert.Empty(t, pagination.EncodeCursor(nil))

	decoded, err := pagination.DecodeCursor("")
	require.NoError(t, err)
	assert.Nil(t, decoded)
}

// Ensure mockQueryClient satisfies pullhandler.DynamoQueryAPI.
var _ pullhandler.DynamoQueryAPI = (*mockQueryClient)(nil)

// Ensure staticKeyProvider satisfies internalauth.KeyfuncProvider.
var _ internalauth.KeyfuncProvider = (*staticKeyProvider)(nil)

// Re-export for test assertions.
var _ = aws.String
