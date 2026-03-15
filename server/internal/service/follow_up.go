package service

import (
	"context"
	"time"

	"github.com/duongta/antra-backend/internal/db/sqlc"
	"github.com/google/uuid"
)

// FollowUpService handles follow-up CRUD and sync operations.
type FollowUpService struct {
	q *sqlc.Queries
}

func NewFollowUpService(q *sqlc.Queries) *FollowUpService {
	return &FollowUpService{q: q}
}

// SyncUpsert applies a push change with LWW conflict detection.
func (s *FollowUpService) SyncUpsert(
	ctx context.Context,
	userID, id uuid.UUID,
	logID, personID *uuid.UUID,
	title string,
	dueDate time.Time,
	status string,
	snoozedUntil *time.Time,
	isRecurring bool,
	recurrenceIntervalDays *int32,
	recurrenceType *string,
	clientUpdatedAt, createdAt time.Time,
) (bool, *SyncConflict, error) {
	existing, err := s.q.GetFollowUpByID(ctx, id, userID)
	if err == nil && existing.UpdatedAt.After(clientUpdatedAt) {
		return false, &SyncConflict{
			ID:     id,
			Reason: "server_newer",
			ServerRecord: map[string]interface{}{
				"id":         existing.ID,
				"updated_at": existing.UpdatedAt,
				"deleted_at": existing.DeletedAt,
				"data": map[string]interface{}{
					"title":    existing.Title,
					"due_date": existing.DueDate.Format("2006-01-02"),
					"status":   existing.Status,
				},
			},
		}, nil
	}

	_, err = s.q.UpsertFollowUp(ctx, sqlc.UpsertFollowUpParams{
		ID:                     id,
		UserID:                 userID,
		LogID:                  logID,
		PersonID:               personID,
		Title:                  title,
		DueDate:                dueDate,
		Status:                 status,
		SnoozedUntil:           snoozedUntil,
		IsRecurring:            isRecurring,
		RecurrenceIntervalDays: recurrenceIntervalDays,
		RecurrenceType:         recurrenceType,
		CreatedAt:              createdAt,
	})
	if err != nil {
		return false, nil, err
	}
	return true, nil, nil
}

// SyncDelete soft-deletes a follow-up via push with LWW conflict detection.
func (s *FollowUpService) SyncDelete(ctx context.Context, userID, id uuid.UUID, clientUpdatedAt time.Time) (bool, *SyncConflict, error) {
	existing, err := s.q.GetFollowUpByID(ctx, id, userID)
	if err != nil {
		return true, nil, nil
	}
	if existing.UpdatedAt.After(clientUpdatedAt) {
		return false, &SyncConflict{
			ID:     id,
			Reason: "server_newer",
			ServerRecord: map[string]interface{}{
				"id":         existing.ID,
				"updated_at": existing.UpdatedAt,
				"deleted_at": existing.DeletedAt,
				"data":       nil,
			},
		}, nil
	}
	_, err = s.q.SoftDeleteFollowUp(ctx, id, userID)
	return err == nil, nil, err
}

// Pull returns follow-ups updated since the given timestamp.
func (s *FollowUpService) Pull(ctx context.Context, userID uuid.UUID, since time.Time, limit int32) ([]sqlc.FollowUp, error) {
	return s.q.GetFollowUpsByUpdatedSince(ctx, sqlc.GetFollowUpsByUpdatedSinceParams{
		UserID:    userID,
		UpdatedAt: since,
		Limit:     limit,
	})
}

// List returns paginated follow-ups, optionally filtered by status.
func (s *FollowUpService) List(ctx context.Context, userID uuid.UUID, status string, limit, offset int32) ([]sqlc.FollowUp, error) {
	return s.q.ListFollowUps(ctx, sqlc.ListFollowUpsParams{
		UserID: userID,
		Status: status,
		Limit:  limit,
		Offset: offset,
	})
}

// Get returns a single follow-up by ID.
func (s *FollowUpService) Get(ctx context.Context, userID, id uuid.UUID) (sqlc.FollowUp, error) {
	fu, err := s.q.GetFollowUpByID(ctx, id, userID)
	if err != nil {
		return sqlc.FollowUp{}, ErrNotFound
	}
	if fu.DeletedAt != nil {
		return sqlc.FollowUp{}, ErrNotFound
	}
	return fu, nil
}

// Create inserts a new follow-up.
func (s *FollowUpService) Create(ctx context.Context, userID, id uuid.UUID, logID, personID *uuid.UUID, title string, dueDate time.Time, isRecurring bool, recurrenceIntervalDays *int32, recurrenceType *string) (sqlc.FollowUp, error) {
	return s.q.CreateFollowUp(ctx, sqlc.CreateFollowUpParams{
		ID:                     id,
		UserID:                 userID,
		LogID:                  logID,
		PersonID:               personID,
		Title:                  title,
		DueDate:                dueDate,
		IsRecurring:            isRecurring,
		RecurrenceIntervalDays: recurrenceIntervalDays,
		RecurrenceType:         recurrenceType,
	})
}

// Update patches a follow-up's mutable fields (status transitions, snooze, etc.).
func (s *FollowUpService) Update(ctx context.Context, userID, id uuid.UUID, title *string, dueDate, snoozedUntil, completedAt *time.Time, status *string) (sqlc.FollowUp, error) {
	return s.q.UpdateFollowUp(ctx, sqlc.UpdateFollowUpParams{
		ID:           id,
		UserID:       userID,
		Title:        title,
		DueDate:      dueDate,
		Status:       status,
		SnoozedUntil: snoozedUntil,
		CompletedAt:  completedAt,
	})
}

// Delete soft-deletes a follow-up.
func (s *FollowUpService) Delete(ctx context.Context, userID, id uuid.UUID) error {
	_, err := s.q.SoftDeleteFollowUp(ctx, id, userID)
	return err
}
