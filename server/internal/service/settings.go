package service

import (
	"context"

	"github.com/duongta/antra-backend/internal/db/sqlc"
	"github.com/google/uuid"
)

// SettingsService handles user settings retrieval and updates.
type SettingsService struct {
	q *sqlc.Queries
}

func NewSettingsService(q *sqlc.Queries) *SettingsService {
	return &SettingsService{q: q}
}

// Get returns the user's settings, creating defaults if they don't exist.
func (s *SettingsService) Get(ctx context.Context, userID uuid.UUID) (sqlc.UserSetting, error) {
	return s.q.GetOrCreateUserSettings(ctx, userID)
}

// Update patches the user's settings.
func (s *SettingsService) Update(ctx context.Context, userID uuid.UUID, notificationsEnabled *bool, defaultFollowUpDays *int32, inactivityFollowUpsEnabled *bool, inactivityThresholdDays *int32) (sqlc.UserSetting, error) {
	return s.q.UpdateUserSettings(ctx, sqlc.UpdateUserSettingsParams{
		UserID:                     userID,
		NotificationsEnabled:       notificationsEnabled,
		DefaultFollowUpDays:        defaultFollowUpDays,
		InactivityFollowUpsEnabled: inactivityFollowUpsEnabled,
		InactivityThresholdDays:    inactivityThresholdDays,
	})
}
