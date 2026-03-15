package integration

import (
	"context"
	"encoding/json"
	"testing"
	"time"

	"github.com/duongta/antra-backend/internal/db/sqlc"
	"github.com/duongta/antra-backend/internal/service"
	"github.com/duongta/antra-backend/internal/token"
	"github.com/duongta/antra-backend/tests/testutil"
	"github.com/google/uuid"
)

func newSyncSetup(t *testing.T) (*sqlc.Queries, *service.AuthService, *service.SyncService) {
	t.Helper()
	pool := testutil.NewTestDB(t)
	q := sqlc.New(pool)
	authSvc := service.NewAuthService(q).WithConfig(testJWTSecret, testAccessExpire, testRefreshDays)
	syncSvc := service.NewSyncService(q)
	return q, authSvc, syncSvc
}

func registerAndGetUserID(t *testing.T, svc *service.AuthService, email string) uuid.UUID {
	t.Helper()
	ctx := context.Background()
	tokens, err := svc.Register(ctx, email, "password123")
	if err != nil {
		t.Fatalf("Register %s: %v", email, err)
	}
	userID, err := token.ParseAccessToken(tokens.AccessToken, testJWTSecret)
	if err != nil {
		t.Fatalf("ParseAccessToken: %v", err)
	}
	return userID
}

// US2-AC1: Push persons from device A, pull on device B.
func TestSync_PushAndPull(t *testing.T) {
	_, authSvc, syncSvc := newSyncSetup(t)
	ctx := context.Background()
	userID := registerAndGetUserID(t, authSvc, "sync1@example.com")

	personID := uuid.New()
	data, _ := json.Marshal(map[string]interface{}{"name": "Test Person", "notes": "from device A"})
	result, err := syncSvc.Push(ctx, userID, "persons", []service.SyncChange{
		{ID: personID, Operation: "upsert", UpdatedAt: time.Now(), Data: data},
	}, "device-A")
	if err != nil {
		t.Fatalf("Push: %v", err)
	}
	if result.Accepted != 1 {
		t.Errorf("expected accepted=1, got %d", result.Accepted)
	}

	// Pull from device B (epoch)
	pullResult, err := syncSvc.Pull(ctx, userID, "persons", time.Time{}, 200)
	if err != nil {
		t.Fatalf("Pull: %v", err)
	}
	if len(pullResult.Records) == 0 {
		t.Fatal("expected records from pull, got none")
	}
	found := false
	for _, r := range pullResult.Records {
		if r.ID == personID {
			found = true
		}
	}
	if !found {
		t.Errorf("person %s not found in pull result", personID)
	}
}

// US2-AC2: Push with stale updated_at returns conflict.
func TestSync_Conflict(t *testing.T) {
	_, authSvc, syncSvc := newSyncSetup(t)
	ctx := context.Background()
	userID := registerAndGetUserID(t, authSvc, "sync2@example.com")

	personID := uuid.New()
	now := time.Now()

	// Push fresh record
	data, _ := json.Marshal(map[string]interface{}{"name": "Server Name"})
	_, _ = syncSvc.Push(ctx, userID, "persons", []service.SyncChange{
		{ID: personID, Operation: "upsert", UpdatedAt: now, Data: data},
	}, "device-A")

	// Push stale version
	staleData, _ := json.Marshal(map[string]interface{}{"name": "Stale Name"})
	result, err := syncSvc.Push(ctx, userID, "persons", []service.SyncChange{
		{ID: personID, Operation: "upsert", UpdatedAt: now.Add(-time.Hour), Data: staleData},
	}, "device-B")
	if err != nil {
		t.Fatalf("Push: %v", err)
	}
	if result.Accepted != 0 {
		t.Errorf("expected accepted=0, got %d", result.Accepted)
	}
	if len(result.Conflicts) != 1 {
		t.Errorf("expected 1 conflict, got %d", len(result.Conflicts))
	}
	if result.Conflicts[0].Reason != "server_newer" {
		t.Errorf("expected reason=server_newer, got %q", result.Conflicts[0].Reason)
	}
}

// US2-AC3: First sync (epoch since) returns all records.
func TestSync_FirstSync(t *testing.T) {
	_, authSvc, syncSvc := newSyncSetup(t)
	ctx := context.Background()
	userID := registerAndGetUserID(t, authSvc, "sync3@example.com")

	for i := 0; i < 3; i++ {
		data, _ := json.Marshal(map[string]interface{}{"name": "Person"})
		_, _ = syncSvc.Push(ctx, userID, "persons", []service.SyncChange{
			{ID: uuid.New(), Operation: "upsert", UpdatedAt: time.Now(), Data: data},
		}, "device-A")
	}

	result, err := syncSvc.Pull(ctx, userID, "persons", time.Time{}, 200)
	if err != nil {
		t.Fatalf("Pull: %v", err)
	}
	if len(result.Records) < 3 {
		t.Errorf("expected >= 3 records, got %d", len(result.Records))
	}
}

// US2-AC4: Delete creates tombstone visible in subsequent pull.
func TestSync_Tombstone(t *testing.T) {
	_, authSvc, syncSvc := newSyncSetup(t)
	ctx := context.Background()
	userID := registerAndGetUserID(t, authSvc, "sync4@example.com")

	personID := uuid.New()
	now := time.Now()

	data, _ := json.Marshal(map[string]interface{}{"name": "To Delete"})
	_, _ = syncSvc.Push(ctx, userID, "persons", []service.SyncChange{
		{ID: personID, Operation: "upsert", UpdatedAt: now, Data: data},
	}, "device-A")

	_, _ = syncSvc.Push(ctx, userID, "persons", []service.SyncChange{
		{ID: personID, Operation: "delete", UpdatedAt: now.Add(time.Second)},
	}, "device-A")

	result, err := syncSvc.Pull(ctx, userID, "persons", time.Time{}, 200)
	if err != nil {
		t.Fatalf("Pull: %v", err)
	}
	for _, r := range result.Records {
		if r.ID == personID {
			if r.DeletedAt == nil {
				t.Error("expected deleted_at set for tombstone")
			}
			if r.Data != nil {
				t.Error("expected data=null for tombstone")
			}
			return
		}
	}
	t.Errorf("tombstone for %s not found in pull result", personID)
}

// US2-AC5: Pull with since returns only newer records.
func TestSync_PullSince(t *testing.T) {
	_, authSvc, syncSvc := newSyncSetup(t)
	ctx := context.Background()
	userID := registerAndGetUserID(t, authSvc, "sync5@example.com")

	// Push one record and capture server timestamp
	data, _ := json.Marshal(map[string]interface{}{"name": "Old Person"})
	firstResult, _ := syncSvc.Push(ctx, userID, "persons", []service.SyncChange{
		{ID: uuid.New(), Operation: "upsert", UpdatedAt: time.Now(), Data: data},
	}, "device-A")

	since := firstResult.ServerTimestamp

	// Push another record after the cursor
	time.Sleep(10 * time.Millisecond) // ensure updated_at is strictly after since
	newID := uuid.New()
	data2, _ := json.Marshal(map[string]interface{}{"name": "New Person"})
	_, _ = syncSvc.Push(ctx, userID, "persons", []service.SyncChange{
		{ID: newID, Operation: "upsert", UpdatedAt: time.Now(), Data: data2},
	}, "device-A")

	result, err := syncSvc.Pull(ctx, userID, "persons", since, 200)
	if err != nil {
		t.Fatalf("Pull: %v", err)
	}
	for _, r := range result.Records {
		if r.ID == newID {
			return
		}
	}
	t.Error("expected new record in pull-since result")
}
