package v1

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/duongta/antra-backend/internal/service"
	"github.com/google/uuid"
)

// NotificationsHandler handles /notifications routes.
type NotificationsHandler struct {
	svc *service.NotificationService
}

func NewNotificationsHandler(svc *service.NotificationService) *NotificationsHandler {
	return &NotificationsHandler{svc: svc}
}

func (h *NotificationsHandler) Routes() chi.Router {
	r := chi.NewRouter()
	r.Get("/", h.list)
	r.Post("/{id}/dismiss", h.dismiss)
	return r
}

func (h *NotificationsHandler) list(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}
	limit := int32(queryInt(r, "limit", 50))
	offset := int32(queryInt(r, "offset", 0))
	notifs, err := h.svc.List(r.Context(), userID, limit, offset)
	if err != nil {
		mapServiceError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, notifs)
}

func (h *NotificationsHandler) dismiss(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		writeError(w, http.StatusBadRequest, "INVALID_INPUT", "invalid id")
		return
	}
	notif, err := h.svc.Dismiss(r.Context(), userID, id)
	if err != nil {
		mapServiceError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, notif)
}
