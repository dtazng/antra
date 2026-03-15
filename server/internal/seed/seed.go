package seed

import (
	"context"
	"database/sql"
	"log/slog"
	"time"

	"github.com/duongta/antra-backend/internal/db/sqlc"
	"github.com/duongta/antra-backend/internal/token"
	"github.com/google/uuid"
)

// Run inserts deterministic seed data for local development.
// All inserts are idempotent (ON CONFLICT DO NOTHING / DO UPDATE).
func Run(ctx context.Context, q *sqlc.Queries) error {
	slog.Info("seed: starting")

	// 1. Seed user
	hash, err := token.HashPassword("password123")
	if err != nil {
		return err
	}
	user, err := q.CreateUser(ctx, sqlc.CreateUserParams{
		Email:        "seed@example.com",
		PasswordHash: hash,
	})
	if err != nil {
		if !isDuplicateKeyError(err) {
			return err
		}
		// Already exists — look it up
		user, err = q.GetUserByEmail(ctx, "seed@example.com")
		if err != nil {
			return err
		}
	}
	slog.Info("seed: user ready", "id", user.ID)

	// Auto-create settings
	_, _ = q.GetOrCreateUserSettings(ctx, user.ID)

	// 2. Seed persons (fixed UUIDs for repeatability)
	person1ID := uuid.MustParse("11111111-1111-1111-1111-111111111111")
	person2ID := uuid.MustParse("22222222-2222-2222-2222-222222222222")
	_, _ = q.UpsertPerson(ctx, sqlc.UpsertPersonParams{
		ID:        person1ID,
		UserID:    user.ID,
		Name:      "Alex Chen",
		Notes:     sql.NullString{String: "Met at conference", Valid: true},
		CreatedAt: time.Now().AddDate(0, -1, 0),
	})
	_, _ = q.UpsertPerson(ctx, sqlc.UpsertPersonParams{
		ID:        person2ID,
		UserID:    user.ID,
		Name:      "Jordan Lee",
		Notes:     sql.NullString{String: "Investor contact", Valid: true},
		CreatedAt: time.Now().AddDate(0, -2, 0),
	})

	// 3. Seed logs
	log1ID := uuid.MustParse("33333333-3333-3333-3333-333333333333")
	_, _ = q.UpsertLog(ctx, sqlc.UpsertLogParams{
		ID:        log1ID,
		UserID:    user.ID,
		Content:   "Had coffee with Alex, discussed new project",
		Type:      "interaction",
		Status:    "open",
		DayID:     time.Now().AddDate(0, 0, -3),
		DeviceID:  "seed-device",
		CreatedAt: time.Now().AddDate(0, 0, -3),
	})
	_ = q.ReplaceLogPersonLinks(ctx, sqlc.ReplaceLogPersonLinksParams{
		LogID:   log1ID,
		Column2: []uuid.UUID{person1ID},
		UserID:  user.ID,
	})

	// 4. Seed a past-due follow-up (due yesterday)
	followUpID := uuid.MustParse("44444444-4444-4444-4444-444444444444")
	_, _ = q.UpsertFollowUp(ctx, sqlc.UpsertFollowUpParams{
		ID:          followUpID,
		UserID:      user.ID,
		LogID:       uuid.NullUUID{UUID: log1ID, Valid: true},
		PersonID:    uuid.NullUUID{UUID: person1ID, Valid: true},
		Title:       "Follow up with Alex about contract",
		DueDate:     time.Now().AddDate(0, 0, -1),
		Status:      "pending",
		IsRecurring: false,
		CreatedAt:   time.Now().AddDate(0, 0, -7),
	})

	slog.Info("seed: complete",
		"user_id", user.ID,
		"email", "seed@example.com",
		"password", "password123",
	)
	return nil
}

func isDuplicateKeyError(err error) bool {
	if err == nil {
		return false
	}
	s := err.Error()
	for _, substr := range []string{"23505", "duplicate key", "unique constraint"} {
		for i := 0; i <= len(s)-len(substr); i++ {
			if s[i:i+len(substr)] == substr {
				return true
			}
		}
	}
	return false
}
