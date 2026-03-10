// Package pagination encodes and decodes DynamoDB LastEvaluatedKey values
// as opaque URL-safe base64 strings for use as HTTP pagination cursors.
package pagination

import (
	"encoding/base64"
	"encoding/json"
	"fmt"

	"github.com/aws/aws-sdk-go-v2/service/dynamodb/types"
)

// EncodeCursor serialises a DynamoDB LastEvaluatedKey map to an opaque
// URL-safe base64 cursor string. Returns empty string for a nil/empty key.
func EncodeCursor(lastEvaluatedKey map[string]types.AttributeValue) string {
	if len(lastEvaluatedKey) == 0 {
		return ""
	}
	// Convert AttributeValue map to a JSON-serialisable representation.
	raw := make(map[string]map[string]string, len(lastEvaluatedKey))
	for k, v := range lastEvaluatedKey {
		switch av := v.(type) {
		case *types.AttributeValueMemberS:
			raw[k] = map[string]string{"S": av.Value}
		case *types.AttributeValueMemberN:
			raw[k] = map[string]string{"N": av.Value}
		case *types.AttributeValueMemberB:
			raw[k] = map[string]string{"B": base64.StdEncoding.EncodeToString(av.Value)}
		}
	}
	data, _ := json.Marshal(raw)
	return base64.URLEncoding.EncodeToString(data)
}

// DecodeCursor deserialises an opaque cursor string back to a DynamoDB
// ExclusiveStartKey map. Returns (nil, nil) for an empty cursor.
func DecodeCursor(cursor string) (map[string]types.AttributeValue, error) {
	if cursor == "" {
		return nil, nil
	}
	data, err := base64.URLEncoding.DecodeString(cursor)
	if err != nil {
		return nil, fmt.Errorf("invalid cursor encoding: %w", err)
	}
	var raw map[string]map[string]string
	if err := json.Unmarshal(data, &raw); err != nil {
		return nil, fmt.Errorf("invalid cursor format: %w", err)
	}
	result := make(map[string]types.AttributeValue, len(raw))
	for k, m := range raw {
		switch {
		case m["S"] != "":
			result[k] = &types.AttributeValueMemberS{Value: m["S"]}
		case m["N"] != "":
			result[k] = &types.AttributeValueMemberN{Value: m["N"]}
		case m["B"] != "":
			decoded, err := base64.StdEncoding.DecodeString(m["B"])
			if err != nil {
				return nil, fmt.Errorf("invalid binary attribute in cursor: %w", err)
			}
			result[k] = &types.AttributeValueMemberB{Value: decoded}
		}
	}
	return result, nil
}
