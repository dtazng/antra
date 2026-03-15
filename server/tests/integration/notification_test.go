package integration

import (
	"context"
	"testing"
	"time"

	"github.com/duongta/antra-backend/internal/db/sqlc"
	"github.com/duongta/antra-backend/internal/push"
	"github.com/duongta/antra-backend/internal/service"
	"github.com/duongta/antra-backend/internal/worker"
	"github.com/duongta/antra-backend/tests/testutil"
	"github.com/google/uuid"
)

func newNotifSetup(t *testing.T) (*sqlc.Queries, uuid.UUID) {
	t.Helper()
	pool := testutil.NewTestDB(t)
	q := sqlc.New(pool)
	authSvc := service.NewAuthService(q).WithConfig(testJWTSecret, testAccessExpire, testRefreshDays)
	tokens, err := authSvc.Register(context.Background(), "notif@example.com", "password123")
	if err != nil {
		t.Fatalf("Register: %v", err)
	}
	userID, _ := parseJWT(tokens.AccessToken)
	return q, userID
}

// US4-AC1: Notification created when follow-up becomes due (tested in follow_up_test.go US3-AC5).
// US4-AC2: Notification dispatch updates status.
func TestNotification_Dispatch(t *testing.T) {
	q, userID := newNotifSetup(t)
	ctx := context.Background()

	// Create a notification manually
	_, err := q.CreateNotification(ctx, sqlc.CreateNotificationParams{
		UserID: userID,
		Title:  "Test Notification",
		Body:   "You have a follow-up due",
	})
	if err != nil {
		t.Fatalf("CreateNotification: %v", err)
	}

	// Run notification job with no-op push client (no Firebase credentials)
	pushClient, _ := push.NewFirebaseClient(ctx, "") // no-op
	worker.DispatchNotifications(ctx, q, pushClient)

	// Notification should be marked sent (no device tokens = sent with no deliveries)
	notifSvc := service.NewNotificationService(q)
	notifs, err := notifSvc.List(ctx, userID, 50, 0)
	if err != nil {
		t.Fatalf("List: %v", err)
	}
	if len(notifs) == 0 {
		t.Fatal("expected notifications")
	}
	if notifs[0].Status != "sent" {
		t.Errorf("expected status=sent, got %q", notifs[0].Status)
	}
}

// US4-AC3: GET /notifications inbox returns user's notifications.
func TestNotification_Inbox(t *testing.T) {
	q, userID := newNotifSetup(t)
	ctx := context.Background()

	// Create two notifications
	for i := 0; i < 2; i++ {
		_, _ = q.CreateNotification(ctx, sqlc.CreateNotificationParams{
			UserID: userID,
			Title:  "Inbox item",
			Body:   "Test",
		})
	}

	notifSvc := service.NewNotificationService(q)
	notifs, err := notifSvc.List(ctx, userID, 50, 0)
	if err != nil {
		t.Fatalf("List: %v", err)
	}
	if len(notifs) < 2 {
		t.Errorf("expected >= 2 notifications, got %d", len(notifs))
	}
}

// US4-AC4: Notifications suppressed when user has notifications disabled.
func TestNotification_Suppressed(t *testing.T) {
	q, userID := newNotifSetup(t)
	ctx := context.Background()

	// Disable notifications
	notifEnabled := false
	_, _ = q.UpdateUserSettings(ctx, sqlc.UpdateUserSettingsParams{
		UserID:               userID,
		NotificationsEnabled: &notifEnabled,
	})

	// Create a past-due follow-up and run job
	fuSvc := service.NewFollowUpService(q)
	_, _ = fuSvc.Create(ctx, userID, uuid.New(), nil, nil,
		"Suppressed follow-up", time.Now().AddDate(0, 0, -1), false, nil, nil)
	worker.CheckDueFollowUps(ctx, q)

	// No notifications should be created
	notifSvc := service.NewNotificationService(q)
	notifs, err := notifSvc.List(ctx, userID, 50, 0)
	if err != nil {
		t.Fatalf("List: %v", err)
	}
	if len(notifs) != 0 {
		t.Errorf("expected 0 notifications (disabled), got %d", len(notifs))
	}
}
