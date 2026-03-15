package service

import (
	"context"

	"github.com/duongta/antra-backend/internal/db/sqlc"
	"github.com/google/uuid"
)

// DeviceService handles device token registration.
type DeviceService struct {
	q *sqlc.Queries
}

func NewDeviceService(q *sqlc.Queries) *DeviceService {
	return &DeviceService{q: q}
}

// Register upserts a device token for a user.
func (s *DeviceService) Register(ctx context.Context, userID uuid.UUID, token, platform string) (sqlc.DeviceToken, error) {
	return s.q.UpsertDeviceToken(ctx, sqlc.UpsertDeviceTokenParams{
		UserID:   userID,
		Token:    token,
		Platform: platform,
	})
}

// Deactivate marks a device token as inactive.
func (s *DeviceService) Deactivate(ctx context.Context, userID, deviceID uuid.UUID) error {
	return s.q.DeactivateDeviceToken(ctx, sqlc.DeactivateDeviceTokenParams{
		ID:     deviceID,
		UserID: userID,
	})
}
