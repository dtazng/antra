package v1

import (
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/duongta/antra-backend/internal/service"
	"github.com/google/uuid"
)

// FollowUpsHandler handles /follow-ups routes.
type FollowUpsHandler struct {
	svc *service.FollowUpService
}

func NewFollowUpsHandler(svc *service.FollowUpService) *FollowUpsHandler {
	return &FollowUpsHandler{svc: svc}
}

func (h *FollowUpsHandler) Routes() chi.Router {
	r := chi.NewRouter()
	r.Get("/", h.list)
	r.Get("/{id}", h.get)
	r.Post("/", h.create)
	r.Patch("/{id}", h.update)
	r.Delete("/{id}", h.delete)
	return r
}

func (h *FollowUpsHandler) list(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}
	status := r.URL.Query().Get("status")
	limit := int32(queryInt(r, "limit", 50))
	offset := int32(queryInt(r, "offset", 0))
	fus, err := h.svc.List(r.Context(), userID, status, limit, offset)
	if err != nil {
		mapServiceError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, fus)
}

func (h *FollowUpsHandler) get(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		writeError(w, http.StatusBadRequest, "INVALID_INPUT", "invalid id")
		return
	}
	fu, err := h.svc.Get(r.Context(), userID, id)
	if err != nil {
		mapServiceError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, fu)
}

func (h *FollowUpsHandler) create(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}
	var req struct {
		ID                     *string    `json:"id"`
		Title                  string     `json:"title"`
		DueDate                string     `json:"due_date"`
		LogID                  *uuid.UUID `json:"log_id"`
		PersonID               *uuid.UUID `json:"person_id"`
		IsRecurring            bool       `json:"is_recurring"`
		RecurrenceIntervalDays *int32     `json:"recurrence_interval_days"`
		RecurrenceType         *string    `json:"recurrence_type"`
	}
	if err := readJSON(r, &req); err != nil || req.Title == "" {
		writeError(w, http.StatusBadRequest, "INVALID_INPUT", "title required")
		return
	}
	dueDate, err := time.Parse("2006-01-02", req.DueDate)
	if err != nil {
		writeError(w, http.StatusBadRequest, "INVALID_INPUT", "due_date must be YYYY-MM-DD")
		return
	}
	id := uuid.New()
	if req.ID != nil {
		if parsed, err := uuid.Parse(*req.ID); err == nil {
			id = parsed
		}
	}
	fu, err := h.svc.Create(r.Context(), userID, id, req.LogID, req.PersonID, req.Title, dueDate, req.IsRecurring, req.RecurrenceIntervalDays, req.RecurrenceType)
	if err != nil {
		mapServiceError(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, fu)
}

func (h *FollowUpsHandler) update(w http.ResponseWriter, r *http.Request) {
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
		Title        *string `json:"title"`
		DueDate      *string `json:"due_date"`
		Status       *string `json:"status"`
		SnoozedUntil *string `json:"snoozed_until"`
	}
	if err := readJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "INVALID_INPUT", "invalid request body")
		return
	}
	var dueDate, snoozedUntil, completedAt *time.Time
	if req.DueDate != nil {
		t, err := time.Parse("2006-01-02", *req.DueDate)
		if err != nil {
			writeError(w, http.StatusBadRequest, "INVALID_INPUT", "due_date must be YYYY-MM-DD")
			return
		}
		dueDate = &t
	}
	if req.SnoozedUntil != nil {
		t, err := time.Parse("2006-01-02", *req.SnoozedUntil)
		if err != nil {
			writeError(w, http.StatusBadRequest, "INVALID_INPUT", "snoozed_until must be YYYY-MM-DD")
			return
		}
		snoozedUntil = &t
	}
	if req.Status != nil && *req.Status == "completed" {
		now := time.Now()
		completedAt = &now
	}
	fu, err := h.svc.Update(r.Context(), userID, id, req.Title, dueDate, snoozedUntil, completedAt, req.Status)
	if err != nil {
		mapServiceError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, fu)
}

func (h *FollowUpsHandler) delete(w http.ResponseWriter, r *http.Request) {
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
