package service

import (
	"context"
	"database/sql"

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
	var nullNotificationsEnabled sql.NullBool
	if notificationsEnabled != nil {
		nullNotificationsEnabled = sql.NullBool{Bool: *notificationsEnabled, Valid: true}
	}
	var nullDefaultFollowUpDays sql.NullInt32
	if defaultFollowUpDays != nil {
		nullDefaultFollowUpDays = sql.NullInt32{Int32: *defaultFollowUpDays, Valid: true}
	}
	var nullInactivityFollowUpsEnabled sql.NullBool
	if inactivityFollowUpsEnabled != nil {
		nullInactivityFollowUpsEnabled = sql.NullBool{Bool: *inactivityFollowUpsEnabled, Valid: true}
	}
	var nullInactivityThresholdDays sql.NullInt32
	if inactivityThresholdDays != nil {
		nullInactivityThresholdDays = sql.NullInt32{Int32: *inactivityThresholdDays, Valid: true}
	}
	return s.q.UpdateUserSettings(ctx, sqlc.UpdateUserSettingsParams{
		UserID:                     userID,
		NotificationsEnabled:       nullNotificationsEnabled,
		DefaultFollowUpDays:        nullDefaultFollowUpDays,
		InactivityFollowUpsEnabled: nullInactivityFollowUpsEnabled,
		InactivityThresholdDays:    nullInactivityThresholdDays,
	})
}
