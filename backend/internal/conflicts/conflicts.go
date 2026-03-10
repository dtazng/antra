// Package conflicts implements Last-Write-Wins conflict resolution using
// DynamoDB conditional expressions.
package conflicts

import (
	"context"
	"errors"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb/types"
)

// DynamoDBAPI abstracts the DynamoDB operations required by ApplyLWW.
// Defining it as an interface enables unit tests with mock implementations
// — no AWS credentials or network access needed.
type DynamoDBAPI interface {
	PutItem(ctx context.Context, params *dynamodb.PutItemInput, optFns ...func(*dynamodb.Options)) (*dynamodb.PutItemOutput, error)
	GetItem(ctx context.Context, params *dynamodb.GetItemInput, optFns ...func(*dynamodb.Options)) (*dynamodb.GetItemOutput, error)
}

// ApplyLWW writes item only if the incoming updatedAt is newer than the stored value.
//
// Returns (nil, nil, nil) when the write succeeds (no conflict).
// Returns (clientItem, serverItem, nil) when the server version wins (conflict).
// Returns (nil, nil, err) on unexpected DynamoDB errors.
func ApplyLWW(
	ctx context.Context,
	client DynamoDBAPI,
	tableName, pk, sk string,
	incoming map[string]types.AttributeValue,
) (clientItem, serverItem map[string]types.AttributeValue, err error) {
	// Copy incoming to avoid mutating the caller's map, then set keys.
	item := make(map[string]types.AttributeValue, len(incoming)+2)
	for k, v := range incoming {
		item[k] = v
	}
	item["pk"] = &types.AttributeValueMemberS{Value: pk}
	item["sk"] = &types.AttributeValueMemberS{Value: sk}

	_, err = client.PutItem(ctx, &dynamodb.PutItemInput{
		TableName: aws.String(tableName),
		Item:      item,
		// Write only if no existing record OR if incoming is strictly newer.
		ConditionExpression: aws.String(
			"attribute_not_exists(updatedAt) OR updatedAt < :ts",
		),
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

	// Conflict: the server record has an equal or newer updatedAt.
	// Fetch the winning server record to return to the client.
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
	return item, out.Item, nil
}
