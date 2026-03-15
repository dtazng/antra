package v1

import (
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/duongta/antra-backend/internal/service"
	"github.com/google/uuid"
)

// LogsHandler handles /logs routes.
type LogsHandler struct {
	svc *service.LogService
}

func NewLogsHandler(svc *service.LogService) *LogsHandler {
	return &LogsHandler{svc: svc}
}

func (h *LogsHandler) Routes() chi.Router {
	r := chi.NewRouter()
	r.Get("/", h.list)
	r.Get("/{id}", h.get)
	r.Post("/", h.create)
	r.Patch("/{id}", h.update)
	r.Delete("/{id}", h.delete)
	return r
}

func (h *LogsHandler) list(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}
	limit := int32(queryInt(r, "limit", 50))
	offset := int32(queryInt(r, "offset", 0))
	logs, err := h.svc.List(r.Context(), userID, limit, offset)
	if err != nil {
		mapServiceError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, logs)
}

func (h *LogsHandler) get(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		writeError(w, http.StatusBadRequest, "INVALID_INPUT", "invalid id")
		return
	}
	log, err := h.svc.Get(r.Context(), userID, id)
	if err != nil {
		mapServiceError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, log)
}

func (h *LogsHandler) create(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}
	var req struct {
		ID        *string     `json:"id"`
		Content   string      `json:"content"`
		Type      string      `json:"type"`
		Status    string      `json:"status"`
		DayID     string      `json:"day_id"`
		DeviceID  string      `json:"device_id"`
		PersonIDs []uuid.UUID `json:"person_ids"`
	}
	if err := readJSON(r, &req); err != nil || req.Content == "" {
		writeError(w, http.StatusBadRequest, "INVALID_INPUT", "content required")
		return
	}
	dayID, err := time.Parse("2006-01-02", req.DayID)
	if err != nil {
		writeError(w, http.StatusBadRequest, "INVALID_INPUT", "day_id must be YYYY-MM-DD")
		return
	}
	id := uuid.New()
	if req.ID != nil {
		if parsed, err := uuid.Parse(*req.ID); err == nil {
			id = parsed
		}
	}
	logType := req.Type
	if logType == "" {
		logType = "note"
	}
	status := req.Status
	if status == "" {
		status = "open"
	}
	log, err := h.svc.Create(r.Context(), userID, id, req.Content, logType, status, dayID, req.DeviceID, req.PersonIDs)
	if err != nil {
		mapServiceError(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, log)
}

func (h *LogsHandler) update(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		writeError(w, http.StatusBadRequest, "INVALID_INPUT", "invalid id")
		return
	}
	var req struct {
		Content   *string     `json:"content"`
		Type      *string     `json:"type"`
		Status    *string     `json:"status"`
		PersonIDs []uuid.UUID `json:"person_ids"`
	}
	if err := readJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "INVALID_INPUT", "invalid request body")
		return
	}
	log, err := h.svc.Update(r.Context(), userID, id, req.Content, req.Type, req.Status, req.PersonIDs)
	if err != nil {
		mapServiceError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, log)
}

func (h *LogsHandler) delete(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		writeError(w, http.StatusBadRequest, "INVALID_INPUT", "invalid id")
		return
	}
	if err := h.svc.Delete(r.Context(), userID, id); err != nil {
		mapServiceError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
