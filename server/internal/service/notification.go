package service

import (
	"context"

	"github.com/duongta/antra-backend/internal/db/sqlc"
	"github.com/google/uuid"
)

// NotificationService handles notification inbox operations.
type NotificationService struct {
	q *sqlc.Queries
}

func NewNotificationService(q *sqlc.Queries) *NotificationService {
	return &NotificationService{q: q}
}

// List returns paginated notifications for a user, newest first.
func (s *NotificationService) List(ctx context.Context, userID uuid.UUID, limit, offset int32) ([]sqlc.Notification, error) {
	return s.q.GetNotificationsByUser(ctx, sqlc.GetNotificationsByUserParams{
		UserID: userID,
		Limit:  limit,
		Offset: offset,
	})
}

// Dismiss marks a notification as dismissed.
func (s *NotificationService) Dismiss(ctx context.Context, userID, id uuid.UUID) (sqlc.Notification, error) {
	n, err := s.q.DismissNotification(ctx, id, userID)
	if err != nil {
		return sqlc.Notification{}, ErrNotFound
	}
	return n, nil
}
