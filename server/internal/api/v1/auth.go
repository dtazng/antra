package v1

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/duongta/antra-backend/internal/api/middleware"
	"github.com/duongta/antra-backend/internal/service"
	"github.com/google/uuid"
)

// AuthHandler holds the auth service for the /auth route group.
type AuthHandler struct {
	svc       *service.AuthService
	jwtSecret string
}

func NewAuthHandler(svc *service.AuthService, jwtSecret string) *AuthHandler {
	return &AuthHandler{svc: svc, jwtSecret: jwtSecret}
}

func (h *AuthHandler) Routes() chi.Router {
	r := chi.NewRouter()
	r.Post("/register", h.register)
	r.Post("/login", h.login)
	r.Post("/refresh", h.refresh)
	r.Post("/logout", h.logout)
	// DELETE /account requires a valid access token
	r.With(middleware.BearerAuth(h.jwtSecret)).Delete("/account", h.deleteAccount)
	return r
}

func (h *AuthHandler) register(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Email    string `json:"email"`
		Password string `json:"password"`
	}
	if err := readJSON(r, &req); err != nil || req.Email == "" || len(req.Password) < 8 {
		writeError(w, http.StatusBadRequest, "INVALID_INPUT", "email and password (min 8 chars) required")
		return
	}
	tokens, err := h.svc.Register(r.Context(), req.Email, req.Password)
	if err != nil {
		mapServiceError(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, tokens)
}

func (h *AuthHandler) login(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Email    string `json:"email"`
		Password string `json:"password"`
	}
	if err := readJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "INVALID_INPUT", "invalid request body")
		return
	}
	tokens, err := h.svc.Login(r.Context(), req.Email, req.Password)
	if err != nil {
		mapServiceError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, tokens)
}

func (h *AuthHandler) refresh(w http.ResponseWriter, r *http.Request) {
	var req struct {
		RefreshToken string `json:"refresh_token"`
	}
	if err := readJSON(r, &req); err != nil || req.RefreshToken == "" {
		writeError(w, http.StatusBadRequest, "INVALID_INPUT", "refresh_token required")
		return
	}
	tokenID, err := uuid.Parse(req.RefreshToken)
	if err != nil {
		writeError(w, http.StatusUnauthorized, "AUTH_REQUIRED", "invalid refresh token")
		return
	}
	accessToken, err := h.svc.Refresh(r.Context(), tokenID)
	if err != nil {
		writeError(w, http.StatusUnauthorized, "AUTH_REQUIRED", "invalid or expired refresh token")
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{
		"access_token": accessToken,
		"token_type":   "bearer",
	})
}

func (h *AuthHandler) logout(w http.ResponseWriter, r *http.Request) {
	var req struct {
		RefreshToken string `json:"refresh_token"`
	}
	if err := readJSON(r, &req); err != nil || req.RefreshToken == "" {
		writeError(w, http.StatusBadRequest, "INVALID_INPUT", "refresh_token required")
		return
	}
	tokenID, err := uuid.Parse(req.RefreshToken)
	if err != nil {
		w.WriteHeader(http.StatusNoContent)
		return
	}
	_ = h.svc.Logout(r.Context(), tokenID)
	w.WriteHeader(http.StatusNoContent)
}

func (h *AuthHandler) deleteAccount(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}
	var req struct {
		Confirm string `json:"confirm"`
	}
	if err := readJSON(r, &req); err != nil || req.Confirm != "DELETE" {
		writeError(w, http.StatusBadRequest, "CONFIRMATION_REQUIRED", `send {"confirm":"DELETE"} to proceed`)
		return
	}
	if err := h.svc.DeleteAccount(r.Context(), userID); err != nil {
		mapServiceError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"message": "Account scheduled for deletion"})
}
