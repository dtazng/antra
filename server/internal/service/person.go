package service

import (
	"context"
	"database/sql"
	"time"

	"github.com/duongta/antra-backend/internal/db/sqlc"
	"github.com/google/uuid"
)

// SyncConflict represents a push conflict where the server has a newer record.
type SyncConflict struct {
	ID           uuid.UUID   `json:"id"`
	Reason       string      `json:"reason"`
	ServerRecord interface{} `json:"server_record"`
}

// PersonService handles person CRUD and sync operations.
type PersonService struct {
	q *sqlc.Queries
}

func NewPersonService(q *sqlc.Queries) *PersonService {
	return &PersonService{q: q}
}

// SyncUpsert applies a single push change with LWW conflict detection.
// Returns (accepted bool, conflict *SyncConflict, error).
func (s *PersonService) SyncUpsert(ctx context.Context, userID, id uuid.UUID, name string, notes *string, clientUpdatedAt, createdAt time.Time) (bool, *SyncConflict, error) {
	existing, err := s.q.GetPersonByID(ctx, sqlc.GetPersonByIDParams{
		ID:     id,
		UserID: userID,
	})
	if err == nil {
		// Record exists — check LWW
		if existing.UpdatedAt.After(clientUpdatedAt) {
			return false, &SyncConflict{
				ID:     id,
				Reason: "server_newer",
				ServerRecord: map[string]interface{}{
					"id":         existing.ID,
					"updated_at": existing.UpdatedAt,
					"deleted_at": existing.DeletedAt,
					"data": map[string]interface{}{
						"name":  existing.Name,
						"notes": existing.Notes,
					},
				},
			}, nil
		}
	}

	var nullNotes sql.NullString
	if notes != nil {
		nullNotes = sql.NullString{String: *notes, Valid: true}
	}

	_, err = s.q.UpsertPerson(ctx, sqlc.UpsertPersonParams{
		ID:        id,
		UserID:    userID,
		Name:      name,
		Notes:     nullNotes,
		CreatedAt: createdAt,
	})
	if err != nil {
		return false, nil, err
	}
	return true, nil, nil
}

// SyncDelete soft-deletes a person via push with LWW conflict detection.
func (s *PersonService) SyncDelete(ctx context.Context, userID, id uuid.UUID, clientUpdatedAt time.Time) (bool, *SyncConflict, error) {
	existing, err := s.q.GetPersonByID(ctx, sqlc.GetPersonByIDParams{
		ID:     id,
		UserID: userID,
	})
	if err != nil {
		// Not found — treat as accepted (idempotent)
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
	_, err = s.q.SoftDeletePerson(ctx, sqlc.SoftDeletePersonParams{
		ID:     id,
		UserID: userID,
	})
	return err == nil, nil, err
}

// Pull returns persons updated since the given timestamp.
func (s *PersonService) Pull(ctx context.Context, userID uuid.UUID, since time.Time, limit int32) ([]sqlc.GetPersonsByUpdatedSinceRow, error) {
	return s.q.GetPersonsByUpdatedSince(ctx, sqlc.GetPersonsByUpdatedSinceParams{
		UserID:    userID,
		UpdatedAt: since,
		Limit:     limit,
	})
}

// List returns paginated active persons sorted by name.
func (s *PersonService) List(ctx context.Context, userID uuid.UUID, limit, offset int32) ([]sqlc.ListPersonsRow, error) {
	return s.q.ListPersons(ctx, sqlc.ListPersonsParams{
		UserID: userID,
		Limit:  limit,
		Offset: offset,
	})
}

// Search performs full-text search on persons.
func (s *PersonService) Search(ctx context.Context, userID uuid.UUID, q string) ([]sqlc.SearchPersonsRow, error) {
	return s.q.SearchPersons(ctx, sqlc.SearchPersonsParams{
		UserID:         userID,
		PlaintoTsquery: q,
	})
}

// Get returns a single person by ID.
func (s *PersonService) Get(ctx context.Context, userID, id uuid.UUID) (sqlc.GetPersonByIDRow, error) {
	p, err := s.q.GetPersonByID(ctx, sqlc.GetPersonByIDParams{
		ID:     id,
		UserID: userID,
	})
	if err != nil {
		return sqlc.GetPersonByIDRow{}, ErrNotFound
	}
	if p.DeletedAt.Valid {
		return sqlc.GetPersonByIDRow{}, ErrNotFound
	}
	return p, nil
}

// Create inserts a new person (client-provided ID or server-generated).
func (s *PersonService) Create(ctx context.Context, userID, id uuid.UUID, name string, notes *string) (sqlc.UpsertPersonRow, error) {
	var nullNotes sql.NullString
	if notes != nil {
		nullNotes = sql.NullString{String: *notes, Valid: true}
	}
	return s.q.UpsertPerson(ctx, sqlc.UpsertPersonParams{
		ID:        id,
		UserID:    userID,
		Name:      name,
		Notes:     nullNotes,
		CreatedAt: time.Now(),
	})
}

// Update patches a person's mutable fields.
func (s *PersonService) Update(ctx context.Context, userID, id uuid.UUID, name, notes *string) (sqlc.UpdatePersonRow, error) {
	var nullName sql.NullString
	if name != nil {
		nullName = sql.NullString{String: *name, Valid: true}
	}
	var nullNotes sql.NullString
	if notes != nil {
		nullNotes = sql.NullString{String: *notes, Valid: true}
	}
	return s.q.UpdatePerson(ctx, sqlc.UpdatePersonParams{
		ID:     id,
		UserID: userID,
		Name:   nullName,
		Notes:  nullNotes,
	})
}

// Delete soft-deletes a person.
func (s *PersonService) Delete(ctx context.Context, userID, id uuid.UUID) error {
	_, err := s.q.SoftDeletePerson(ctx, sqlc.SoftDeletePersonParams{
		ID:     id,
		UserID: userID,
	})
	return err
}
