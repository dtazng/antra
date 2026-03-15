package v1

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/duongta/antra-backend/internal/service"
)

// SettingsHandler handles /settings routes.
type SettingsHandler struct {
	svc *service.SettingsService
}

func NewSettingsHandler(svc *service.SettingsService) *SettingsHandler {
	return &SettingsHandler{svc: svc}
}

func (h *SettingsHandler) Routes() chi.Router {
	r := chi.NewRouter()
	r.Get("/", h.get)
	r.Patch("/", h.update)
	return r
}

func (h *SettingsHandler) get(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}
	settings, err := h.svc.Get(r.Context(), userID)
	if err != nil {
		mapServiceError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, settings)
}

func (h *SettingsHandler) update(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}
	var req struct {
		NotificationsEnabled       *bool  `json:"notifications_enabled"`
		DefaultFollowUpDays        *int32 `json:"default_follow_up_days"`
		InactivityFollowUpsEnabled *bool  `json:"inactivity_follow_ups_enabled"`
		InactivityThresholdDays    *int32 `json:"inactivity_threshold_days"`
	}
	if err := readJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "INVALID_INPUT", "invalid request body")
		return
	}
	settings, err := h.svc.Update(r.Context(), userID, req.NotificationsEnabled, req.DefaultFollowUpDays, req.InactivityFollowUpsEnabled, req.InactivityThresholdDays)
	if err != nil {
		mapServiceError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, settings)
}
