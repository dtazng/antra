// Package pullhandler implements the sync pull Lambda handler.
// Extracted into an internal package so it can be tested without AWS credentials.
package pullhandler

import (
	"context"
	"encoding/json"
	"time"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb/types"

	internalauth "antra/backend/internal/auth"
	"antra/backend/internal/pagination"
	"antra/backend/internal/syncrecord"
)

// DynamoQueryAPI abstracts the DynamoDB Query call for testability.
type DynamoQueryAPI interface {
	Query(ctx context.Context, params *dynamodb.QueryInput, optFns ...func(*dynamodb.Options)) (*dynamodb.QueryOutput, error)
}

// Handler holds the dependencies for the pull_sync Lambda.
type Handler struct {
	Dynamo    DynamoQueryAPI
	TableName string
}

// SyncPullRequest is the expected JSON body for POST /sync/pull.
type SyncPullRequest struct {
	DeviceID          string   `json:"deviceId"`
	LastSyncTimestamp string   `json:"lastSyncTimestamp"`
	EntityTypes       []string `json:"entityTypes"`
	Cursor            string   `json:"cursor,omitempty"`
}

// SyncPullResponse is the JSON body returned by POST /sync/pull.
type SyncPullResponse struct {
	Records         []syncrecord.SyncRecord `json:"records"`
	ServerTimestamp string                  `json:"serverTimestamp"`
	HasMore         bool                    `json:"hasMore"`
	NextCursor      string                  `json:"nextCursor"`
}

func jsonResponse(statusCode int, body any) (events.APIGatewayProxyResponse, error) {
	data, _ := json.Marshal(body)
	return events.APIGatewayProxyResponse{
		StatusCode: statusCode,
		Headers:    map[string]string{"Content-Type": "application/json"},
		Body:       string(data),
	}, nil
}

// Handle is the Lambda handler function.
func (h *Handler) Handle(ctx context.Context, event events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	userID, err := internalauth.VerifyCognitoJWT(event.Headers["Authorization"])
	if err != nil {
		return jsonResponse(401, map[string]string{"error": "unauthorized"})
	}

	var req SyncPullRequest
	if err := json.Unmarshal([]byte(event.Body), &req); err != nil {
		return jsonResponse(400, map[string]string{"error": "invalid body"})
	}
	if req.LastSyncTimestamp == "" {
		req.LastSyncTimestamp = "1970-01-01T00:00:00Z"
	}

	exclusiveStartKey, err := pagination.DecodeCursor(req.Cursor)
	if err != nil {
		return jsonResponse(400, map[string]string{"error": "invalid cursor"})
	}

	result, err := h.Dynamo.Query(ctx, &dynamodb.QueryInput{
		TableName:              aws.String(h.TableName),
		IndexName:              aws.String("GSI1"),
		KeyConditionExpression: aws.String("userId = :uid AND updatedAt > :ts"),
		ExpressionAttributeValues: map[string]types.AttributeValue{
			":uid": &types.AttributeValueMemberS{Value: userID},
			":ts":  &types.AttributeValueMemberS{Value: req.LastSyncTimestamp},
		},
		Limit:             aws.Int32(500),
		ExclusiveStartKey: exclusiveStartKey,
	})
	if err != nil {
		return jsonResponse(500, map[string]string{"error": "query failed"})
	}

	records := make([]syncrecord.SyncRecord, 0, len(result.Items))
	for _, item := range result.Items {
		rec := itemToRecord(item)
		records = append(records, rec)
	}

	nextCursor := pagination.EncodeCursor(result.LastEvaluatedKey)
	return jsonResponse(200, SyncPullResponse{
		Records:         records,
		ServerTimestamp: time.Now().UTC().Format(time.RFC3339),
		HasMore:         result.LastEvaluatedKey != nil,
		NextCursor:      nextCursor,
	})
}

func itemToRecord(item map[string]types.AttributeValue) syncrecord.SyncRecord {
	rec := syncrecord.SyncRecord{}
	if v, ok := item["entityId"].(*types.AttributeValueMemberS); ok {
		rec.ID = v.Value
	}
	if v, ok := item["syncId"].(*types.AttributeValueMemberS); ok {
		s := v.Value
		rec.SyncID = &s
	}
	if v, ok := item["entityType"].(*types.AttributeValueMemberS); ok {
		rec.EntityType = v.Value
	}
	if v, ok := item["data"].(*types.AttributeValueMemberS); ok {
		rec.Data = v.Value
	}
	if v, ok := item["updatedAt"].(*types.AttributeValueMemberS); ok {
		rec.UpdatedAt = v.Value
	}
	if v, ok := item["deviceId"].(*types.AttributeValueMemberS); ok {
		rec.DeviceID = v.Value
	}
	if v, ok := item["isDeleted"].(*types.AttributeValueMemberBOOL); ok {
		rec.IsDeleted = v.Value
	}
	if v, ok := item["encryptionEnabled"].(*types.AttributeValueMemberBOOL); ok {
		rec.EncryptionEnabled = v.Value
	}
	return rec
}
