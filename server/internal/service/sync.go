package service

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/duongta/antra-backend/internal/db/sqlc"
	"github.com/google/uuid"
)

var ErrUnsupportedEntityType = errors.New("unsupported entity type")

// SyncChange represents a single change in a push payload.
type SyncChange struct {
	ID        uuid.UUID       `json:"id"`
	Operation string          `json:"operation"` // "upsert" | "delete"
	UpdatedAt time.Time       `json:"updated_at"`
	Data      json.RawMessage `json:"data"`
}

// PushResult holds the result of a sync push operation.
type PushResult struct {
	Accepted        int            `json:"accepted"`
	Conflicts       []SyncConflict `json:"conflicts"`
	ServerTimestamp time.Time      `json:"server_timestamp"`
}

// PullResult holds the result of a sync pull operation.
type PullResult struct {
	Records         []SyncRecord `json:"records"`
	NextCursor      *string      `json:"next_cursor"`
	ServerTimestamp time.Time    `json:"server_timestamp"`
}

// SyncRecord is a single record in a pull response.
type SyncRecord struct {
	ID        uuid.UUID       `json:"id"`
	UpdatedAt time.Time       `json:"updated_at"`
	DeletedAt *time.Time      `json:"deleted_at"`
	Data      json.RawMessage `json:"data"`
}

// SyncService orchestrates push/pull per entity type.
type SyncService struct {
	q         *sqlc.Queries
	personSvc *PersonService
	logSvc    *LogService
	followUpSvc *FollowUpService
}

func NewSyncService(q *sqlc.Queries) *SyncService {
	return &SyncService{
		q:           q,
		personSvc:   NewPersonService(q),
		logSvc:      NewLogService(q),
		followUpSvc: NewFollowUpService(q),
	}
}

// Push processes a batch of changes for a given entity type.
func (s *SyncService) Push(ctx context.Context, userID uuid.UUID, entityType string, changes []SyncChange, deviceID string) (*PushResult, error) {
	now := time.Now()
	result := &PushResult{
		Conflicts:       []SyncConflict{},
		ServerTimestamp: now,
	}

	for _, change := range changes {
		var accepted bool
		var conflict *SyncConflict
		var err error

		switch entityType {
		case "persons":
			accepted, conflict, err = s.applyPersonChange(ctx, userID, change)
		case "logs":
			accepted, conflict, err = s.applyLogChange(ctx, userID, change)
		case "follow_ups":
			accepted, conflict, err = s.applyFollowUpChange(ctx, userID, change)
		default:
			return nil, ErrUnsupportedEntityType
		}

		if err != nil {
			return nil, fmt.Errorf("applying change %s: %w", change.ID, err)
		}
		if accepted {
			result.Accepted++
		}
		if conflict != nil {
			result.Conflicts = append(result.Conflicts, *conflict)
		}
	}

	// Update sync metadata
	_, _ = s.q.UpsertSyncMetadata(ctx, sqlc.UpsertSyncMetadataParams{
		UserID:     userID,
		EntityType: entityType,
		DeviceID:   deviceID,
		LastSyncAt: now,
	})

	return result, nil
}

// Pull returns records for an entity type updated since a timestamp.
func (s *SyncService) Pull(ctx context.Context, userID uuid.UUID, entityType string, since time.Time, limit int32) (*PullResult, error) {
	now := time.Now()
	result := &PullResult{
		Records:         []SyncRecord{},
		NextCursor:      nil,
		ServerTimestamp: now,
	}

	switch entityType {
	case "persons":
		persons, err := s.personSvc.Pull(ctx, userID, since, limit)
		if err != nil {
			return nil, err
		}
		for _, p := range persons {
			var data json.RawMessage
			if p.DeletedAt == nil {
				dataMap := map[string]interface{}{
					"name":  p.Name,
					"notes": p.Notes,
					"last_interaction_date": formatDate(p.LastInteractionDate),
					"created_at": p.CreatedAt,
				}
				data, _ = json.Marshal(dataMap)
			}
			result.Records = append(result.Records, SyncRecord{
				ID:        p.ID,
				UpdatedAt: p.UpdatedAt,
				DeletedAt: p.DeletedAt,
				Data:      data,
			})
		}

	case "logs":
		logs, err := s.logSvc.Pull(ctx, userID, since, limit)
		if err != nil {
			return nil, err
		}
		for _, l := range logs {
			var data json.RawMessage
			if l.DeletedAt == nil {
				dataMap := map[string]interface{}{
					"content":   l.Content,
					"type":      l.Type,
					"status":    l.Status,
					"day_id":    l.DayID.Format("2006-01-02"),
					"device_id": l.DeviceID,
				}
				data, _ = json.Marshal(dataMap)
			}
			result.Records = append(result.Records, SyncRecord{
				ID:        l.ID,
				UpdatedAt: l.UpdatedAt,
				DeletedAt: l.DeletedAt,
				Data:      data,
			})
		}

	case "follow_ups":
		fus, err := s.followUpSvc.Pull(ctx, userID, since, limit)
		if err != nil {
			return nil, err
		}
		for _, fu := range fus {
			var data json.RawMessage
			if fu.DeletedAt == nil {
				dataMap := map[string]interface{}{
					"title":                    fu.Title,
					"due_date":                 fu.DueDate.Format("2006-01-02"),
					"status":                   fu.Status,
					"snoozed_until":            formatDate(fu.SnoozedUntil),
					"completed_at":             fu.CompletedAt,
					"is_recurring":             fu.IsRecurring,
					"recurrence_interval_days": fu.RecurrenceIntervalDays,
				}
				data, _ = json.Marshal(dataMap)
			}
			result.Records = append(result.Records, SyncRecord{
				ID:        fu.ID,
				UpdatedAt: fu.UpdatedAt,
				DeletedAt: fu.DeletedAt,
				Data:      data,
			})
		}

	default:
		return nil, ErrUnsupportedEntityType
	}

	return result, nil
}

