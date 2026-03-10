// Package pushhandler implements the sync push Lambda handler.
// Extracted into an internal package so it can be tested without AWS credentials.
package pushhandler

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb/types"
	"github.com/google/uuid"

	internalauth "antra/backend/internal/auth"
	"antra/backend/internal/conflicts"
	"antra/backend/internal/syncrecord"
)

// Handler holds the dependencies for the push_sync Lambda.
type Handler struct {
	Dynamo    conflicts.DynamoDBAPI
	TableName string
}

// SyncPushRequest is the expected JSON body for POST /sync/push.
type SyncPushRequest struct {
	DeviceID string                  `json:"deviceId"`
	Changes  []syncrecord.SyncRecord `json:"changes"`
}

// SyncPushResponse is the JSON body returned by POST /sync/push.
type SyncPushResponse struct {
	AppliedCount int                          `json:"appliedCount"`
	Conflicts    []syncrecord.ConflictInfo    `json:"conflicts"`
	SyncIDs      map[string]string            `json:"syncIds"`
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

	var req SyncPushRequest
	if err := json.Unmarshal([]byte(event.Body), &req); err != nil {
		return jsonResponse(400, map[string]string{"error": "invalid body"})
	}
	if len(req.Changes) > 500 {
		return jsonResponse(413, map[string]string{"error": "payload_too_large"})
	}

	resp := SyncPushResponse{
		Conflicts: make([]syncrecord.ConflictInfo, 0),
		SyncIDs:   make(map[string]string),
	}

	for i := range req.Changes {
		change := &req.Changes[i]
		pk := fmt.Sprintf("USER#%s", userID)
		sk := fmt.Sprintf("ENTITY#%s#%s", change.EntityType, change.ID)

		isNew := change.SyncID == nil
		if isNew {
			s := uuid.New().String()
			change.SyncID = &s
		}

		incoming := recordToItem(*change, userID)
		clientItem, serverItem, lwwErr := conflicts.ApplyLWW(ctx, h.Dynamo, h.TableName, pk, sk, incoming)
		if lwwErr != nil {
			continue // non-fatal; skip record
		}

		if clientItem == nil {
			// No conflict — applied.
			resp.AppliedCount++
			if isNew {
				resp.SyncIDs[change.ID] = *change.SyncID
			}
		} else {
			// Conflict — server version wins under LWW.
			resp.Conflicts = append(resp.Conflicts, syncrecord.ConflictInfo{
				ID:            change.ID,
				EntityType:    change.EntityType,
				ServerVersion: itemToRecord(serverItem),
				ClientVersion: itemToRecord(clientItem),
				Resolution:    "last_write_wins",
			})
		}
	}

	return jsonResponse(200, resp)
}

func recordToItem(rec syncrecord.SyncRecord, userID string) map[string]types.AttributeValue {
	item := map[string]types.AttributeValue{
		"userId":            &types.AttributeValueMemberS{Value: userID},
		"entityId":          &types.AttributeValueMemberS{Value: rec.ID},
		"entityType":        &types.AttributeValueMemberS{Value: rec.EntityType},
		"data":              &types.AttributeValueMemberS{Value: rec.Data},
		"updatedAt":         &types.AttributeValueMemberS{Value: rec.UpdatedAt},
		"deviceId":          &types.AttributeValueMemberS{Value: rec.DeviceID},
		"isDeleted":         &types.AttributeValueMemberBOOL{Value: rec.IsDeleted},
		"encryptionEnabled": &types.AttributeValueMemberBOOL{Value: rec.EncryptionEnabled},
	}
	if rec.SyncID != nil {
		item["syncId"] = &types.AttributeValueMemberS{Value: *rec.SyncID}
	}
	return item
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
