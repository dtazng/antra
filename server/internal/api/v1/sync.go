package v1

import (
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/duongta/antra-backend/internal/service"
)

// SyncHandler handles /sync/{entityType}/push and pull routes.
type SyncHandler struct {
	svc *service.SyncService
}

func NewSyncHandler(svc *service.SyncService) *SyncHandler {
	return &SyncHandler{svc: svc}
}

func (h *SyncHandler) Routes() chi.Router {
	r := chi.NewRouter()
	r.Post("/{entityType}/push", h.push)
	r.Get("/{entityType}/pull", h.pull)
	return r
}

func (h *SyncHandler) push(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}
	entityType := chi.URLParam(r, "entityType")

	var req struct {
		DeviceID string               `json:"device_id"`
		Changes  []service.SyncChange `json:"changes"`
	}
	if err := readJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "INVALID_INPUT", "invalid request body")
		return
	}
	if req.DeviceID == "" {
		writeError(w, http.StatusBadRequest, "INVALID_INPUT", "device_id required")
		return
	}

	result, err := h.svc.Push(r.Context(), userID, entityType, req.Changes, req.DeviceID)
	if err != nil {
		if err == service.ErrUnsupportedEntityType {
			writeError(w, http.StatusBadRequest, "INVALID_INPUT", "entityType must be persons, logs, or follow_ups")
			return
		}
		mapServiceError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, result)
}

func (h *SyncHandler) pull(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}
	entityType := chi.URLParam(r, "entityType")

	// Parse since parameter (default: epoch)
	sinceStr := r.URL.Query().Get("since")
	since := time.Time{}
	if sinceStr != "" {
		if t, err := time.Parse(time.RFC3339, sinceStr); err == nil {
			since = t
		}
	}
	limit := int32(queryInt(r, "limit", 200))

	result, err := h.svc.Pull(r.Context(), userID, entityType, since, limit)
	if err != nil {
		if err == service.ErrUnsupportedEntityType {
			writeError(w, http.StatusBadRequest, "INVALID_INPUT", "entityType must be persons, logs, or follow_ups")
			return
		}
		mapServiceError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, result)
}
