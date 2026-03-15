package worker

import (
	"context"
	"log/slog"

	"github.com/duongta/antra-backend/internal/config"
	"github.com/duongta/antra-backend/internal/db/sqlc"
	"github.com/duongta/antra-backend/internal/push"
	"github.com/google/uuid"
	"github.com/robfig/cron/v3"
)

// Scheduler wraps robfig/cron with the worker jobs.
type Scheduler struct {
	c          *cron.Cron
	q          *sqlc.Queries
	pushClient *push.Client
}

// NewScheduler creates a scheduler and wires up the Firebase push client.
func NewScheduler(q *sqlc.Queries, cfg *config.Config) *Scheduler {
	pushClient, err := push.NewFirebaseClient(context.Background(), cfg.FirebaseCredentialsJSON)
	if err != nil {
		slog.Error("failed to init Firebase client", "error", err)
		pushClient = &push.Client{}
	}
	return &Scheduler{
		c:          cron.New(),
		q:          q,
		pushClient: pushClient,
	}
}

// Start registers jobs and starts the cron scheduler.
func (s *Scheduler) Start() {
	_, _ = s.c.AddFunc("@every 5m", func() {
		CheckDueFollowUps(context.Background(), s.q)
	})
	_, _ = s.c.AddFunc("@every 5m", func() {
		DispatchNotifications(context.Background(), s.q, s.pushClient)
	})
	s.c.Start()
	slog.Info("scheduler started", "jobs", 2)
}

// Stop gracefully stops the scheduler.
func (s *Scheduler) Stop() {
	ctx := s.c.Stop()
	<-ctx.Done()
	slog.Info("scheduler stopped")
}

// newUUID is a helper for worker jobs to generate UUIDs.
func newUUID() uuid.UUID {
	return uuid.New()
}
