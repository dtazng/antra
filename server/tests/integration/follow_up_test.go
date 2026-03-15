package integration

import (
	"context"
	"testing"
	"time"

	"github.com/duongta/antra-backend/internal/db/sqlc"
	"github.com/duongta/antra-backend/internal/service"
	"github.com/duongta/antra-backend/internal/worker"
	"github.com/duongta/antra-backend/tests/testutil"
	"github.com/google/uuid"
)

func newFollowUpSetup(t *testing.T) (*sqlc.Queries, uuid.UUID) {
	t.Helper()
	pool := testutil.NewTestDB(t)
	q := sqlc.New(pool)
	authSvc := service.NewAuthService(q).WithConfig(testJWTSecret, testAccessExpire, testRefreshDays)
	tokens, err := authSvc.Register(context.Background(), "fu@example.com", "password123")
	if err != nil {
		t.Fatalf("Register: %v", err)
	}
	userID, err := parseUserIDFromJWT(tokens.AccessToken)
	if err != nil {
		t.Fatalf("parse user ID: %v", err)
	}
	return q, userID
}

// US3-AC1: Past-due follow-up marked due by job.
func TestFollowUpJob_MarksDue(t *testing.T) {
	q, userID := newFollowUpSetup(t)
	ctx := context.Background()

	fuSvc := service.NewFollowUpService(q)
	fu, err := fuSvc.Create(ctx, userID, uuid.New(), nil, nil,
		"Check in with client", time.Now().AddDate(0, 0, -1), false, nil, nil)
	if err != nil {
		t.Fatalf("Create follow-up: %v", err)
	}
	if fu.Status != "pending" {
		t.Errorf("expected status=pending, got %q", fu.Status)
	}

	// Run the job
	worker.CheckDueFollowUps(ctx, q)

	// Re-fetch
	updated, err := fuSvc.Get(ctx, userID, fu.ID)
	if err != nil {
		t.Fatalf("Get follow-up: %v", err)
	}
	if updated.Status != "due" {
		t.Errorf("expected status=due after job, got %q", updated.Status)
	}
}

// US3-AC2: Snooze a due follow-up.
func TestFollowUp_Snooze(t *testing.T) {
	q, userID := newFollowUpSetup(t)
	ctx := context.Background()

	fuSvc := service.NewFollowUpService(q)
	fu, _ := fuSvc.Create(ctx, userID, uuid.New(), nil, nil,
		"Snooze test", time.Now().AddDate(0, 0, -1), false, nil, nil)

	worker.CheckDueFollowUps(ctx, q)

	snoozedUntil := time.Now().AddDate(0, 0, 7)
	status := "snoozed"
	updated, err := fuSvc.Update(ctx, userID, fu.ID, nil, nil, &snoozedUntil, nil, &status)
	if err != nil {
		t.Fatalf("Update (snooze): %v", err)
	}
	if updated.Status != "snoozed" {
		t.Errorf("expected status=snoozed, got %q", updated.Status)
	}
}

// US3-AC3: Complete a follow-up sets completed_at.
func TestFollowUp_Complete(t *testing.T) {
	q, userID := newFollowUpSetup(t)
	ctx := context.Background()

	fuSvc := service.NewFollowUpService(q)
	fu, _ := fuSvc.Create(ctx, userID, uuid.New(), nil, nil,
		"Complete test", time.Now().AddDate(0, 0, -1), false, nil, nil)

	worker.CheckDueFollowUps(ctx, q)

	status := "completed"
	now := time.Now()
	updated, err := fuSvc.Update(ctx, userID, fu.ID, nil, nil, nil, &now, &status)
	if err != nil {
		t.Fatalf("Update (complete): %v", err)
	}
	if updated.Status != "completed" {
		t.Errorf("expected status=completed, got %q", updated.Status)
	}
	if updated.CompletedAt == nil {
		t.Error("expected completed_at to be set")
	}
}

// US3-AC4: Recurring follow-up creates next one when job runs.
func TestFollowUp_Recurring(t *testing.T) {
	q, userID := newFollowUpSetup(t)
	ctx := context.Background()

	fuSvc := service.NewFollowUpService(q)
	interval := int32(7)
	recType := "interval"
	fu, _ := fuSvc.Create(ctx, userID, uuid.New(), nil, nil,
		"Weekly recurring", time.Now().AddDate(0, 0, -1), true, &interval, &recType)

	// Job should mark due AND create next occurrence
	worker.CheckDueFollowUps(ctx, q)

	// List should have >= 2 items (original + next)
	all, err := fuSvc.List(ctx, userID, "", 50, 0)
	if err != nil {
		t.Fatalf("List follow-ups: %v", err)
	}
	// Find the new occurrence (different from original ID)
	found := false
	for _, f := range all {
		if f.ID != fu.ID && f.Title == fu.Title && f.IsRecurring {
			found = true
		}
	}
	if !found {
		t.Error("expected new recurring follow-up to be created")
	}
}

// US3-AC5: Notification created for due follow-up if notifications enabled.
func TestFollowUp_NotificationCreated(t *testing.T) {
	q, userID := newFollowUpSetup(t)
	ctx := context.Background()

	// Ensure notifications are enabled (default is true)
	_, _ = q.GetOrCreateUserSettings(ctx, userID)

	fuSvc := service.NewFollowUpService(q)
	_, _ = fuSvc.Create(ctx, userID, uuid.New(), nil, nil,
		"Notify test", time.Now().AddDate(0, 0, -1), false, nil, nil)

	worker.CheckDueFollowUps(ctx, q)

	// Check notification was created
	notifSvc := service.NewNotificationService(q)
	notifs, err := notifSvc.List(ctx, userID, 50, 0)
	if err != nil {
		t.Fatalf("List notifications: %v", err)
	}
	if len(notifs) == 0 {
		t.Error("expected notification to be created for due follow-up")
	}
}

func parseUserIDFromJWT(accessToken string) (uuid.UUID, error) {
	return parseJWT(accessToken)
}
