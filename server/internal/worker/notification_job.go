package worker

import (
	"context"
	"log/slog"

	"github.com/duongta/antra-backend/internal/db/sqlc"
	"github.com/duongta/antra-backend/internal/push"
)

// DispatchNotifications fetches pending notifications and sends them via Firebase.
func DispatchNotifications(ctx context.Context, q *sqlc.Queries, pushClient *push.Client) {
	slog.Info("notification_job: starting DispatchNotifications")

	notifications, err := q.GetPendingNotifications(ctx)
	if err != nil {
		slog.Error("notification_job: GetPendingNotifications failed", "error", err)
		return
	}

	if len(notifications) == 0 {
		slog.Info("notification_job: no pending notifications")
		return
	}

	slog.Info("notification_job: dispatching", "count", len(notifications))

	for _, notif := range notifications {
		// Fetch active device tokens for this user
		tokens, err := q.GetActiveDeviceTokens(ctx, notif.UserID)
		if err != nil || len(tokens) == 0 {
			// No active devices — mark as sent (nothing to do)
			_, _ = q.UpdateNotificationStatus(ctx, sqlc.UpdateNotificationStatusParams{
				ID:         notif.ID,
				Status:     "sent",
				RetryCount: notif.RetryCount,
			})
			continue
		}

		// Build token strings
		tokenStrs := make([]string, 0, len(tokens))
		for _, t := range tokens {
			tokenStrs = append(tokenStrs, t.Token)
		}

		sent, results := pushClient.SendToTokens(ctx, tokenStrs, notif.Title, notif.Body)

		// Record delivery results
		for i, r := range results {
			status := "delivered"
			var errMsg *string
			if !r.Success {
				status = "failed"
				errMsg = &r.Error
			}
			dtUUID := tokens[i].ID
			_, _ = q.CreateDeliveryRecord(ctx, sqlc.CreateDeliveryRecordParams{
				NotificationID: notif.ID,
				DeviceTokenID:  &dtUUID,
				Status:         status,
				ErrorMessage:   errMsg,
			})
		}

		// Update notification status
		newStatus := "sent"
		if sent == 0 {
			newStatus = "failed"
		}
		_, _ = q.UpdateNotificationStatus(ctx, sqlc.UpdateNotificationStatusParams{
			ID:         notif.ID,
			Status:     newStatus,
			RetryCount: notif.RetryCount + 1,
		})
	}

	slog.Info("notification_job: done", "dispatched", len(notifications))
}
