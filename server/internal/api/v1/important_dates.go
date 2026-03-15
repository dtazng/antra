package v1

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/duongta/antra-backend/internal/service"
	"github.com/google/uuid"
)

// ImportantDatesHandler handles /persons/{personId}/important-dates routes.
type ImportantDatesHandler struct {
	svc *service.ImportantDatesService
}

func NewImportantDatesHandler(svc *service.ImportantDatesService) *ImportantDatesHandler {
	return &ImportantDatesHandler{svc: svc}
}

func (h *ImportantDatesHandler) Routes() chi.Router {
	r := chi.NewRouter()
	r.Post("/", h.create)
	r.Get("/", h.list)
	r.Put("/{id}", h.update)
	r.Delete("/{id}", h.delete)
	return r
}

// importantDateRequest mirrors the POST/PUT body from the API contract.
type importantDateRequest struct {
	ID                 string  `json:"id"`
	Label              string  `json:"label"`
	IsBirthday         bool    `json:"is_birthday"`
	Month              int32   `json:"month"`
	Day                int32   `json:"day"`
	Year               *int32  `json:"year"`
	ReminderOffsetDays *int32  `json:"reminder_offset_days"`
	ReminderRecurrence *string `json:"reminder_recurrence"`
	Note               *string `json:"note"`
}

func (h *ImportantDatesHandler) create(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}
	personID, err := uuid.Parse(chi.URLParam(r, "personId"))
	if err != nil {
		writeError(w, http.StatusBadRequest, "INVALID_INPUT", "invalid person_id")
		return
	}

	var req importantDateRequest
	if err := readJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "INVALID_INPUT", "malformed request body")
		return
	}
	id, err := uuid.Parse(req.ID)
	if err != nil {
		writeError(w, http.StatusBadRequest, "INVALID_INPUT", "id must be a valid UUID")
		return
	}

	result, err := h.svc.Create(r.Context(), id, userID, personID, service.ImportantDateInput{
		Label:              req.Label,
		IsBirthday:         req.IsBirthday,
		Month:              req.Month,
		Day:                req.Day,
		Year:               req.Year,
		ReminderOffsetDays: req.ReminderOffsetDays,
		ReminderRecurrence: req.ReminderRecurrence,
		Note:               req.Note,
	})
	if err != nil {
		mapServiceError(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, result)
}

func (h *ImportantDatesHandler) list(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}
	personID, err := uuid.Parse(chi.URLParam(r, "personId"))
	if err != nil {
		writeError(w, http.StatusBadRequest, "INVALID_INPUT", "invalid person_id")
		return
	}

	items, err := h.svc.List(r.Context(), userID, personID)
	if err != nil {
		mapServiceError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]interface{}{"items": items})
}

func (h *ImportantDatesHandler) update(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		writeError(w, http.StatusBadRequest, "INVALID_INPUT", "invalid id")
		return
	}

	var req importantDateRequest
	if err := readJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "INVALID_INPUT", "malformed request body")
		return
	}

	result, err := h.svc.Update(r.Context(), id, userID, service.ImportantDateInput{
		Label:              req.Label,
		IsBirthday:         req.IsBirthday,
		Month:              req.Month,
		Day:                req.Day,
		Year:               req.Year,
		ReminderOffsetDays: req.ReminderOffsetDays,
		ReminderRecurrence: req.ReminderRecurrence,
		Note:               req.Note,
	})
	if err != nil {
		mapServiceError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, result)
}

func (h *ImportantDatesHandler) delete(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		writeError(w, http.StatusBadRequest, "INVALID_INPUT", "invalid id")
		return
	}

	if err := h.svc.Delete(r.Context(), id, userID); err != nil {
		mapServiceError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
