package v1

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/duongta/antra-backend/internal/service"
	"github.com/google/uuid"
)

// DevicesHandler handles /devices routes.
type DevicesHandler struct {
	svc *service.DeviceService
}

func NewDevicesHandler(svc *service.DeviceService) *DevicesHandler {
	return &DevicesHandler{svc: svc}
}

func (h *DevicesHandler) Routes() chi.Router {
	r := chi.NewRouter()
	r.Post("/", h.register)
	r.Delete("/{id}", h.deactivate)
	return r
}

func (h *DevicesHandler) register(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}
	var req struct {
		Token    string `json:"token"`
		Platform string `json:"platform"`
	}
	if err := readJSON(r, &req); err != nil || req.Token == "" || req.Platform == "" {
		writeError(w, http.StatusBadRequest, "INVALID_INPUT", "token and platform required")
		return
	}
	device, err := h.svc.Register(r.Context(), userID, req.Token, req.Platform)
	if err != nil {
		mapServiceError(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, device)
}

func (h *DevicesHandler) deactivate(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		writeError(w, http.StatusBadRequest, "INVALID_INPUT", "invalid id")
		return
	}
	if err := h.svc.Deactivate(r.Context(), userID, id); err != nil {
		mapServiceError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
