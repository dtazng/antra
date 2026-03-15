package integration

import (
	"context"
	"testing"

	"github.com/duongta/antra-backend/internal/db/sqlc"
	"github.com/duongta/antra-backend/internal/service"
	"github.com/duongta/antra-backend/tests/testutil"
	"github.com/google/uuid"
)

const (
	testJWTSecret    = "test-secret-key-for-integration-tests-min-32"
	testAccessExpire = 15
	testRefreshDays  = 30
)

func newAuthService(t *testing.T) (*service.AuthService, *sqlc.Queries) {
	t.Helper()
	pool := testutil.NewTestDB(t)
	q := sqlc.New(pool)
	svc := service.NewAuthService(q).WithConfig(testJWTSecret, testAccessExpire, testRefreshDays)
	return svc, q
}

// US1-AC1: Register creates a user and returns tokens.
func TestRegister(t *testing.T) {
	svc, _ := newAuthService(t)
	ctx := context.Background()

	tokens, err := svc.Register(ctx, "test@example.com", "password123")
	if err != nil {
		t.Fatalf("Register: %v", err)
	}
	if tokens.AccessToken == "" {
		t.Error("expected non-empty access_token")
	}
	if tokens.RefreshToken == "" {
		t.Error("expected non-empty refresh_token")
	}
	if tokens.TokenType != "bearer" {
		t.Errorf("expected token_type=bearer, got %q", tokens.TokenType)
	}
}

// US1-AC2: Duplicate email returns ErrEmailTaken.
func TestRegister_DuplicateEmail(t *testing.T) {
	svc, _ := newAuthService(t)
	ctx := context.Background()

	if _, err := svc.Register(ctx, "dup@example.com", "password123"); err != nil {
		t.Fatalf("first Register: %v", err)
	}
	_, err := svc.Register(ctx, "dup@example.com", "password123")
	if err != service.ErrEmailTaken {
		t.Errorf("expected ErrEmailTaken, got %v", err)
	}
}

// US1-AC3: Login with valid credentials returns tokens.
func TestLogin(t *testing.T) {
	svc, _ := newAuthService(t)
	ctx := context.Background()

	if _, err := svc.Register(ctx, "login@example.com", "password123"); err != nil {
		t.Fatalf("Register: %v", err)
	}
	tokens, err := svc.Login(ctx, "login@example.com", "password123")
	if err != nil {
		t.Fatalf("Login: %v", err)
	}
	if tokens.AccessToken == "" {
		t.Error("expected access_token")
	}
}

// US1-AC4: Login with wrong password returns ErrInvalidCredentials.
func TestLogin_WrongPassword(t *testing.T) {
	svc, _ := newAuthService(t)
	ctx := context.Background()

	_, _ = svc.Register(ctx, "creds@example.com", "password123")
	_, err := svc.Login(ctx, "creds@example.com", "wrongpassword")
	if err != service.ErrInvalidCredentials {
		t.Errorf("expected ErrInvalidCredentials, got %v", err)
	}
}

// US1-AC5: Refresh returns a new access token.
func TestRefreshToken(t *testing.T) {
	svc, _ := newAuthService(t)
	ctx := context.Background()

	tokens, err := svc.Register(ctx, "refresh@example.com", "password123")
	if err != nil {
		t.Fatalf("Register: %v", err)
	}
	refreshID, err := uuid.Parse(tokens.RefreshToken)
	if err != nil {
		t.Fatalf("parse refresh token: %v", err)
	}
	newToken, err := svc.Refresh(ctx, refreshID)
	if err != nil {
		t.Fatalf("Refresh: %v", err)
	}
	if newToken == "" {
		t.Error("expected new access_token")
	}
}

// US1-AC6: Logout invalidates the refresh token.
func TestLogout(t *testing.T) {
	svc, _ := newAuthService(t)
	ctx := context.Background()

	tokens, err := svc.Register(ctx, "logout@example.com", "password123")
	if err != nil {
		t.Fatalf("Register: %v", err)
	}
	refreshID, _ := uuid.Parse(tokens.RefreshToken)

	if err := svc.Logout(ctx, refreshID); err != nil {
		t.Fatalf("Logout: %v", err)
	}
	_, err = svc.Refresh(ctx, refreshID)
	if err == nil {
		t.Error("expected error refreshing after logout, got nil")
	}
}
