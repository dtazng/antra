package integration

import (
	"github.com/duongta/antra-backend/internal/token"
	"github.com/google/uuid"
)

// parseJWT is a shared helper for all integration tests to extract a userID from a JWT.
func parseJWT(accessToken string) (uuid.UUID, error) {
	return token.ParseAccessToken(accessToken, testJWTSecret)
}
