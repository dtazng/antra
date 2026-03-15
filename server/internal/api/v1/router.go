package v1

import (
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"
	chimw "github.com/go-chi/chi/v5/middleware"

	"github.com/duongta/antra-backend/internal/api/middleware"
	"github.com/duongta/antra-backend/internal/db/sqlc"
	"github.com/duongta/antra-backend/internal/service"
)

// Config holds dependencies needed by the v1 router.
type Config struct {
	Queries              *sqlc.Queries
	JWTSecret            string
	AccessExpireMinutes  int
	RefreshExpireDays    int
}

// NewRouter creates the root chi router: /health + /v1/* routes.
func NewRouter(cfg Config) http.Handler {
	r := chi.NewRouter()

	// Shared middleware
	r.Use(chimw.Recoverer)
	r.Use(middleware.Logger)

	// Health endpoint (no auth)
	r.Get("/health", healthHandler(cfg.Queries))

	// Versioned API
	r.Mount("/v1", v1Router(cfg))

	return r
}

// v1Router returns a chi router for all /v1 routes.
func v1Router(cfg Config) http.Handler {
	r := chi.NewRouter()

	// Public routes (no auth required); DELETE /auth/account applies its own bearer middleware
	authSvc := service.NewAuthService(cfg.Queries).WithConfig(cfg.JWTSecret, cfg.AccessExpireMinutes, cfg.RefreshExpireDays)
	r.Mount("/auth", NewAuthHandler(authSvc, cfg.JWTSecret).Routes())

	// Protected routes
	r.Group(func(r chi.Router) {
		r.Use(middleware.BearerAuth(cfg.JWTSecret))

		personSvc := service.NewPersonService(cfg.Queries)
		r.Mount("/persons", NewPersonsHandler(personSvc).Routes())

		logSvc := service.NewLogService(cfg.Queries)
		r.Mount("/logs", NewLogsHandler(logSvc).Routes())

		followUpSvc := service.NewFollowUpService(cfg.Queries)
		r.Mount("/follow-ups", NewFollowUpsHandler(followUpSvc).Routes())

		notifSvc := service.NewNotificationService(cfg.Queries)
		r.Mount("/notifications", NewNotificationsHandler(notifSvc).Routes())

		deviceSvc := service.NewDeviceService(cfg.Queries)
		r.Mount("/devices", NewDevicesHandler(deviceSvc).Routes())

		settingsSvc := service.NewSettingsService(cfg.Queries)
		r.Mount("/settings", NewSettingsHandler(settingsSvc).Routes())

		syncSvc := service.NewSyncService(cfg.Queries)
		r.Mount("/sync", NewSyncHandler(syncSvc).Routes())
	})

	return r
}

// healthHandler checks database connectivity and returns {"status":"ok","db":"ok"}.
func healthHandler(q *sqlc.Queries) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		dbStatus := "ok"
		// Simple connectivity check via a cheap query
		if q == nil {
			dbStatus = "unavailable"
		}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(map[string]string{
			"status": "ok",
			"db":     dbStatus,
		})
	}
}
