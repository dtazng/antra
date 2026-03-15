package service

import (
	"context"
	"time"

	"github.com/duongta/antra-backend/internal/db/sqlc"
	"github.com/google/uuid"
)

// LogService handles log CRUD and sync operations.
type LogService struct {
	q *sqlc.Queries
}

func NewLogService(q *sqlc.Queries) *LogService {
	return &LogService{q: q}
}

// SyncUpsert applies a single push change with LWW conflict detection.
func (s *LogService) SyncUpsert(
	ctx context.Context,
	userID, id uuid.UUID,
	content, logType, status string,
	dayID time.Time,
	deviceID string,
	personIDs []uuid.UUID,
	clientUpdatedAt, createdAt time.Time,
) (bool, *SyncConflict, error) {
	existing, err := s.q.GetLogByID(ctx, id, userID)
	if err == nil && existing.UpdatedAt.After(clientUpdatedAt) {
		return false, &SyncConflict{
			ID:     id,
			Reason: "server_newer",
			ServerRecord: map[string]interface{}{
				"id":         existing.ID,
				"updated_at": existing.UpdatedAt,
				"deleted_at": existing.DeletedAt,
				"data": map[string]interface{}{
					"content":   existing.Content,
					"type":      existing.Type,
					"status":    existing.Status,
					"day_id":    existing.DayID.Format("2006-01-02"),
					"device_id": existing.DeviceID,
				},
			},
		}, nil
	}

	log, err := s.q.UpsertLog(ctx, sqlc.UpsertLogParams{
		ID:        id,
		UserID:    userID,
		Content:   content,
		Type:      logType,
		Status:    status,
		DayID:     dayID,
		DeviceID:  deviceID,
		CreatedAt: createdAt,
	})
	if err != nil {
		return false, nil, err
	}

	// Replace person links atomically
	if len(personIDs) > 0 {
		if err := s.q.ReplaceLogPersonLinks(ctx, sqlc.ReplaceLogPersonLinksParams{
			LogID:     log.ID,
			PersonIDs: personIDs,
			UserID:    userID,
		}); err != nil {
			return false, nil, err
		}
	}

	return true, nil, nil
}

// SyncDelete soft-deletes a log via push with LWW conflict detection.
func (s *LogService) SyncDelete(ctx context.Context, userID, id uuid.UUID, clientUpdatedAt time.Time) (bool, *SyncConflict, error) {
	existing, err := s.q.GetLogByID(ctx, id, userID)
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
	_, err = s.q.SoftDeleteLog(ctx, id, userID)
	return err == nil, nil, err
}

// Pull returns logs updated since the given timestamp.
func (s *LogService) Pull(ctx context.Context, userID uuid.UUID, since time.Time, limit int32) ([]sqlc.Log, error) {
	return s.q.GetLogsByUpdatedSince(ctx, sqlc.GetLogsByUpdatedSinceParams{
		UserID:    userID,
		UpdatedAt: since,
		Limit:     limit,
	})
}

// List returns paginated active logs sorted by day_id DESC.
func (s *LogService) List(ctx context.Context, userID uuid.UUID, limit, offset int32) ([]sqlc.Log, error) {
	return s.q.ListLogs(ctx, sqlc.ListLogsParams{
		UserID: userID,
		Limit:  limit,
		Offset: offset,
	})
}

// Get returns a single log by ID.
func (s *LogService) Get(ctx context.Context, userID, id uuid.UUID) (sqlc.Log, error) {
	l, err := s.q.GetLogByID(ctx, id, userID)
	if err != nil {
		return sqlc.Log{}, ErrNotFound
	}
	if l.DeletedAt != nil {
		return sqlc.Log{}, ErrNotFound
	}
	return l, nil
}

// Create inserts a new log with optional person links.
func (s *LogService) Create(ctx context.Context, userID, id uuid.UUID, content, logType, status string, dayID time.Time, deviceID string, personIDs []uuid.UUID) (sqlc.Log, error) {
	log, err := s.q.UpsertLog(ctx, sqlc.UpsertLogParams{
		ID:        id,
		UserID:    userID,
		Content:   content,
		Type:      logType,
		Status:    status,
		DayID:     dayID,
		DeviceID:  deviceID,
		CreatedAt: time.Now(),
	})
	if err != nil {
		return sqlc.Log{}, err
	}
	if len(personIDs) > 0 {
		_ = s.q.ReplaceLogPersonLinks(ctx, sqlc.ReplaceLogPersonLinksParams{
			LogID:     log.ID,
			PersonIDs: personIDs,
			UserID:    userID,
		})
	}
	return log, nil
}

// Update patches a log's mutable fields.
func (s *LogService) Update(ctx context.Context, userID, id uuid.UUID, content, logType, status *string, personIDs []uuid.UUID) (sqlc.Log, error) {
	log, err := s.q.UpdateLog(ctx, sqlc.UpdateLogParams{
		ID:      id,
		UserID:  userID,
		Content: content,
		Type:    logType,
		Status:  status,
	})
	if err != nil {
		return sqlc.Log{}, err
	}
	if personIDs != nil {
		_ = s.q.ReplaceLogPersonLinks(ctx, sqlc.ReplaceLogPersonLinksParams{
			LogID:     log.ID,
			PersonIDs: personIDs,
			UserID:    userID,
		})
	}
	return log, nil
}

// Delete soft-deletes a log.
func (s *LogService) Delete(ctx context.Context, userID, id uuid.UUID) error {
	_, err := s.q.SoftDeleteLog(ctx, id, userID)
	return err
}
