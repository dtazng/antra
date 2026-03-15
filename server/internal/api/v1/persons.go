package v1

import (
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"
	"github.com/duongta/antra-backend/internal/service"
	"github.com/google/uuid"
)

// PersonsHandler handles /persons routes.
type PersonsHandler struct {
	svc *service.PersonService
}

func NewPersonsHandler(svc *service.PersonService) *PersonsHandler {
	return &PersonsHandler{svc: svc}
}

func (h *PersonsHandler) Routes() chi.Router {
	r := chi.NewRouter()
	r.Get("/", h.list)
	r.Get("/search", h.search)
	r.Get("/{id}", h.get)
	r.Post("/", h.create)
	r.Patch("/{id}", h.update)
	r.Delete("/{id}", h.delete)
	return r
}

func (h *PersonsHandler) list(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}
	limit := int32(queryInt(r, "limit", 50))
	offset := int32(queryInt(r, "offset", 0))
	persons, err := h.svc.List(r.Context(), userID, limit, offset)
	if err != nil {
		mapServiceError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, persons)
}

func (h *PersonsHandler) search(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}
	q := r.URL.Query().Get("q")
	if q == "" {
		writeJSON(w, http.StatusOK, []interface{}{})
		return
	}
	persons, err := h.svc.Search(r.Context(), userID, q)
	if err != nil {
		mapServiceError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, persons)
}

func (h *PersonsHandler) get(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		writeError(w, http.StatusBadRequest, "INVALID_INPUT", "invalid id")
		return
	}
	person, err := h.svc.Get(r.Context(), userID, id)
	if err != nil {
		mapServiceError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, person)
}

func (h *PersonsHandler) create(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}
	var req struct {
		ID    *string `json:"id"`
		Name  string  `json:"name"`
		Notes *string `json:"notes"`
	}
	if err := readJSON(r, &req); err != nil || req.Name == "" {
		writeError(w, http.StatusBadRequest, "INVALID_INPUT", "name required")
		return
	}
	id := uuid.New()
	if req.ID != nil {
		if parsed, err := uuid.Parse(*req.ID); err == nil {
			id = parsed
		}
	}
	person, err := h.svc.Create(r.Context(), userID, id, req.Name, req.Notes)
	if err != nil {
		mapServiceError(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, person)
}

func (h *PersonsHandler) update(w http.ResponseWriter, r *http.Request) {
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
		Name  *string `json:"name"`
		Notes *string `json:"notes"`
	}
	if err := readJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, "INVALID_INPUT", "invalid request body")
		return
	}
	person, err := h.svc.Update(r.Context(), userID, id, req.Name, req.Notes)
	if err != nil {
		mapServiceError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, person)
}

func (h *PersonsHandler) delete(w http.ResponseWriter, r *http.Request) {
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

func queryInt(r *http.Request, key string, defaultVal int) int {
	v := r.URL.Query().Get(key)
	if v == "" {
		return defaultVal
	}
	n, err := strconv.Atoi(v)
	if err != nil {
		return defaultVal
	}
	return n
}
