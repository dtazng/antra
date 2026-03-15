package middleware

import (
	"context"
	"encoding/json"
	"net/http"
	"strings"

	"github.com/duongta/antra-backend/internal/token"
	"github.com/google/uuid"
)

type contextKey string

const userIDKey contextKey = "userID"

type errorResponse struct {
	Error   string `json:"error"`
	Message string `json:"message"`
}

// BearerAuth extracts and validates the Authorization: Bearer <jwt> header.
// On success, injects the userID (uuid.UUID) into the request context.
// On failure, responds 401 AUTH_REQUIRED.
func BearerAuth(secret string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			authHeader := r.Header.Get("Authorization")
			if !strings.HasPrefix(authHeader, "Bearer ") {
				writeJSONError(w, http.StatusUnauthorized, "AUTH_REQUIRED", "missing or invalid Authorization header")
				return
			}
			tokenStr := strings.TrimPrefix(authHeader, "Bearer ")
			userID, err := token.ParseAccessToken(tokenStr, secret)
			if err != nil {
				writeJSONError(w, http.StatusUnauthorized, "AUTH_REQUIRED", "invalid or expired token")
				return
			}
			ctx := context.WithValue(r.Context(), userIDKey, userID)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

// UserIDFromContext retrieves the authenticated user's UUID from the context.
// Returns uuid.Nil and false if not present.
func UserIDFromContext(ctx context.Context) (uuid.UUID, bool) {
	id, ok := ctx.Value(userIDKey).(uuid.UUID)
	return id, ok
}

// writeJSONError writes a JSON error response.
func writeJSONError(w http.ResponseWriter, status int, code, message string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(errorResponse{Error: code, Message: message})
}
