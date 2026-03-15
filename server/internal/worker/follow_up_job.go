package worker

import (
	"context"
	"database/sql"
	"fmt"
	"log/slog"

	"github.com/duongta/antra-backend/internal/db/sqlc"
	"github.com/google/uuid"
)

// CheckDueFollowUps marks pending/snoozed follow-ups as due and creates notifications.
func CheckDueFollowUps(ctx context.Context, q *sqlc.Queries) {
	slog.Info("follow_up_job: starting CheckDueFollowUps")

	dueFollowUps, err := q.MarkFollowUpsDue(ctx)
	if err != nil {
		slog.Error("follow_up_job: MarkFollowUpsDue failed", "error", err)
		return
	}

	slog.Info("follow_up_job: marked follow-ups as due", "count", len(dueFollowUps))

	for _, fu := range dueFollowUps {
		// Get user settings to check notifications_enabled
		settings, err := q.GetOrCreateUserSettings(ctx, fu.UserID)
		if err != nil || !settings.NotificationsEnabled {
			continue
		}

		title := "Follow-up due"
		body := fmt.Sprintf("Follow up: %s", fu.Title)

		_, err = q.CreateNotification(ctx, sqlc.CreateNotificationParams{
			UserID:     fu.UserID,
			FollowUpID: uuid.NullUUID{UUID: fu.ID, Valid: true},
			Title:      title,
			Body:       body,
		})
		if err != nil {
			slog.Error("follow_up_job: CreateNotification failed",
				"follow_up_id", fu.ID, "error", err)
		}

		// Handle recurring follow-ups
		if fu.IsRecurring && fu.RecurrenceIntervalDays.Valid {
			nextDueDate := fu.DueDate.AddDate(0, 0, int(fu.RecurrenceIntervalDays.Int32))
			_, err = q.CreateFollowUp(ctx, sqlc.CreateFollowUpParams{
				ID:                     newUUID(),
				UserID:                 fu.UserID,
				LogID:                  fu.LogID,
				PersonID:               fu.PersonID,
				Title:                  fu.Title,
				DueDate:                nextDueDate,
				IsRecurring:            fu.IsRecurring,
				RecurrenceIntervalDays: sql.NullInt32{Int32: fu.RecurrenceIntervalDays.Int32, Valid: fu.RecurrenceIntervalDays.Valid},
				RecurrenceType:         sql.NullString{String: fu.RecurrenceType.String, Valid: fu.RecurrenceType.Valid},
			})
			if err != nil {
				slog.Error("follow_up_job: CreateFollowUp (recurring) failed",
					"follow_up_id", fu.ID, "error", err)
			}
		}
	}

	slog.Info("follow_up_job: done", "notifications_created", len(dueFollowUps))
}
