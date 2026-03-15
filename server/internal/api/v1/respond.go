package v1

import (
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"

	"github.com/duongta/antra-backend/internal/api/middleware"
	"github.com/duongta/antra-backend/internal/service"
	"github.com/google/uuid"
)

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

func writeError(w http.ResponseWriter, status int, code, message string) {
	writeJSON(w, status, map[string]string{"error": code, "message": message})
}

func readJSON(r *http.Request, v any) error {
	return json.NewDecoder(r.Body).Decode(v)
}

// requireUserID extracts the authenticated user ID from context or writes 401.
func requireUserID(w http.ResponseWriter, r *http.Request) (uuid.UUID, bool) {
	userID, ok := middleware.UserIDFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "AUTH_REQUIRED", "authentication required")
		return uuid.Nil, false
	}
	return userID, true
}

// mapServiceError maps common service errors to HTTP status/code pairs.
func mapServiceError(w http.ResponseWriter, err error) {
	switch {
	case errors.Is(err, service.ErrNotFound):
		writeError(w, http.StatusNotFound, "NOT_FOUND", "resource not found")
	case errors.Is(err, service.ErrEmailTaken):
		writeError(w, http.StatusConflict, "EMAIL_TAKEN", "email already registered")
	case errors.Is(err, service.ErrConflict):
		writeError(w, http.StatusConflict, "CONFLICT", "resource already exists")
	case errors.Is(err, service.ErrInvalidInput):
		writeError(w, http.StatusBadRequest, "INVALID_INPUT", err.Error())
	case errors.Is(err, service.ErrInvalidCredentials):
		writeError(w, http.StatusUnauthorized, "AUTH_REQUIRED", "invalid credentials")
	default:
		slog.Error("unhandled service error", "error", err)
		writeError(w, http.StatusInternalServerError, "INTERNAL_ERROR", "internal server error")
	}
}
