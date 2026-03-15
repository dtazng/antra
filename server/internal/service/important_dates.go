package service

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"strings"

	"github.com/duongta/antra-backend/internal/db/sqlc"
	"github.com/google/uuid"
)

// ImportantDatesService handles CRUD operations for person important dates.
type ImportantDatesService struct {
	q *sqlc.Queries
}

func NewImportantDatesService(q *sqlc.Queries) *ImportantDatesService {
	return &ImportantDatesService{q: q}
}

// ImportantDateInput carries validated fields for create/update operations.
type ImportantDateInput struct {
	Label              string
	IsBirthday         bool
	Month              int32
	Day                int32
	Year               *int32
	ReminderOffsetDays *int32
	ReminderRecurrence *string
	Note               *string
}

// Validate checks field constraints and returns ErrInvalidInput on failure.
func (in *ImportantDateInput) Validate() error {
	if strings.TrimSpace(in.Label) == "" || len(in.Label) > 100 {
		return fmt.Errorf("%w: label must be 1–100 characters", ErrInvalidInput)
	}
	if in.Month < 1 || in.Month > 12 {
		return fmt.Errorf("%w: month must be 1–12", ErrInvalidInput)
	}
	if in.Day < 1 || in.Day > 31 {
		return fmt.Errorf("%w: day must be 1–31", ErrInvalidInput)
	}
	if in.ReminderOffsetDays != nil && in.ReminderRecurrence == nil {
		return fmt.Errorf("%w: reminder_recurrence is required when reminder_offset_days is set", ErrInvalidInput)
	}
	if in.ReminderRecurrence != nil {
		r := *in.ReminderRecurrence
		if r != "yearly" && r != "once" {
			return fmt.Errorf("%w: reminder_recurrence must be 'yearly' or 'once'", ErrInvalidInput)
		}
	}
	if in.Note != nil && len(*in.Note) > 500 {
		return fmt.Errorf("%w: note must be at most 500 characters", ErrInvalidInput)
	}
	return nil
}

// Create creates a new important date. Returns ErrConflict if the ID already exists.
func (s *ImportantDatesService) Create(
	ctx context.Context,
	id uuid.UUID,
	userID uuid.UUID,
	personID uuid.UUID,
	in ImportantDateInput,
) (sqlc.PersonImportantDate, error) {
	if err := in.Validate(); err != nil {
		return sqlc.PersonImportantDate{}, err
	}

	// Check if isBirthday is being set and one already exists for this person.
	if in.IsBirthday {
		existing, err := s.q.ListImportantDatesByPerson(ctx, sqlc.ListImportantDatesByPersonParams{
			PersonID: personID,
			UserID:   userID,
		})
		if err == nil {
			for _, e := range existing {
				if e.IsBirthday {
					return sqlc.PersonImportantDate{}, fmt.Errorf("%w: a birthday already exists for this person", ErrConflict)
				}
			}
		}
	}

	result, err := s.q.CreateImportantDate(ctx, sqlc.CreateImportantDateParams{
		ID:                 id,
		UserID:             userID,
		PersonID:           personID,
		Label:              in.Label,
		IsBirthday:         in.IsBirthday,
		Month:              in.Month,
		Day:                in.Day,
		Year:               nullInt32(in.Year),
		ReminderOffsetDays: nullInt32(in.ReminderOffsetDays),
		ReminderRecurrence: nullString(in.ReminderRecurrence),
		Note:               nullString(in.Note),
	})
	if err != nil {
		if strings.Contains(err.Error(), "duplicate key") ||
			strings.Contains(err.Error(), "unique constraint") {
			return sqlc.PersonImportantDate{}, ErrConflict
		}
		return sqlc.PersonImportantDate{}, err
	}
	return result, nil
}

// List returns all active important dates for a person.
func (s *ImportantDatesService) List(
	ctx context.Context,
	userID uuid.UUID,
	personID uuid.UUID,
) ([]sqlc.PersonImportantDate, error) {
	rows, err := s.q.ListImportantDatesByPerson(ctx, sqlc.ListImportantDatesByPersonParams{
		PersonID: personID,
		UserID:   userID,
	})
	if err != nil {
		return nil, err
	}
	if rows == nil {
		rows = []sqlc.PersonImportantDate{}
	}
	return rows, nil
}

// Update performs a full replacement of an important date.
func (s *ImportantDatesService) Update(
	ctx context.Context,
	id uuid.UUID,
	userID uuid.UUID,
	in ImportantDateInput,
) (sqlc.PersonImportantDate, error) {
	if err := in.Validate(); err != nil {
		return sqlc.PersonImportantDate{}, err
	}

	result, err := s.q.UpdateImportantDate(ctx, sqlc.UpdateImportantDateParams{
		ID:                 id,
		UserID:             userID,
		Label:              in.Label,
		IsBirthday:         in.IsBirthday,
		Month:              in.Month,
		Day:                in.Day,
		Year:               nullInt32(in.Year),
		ReminderOffsetDays: nullInt32(in.ReminderOffsetDays),
		ReminderRecurrence: nullString(in.ReminderRecurrence),
		Note:               nullString(in.Note),
	})
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return sqlc.PersonImportantDate{}, ErrNotFound
		}
		return sqlc.PersonImportantDate{}, err
	}
	return result, nil
}

// Delete soft-deletes an important date.
func (s *ImportantDatesService) Delete(
	ctx context.Context,
	id uuid.UUID,
	userID uuid.UUID,
) error {
	// Verify ownership before deleting.
	_, err := s.q.GetImportantDate(ctx, sqlc.GetImportantDateParams{
		ID:     id,
		UserID: userID,
	})
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return ErrNotFound
		}
		return err
	}
	return s.q.SoftDeleteImportantDate(ctx, sqlc.SoftDeleteImportantDateParams{
		ID:     id,
		UserID: userID,
	})
}

// ---------------------------------------------------------------------------
// Null helpers
// ---------------------------------------------------------------------------

func nullString(s *string) sql.NullString {
	if s == nil {
		return sql.NullString{}
	}
	return sql.NullString{String: *s, Valid: true}
}

func nullInt32(i *int32) sql.NullInt32 {
	if i == nil {
		return sql.NullInt32{}
	}
	return sql.NullInt32{Int32: *i, Valid: true}
}