func (s *SyncService) applyPersonChange(ctx context.Context, userID uuid.UUID, change SyncChange) (bool, *SyncConflict, error) {
	if change.Operation == "delete" {
		return s.personSvc.SyncDelete(ctx, userID, change.ID, change.UpdatedAt)
	}
	var data struct {
		Name      string  `json:"name"`
		Notes     *string `json:"notes"`
		CreatedAt time.Time `json:"created_at"`
	}
	if err := json.Unmarshal(change.Data, &data); err != nil {
		return false, nil, fmt.Errorf("invalid person data: %w", err)
	}
	if data.CreatedAt.IsZero() {
		data.CreatedAt = change.UpdatedAt
	}
	return s.personSvc.SyncUpsert(ctx, userID, change.ID, data.Name, data.Notes, change.UpdatedAt, data.CreatedAt)
}

func (s *SyncService) applyLogChange(ctx context.Context, userID uuid.UUID, change SyncChange) (bool, *SyncConflict, error) {
	if change.Operation == "delete" {
		return s.logSvc.SyncDelete(ctx, userID, change.ID, change.UpdatedAt)
	}
	var data struct {
		Content   string      `json:"content"`
		Type      string      `json:"type"`
		Status    string      `json:"status"`
		DayID     string      `json:"day_id"`
		DeviceID  string      `json:"device_id"`
		PersonIDs []uuid.UUID `json:"person_ids"`
		CreatedAt time.Time   `json:"created_at"`
	}
	if err := json.Unmarshal(change.Data, &data); err != nil {
		return false, nil, fmt.Errorf("invalid log data: %w", err)
	}
	dayID, _ := time.Parse("2006-01-02", data.DayID)
	if data.CreatedAt.IsZero() {
		data.CreatedAt = change.UpdatedAt
	}
	logType := data.Type
	if logType == "" {
		logType = "note"
	}
	status := data.Status
	if status == "" {
		status = "open"
	}
	return s.logSvc.SyncUpsert(ctx, userID, change.ID, data.Content, logType, status, dayID, data.DeviceID, data.PersonIDs, change.UpdatedAt, data.CreatedAt)
}

func (s *SyncService) applyFollowUpChange(ctx context.Context, userID uuid.UUID, change SyncChange) (bool, *SyncConflict, error) {
	if change.Operation == "delete" {
		return s.followUpSvc.SyncDelete(ctx, userID, change.ID, change.UpdatedAt)
	}
	var data struct {
		Title                  string     `json:"title"`
		DueDate                string     `json:"due_date"`
		Status                 string     `json:"status"`
		SnoozedUntil           *string    `json:"snoozed_until"`
		IsRecurring            bool       `json:"is_recurring"`
		RecurrenceIntervalDays *int32     `json:"recurrence_interval_days"`
		RecurrenceType         *string    `json:"recurrence_type"`
		LogID                  *uuid.UUID `json:"log_id"`
		PersonID               *uuid.UUID `json:"person_id"`
		CreatedAt              time.Time  `json:"created_at"`
	}
	if err := json.Unmarshal(change.Data, &data); err != nil {
		return false, nil, fmt.Errorf("invalid follow_up data: %w", err)
	}
	dueDate, _ := time.Parse("2006-01-02", data.DueDate)
	var snoozedUntil *time.Time
	if data.SnoozedUntil != nil {
		t, _ := time.Parse("2006-01-02", *data.SnoozedUntil)
		snoozedUntil = &t
	}
	status := data.Status
	if status == "" {
		status = "pending"
	}
	if data.CreatedAt.IsZero() {
		data.CreatedAt = change.UpdatedAt
	}
	return s.followUpSvc.SyncUpsert(ctx, userID, change.ID,
		data.LogID, data.PersonID, data.Title, dueDate, status, snoozedUntil,
		data.IsRecurring, data.RecurrenceIntervalDays, data.RecurrenceType,
		change.UpdatedAt, data.CreatedAt,
	)
}

func formatDate(t *time.Time) *string {
	if t == nil {
		return nil
	}
	s := t.Format("2006-01-02")
	return &s
}
