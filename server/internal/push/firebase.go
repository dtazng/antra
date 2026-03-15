package push

import (
	"context"
	"log/slog"

	firebase "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/messaging"
	"google.golang.org/api/option"
)

// DeliveryResult holds the result of a single token delivery attempt.
type DeliveryResult struct {
	Token   string
	Success bool
	Error   string
}

// Client wraps firebase-admin-go for FCM push delivery.
type Client struct {
	messaging *messaging.Client
}

// NewFirebaseClient initializes the Firebase messaging client.
// If credentialsJSON is empty, returns a no-op client (graceful degradation).
func NewFirebaseClient(ctx context.Context, credentialsJSON string) (*Client, error) {
	if credentialsJSON == "" {
		slog.Warn("FIREBASE_CREDENTIALS_JSON not set — push notifications disabled")
		return &Client{}, nil
	}

	app, err := firebase.NewApp(ctx, nil, option.WithCredentialsJSON([]byte(credentialsJSON)))
	if err != nil {
		return nil, err
	}
	client, err := app.Messaging(ctx)
	if err != nil {
		return nil, err
	}
	return &Client{messaging: client}, nil
}

// SendToTokens sends a notification to multiple device tokens.
// Returns the count of successful deliveries and per-token results.
func (c *Client) SendToTokens(ctx context.Context, tokens []string, title, body string) (int, []DeliveryResult) {
	if c.messaging == nil || len(tokens) == 0 {
		return 0, nil
	}

	messages := make([]*messaging.Message, 0, len(tokens))
	for _, token := range tokens {
		messages = append(messages, &messaging.Message{
			Token: token,
			Notification: &messaging.Notification{
				Title: title,
				Body:  body,
			},
		})
	}

	resp, err := c.messaging.SendEach(ctx, messages)
	if err != nil {
		slog.Error("firebase SendEach failed", "error", err)
		return 0, nil
	}

	results := make([]DeliveryResult, 0, len(tokens))
	sent := 0
	for i, r := range resp.Responses {
		dr := DeliveryResult{Token: tokens[i], Success: r.Success}
		if r.Error != nil {
			dr.Error = r.Error.Error()
		} else {
			sent++
		}
		results = append(results, dr)
	}
	return sent, results
}
