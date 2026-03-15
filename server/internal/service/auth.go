package service

import (
	"context"
	"errors"
	"time"

	"github.com/duongta/antra-backend/internal/db/sqlc"
	"github.com/duongta/antra-backend/internal/token"
	"github.com/google/uuid"
)

// ErrEmailTaken is returned when registration fails due to a duplicate email.
var ErrEmailTaken = errors.New("email already registered")

// ErrInvalidCredentials is returned on login failure.
var ErrInvalidCredentials = errors.New("invalid credentials")

// ErrNotFound is returned when a resource is not found.
var ErrNotFound = errors.New("not found")

// AuthTokens holds the tokens returned after auth operations.
type AuthTokens struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
	TokenType    string `json:"token_type"`
	UserID       string `json:"user_id"`
	Email        string `json:"email"`
	ExpiresIn    int    `json:"expires_in"` // seconds
}

// AuthService handles authentication business logic.
type AuthService struct {
	q             *sqlc.Queries
	jwtSecret     string
	accessExpire  int
	refreshExpire int
}

func NewAuthService(q *sqlc.Queries) *AuthService {
	return &AuthService{q: q}
}

// WithConfig sets the JWT configuration on the service.
func (s *AuthService) WithConfig(jwtSecret string, accessExpireMinutes, refreshExpireDays int) *AuthService {
	s.jwtSecret = jwtSecret
	s.accessExpire = accessExpireMinutes
	s.refreshExpire = refreshExpireDays
	return s
}

// Register creates a new user and returns auth tokens.
func (s *AuthService) Register(ctx context.Context, email, password string) (*AuthTokens, error) {
	hash, err := token.HashPassword(password)
	if err != nil {
		return nil, err
	}

	user, err := s.q.CreateUser(ctx, sqlc.CreateUserParams{
		Email:        email,
		PasswordHash: hash,
	})
	if err != nil {
		// Duplicate email (unique constraint violation)
		if isDuplicateKeyError(err) {
			return nil, ErrEmailTaken
		}
		return nil, err
	}

	// Auto-create user settings
	_, _ = s.q.GetOrCreateUserSettings(ctx, user.ID)

	return s.issueTokens(ctx, user.ID, user.Email)
}

// Login verifies credentials and returns auth tokens.
func (s *AuthService) Login(ctx context.Context, email, password string) (*AuthTokens, error) {
	user, err := s.q.GetUserByEmail(ctx, email)
	if err != nil {
		return nil, ErrInvalidCredentials
	}
	if !token.VerifyPassword(password, user.PasswordHash) {
		return nil, ErrInvalidCredentials
	}
	return s.issueTokens(ctx, user.ID, user.Email)
}

// Refresh exchanges a refresh token for a new access token.
func (s *AuthService) Refresh(ctx context.Context, refreshTokenID uuid.UUID) (string, error) {
	rt, err := s.q.GetRefreshToken(ctx, refreshTokenID)
	if err != nil {
		return "", ErrInvalidCredentials
	}
	accessToken, err := token.CreateAccessToken(rt.UserID, s.jwtSecret, s.accessExpire)
	if err != nil {
		return "", err
	}
	return accessToken, nil
}

// Logout deletes the refresh token (invalidates session).
func (s *AuthService) Logout(ctx context.Context, refreshTokenID uuid.UUID) error {
	return s.q.DeleteRefreshToken(ctx, refreshTokenID)
}

// DeleteAccount soft-deletes the user.
func (s *AuthService) DeleteAccount(ctx context.Context, userID uuid.UUID) error {
	return s.q.SoftDeleteUser(ctx, userID)
}

// issueTokens creates a refresh token in the DB and a signed JWT.
func (s *AuthService) issueTokens(ctx context.Context, userID uuid.UUID, email string) (*AuthTokens, error) {
	accessToken, err := token.CreateAccessToken(userID, s.jwtSecret, s.accessExpire)
	if err != nil {
		return nil, err
	}

	refreshID := uuid.New()
	expiresAt := time.Now().Add(time.Duration(s.refreshExpire) * 24 * time.Hour)
	_, err = s.q.CreateRefreshToken(ctx, sqlc.CreateRefreshTokenParams{
		ID:        refreshID,
		UserID:    userID,
		ExpiresAt: expiresAt,
	})
	if err != nil {
		return nil, err
	}

	return &AuthTokens{
		AccessToken:  accessToken,
		RefreshToken: refreshID.String(),
		TokenType:    "bearer",
		UserID:       userID.String(),
		Email:        email,
		ExpiresIn:    s.accessExpire * 60,
	}, nil
}

// isDuplicateKeyError checks if an error is a PostgreSQL unique violation.
func isDuplicateKeyError(err error) bool {
	if err == nil {
		return false
	}
	return containsAny(err.Error(), "23505", "duplicate key", "unique constraint")
}

func containsAny(s string, subs ...string) bool {
	for _, sub := range subs {
		if len(s) >= len(sub) {
			for i := 0; i <= len(s)-len(sub); i++ {
				if s[i:i+len(sub)] == sub {
					return true
				}
			}
		}
	}
	return false
}

// ErrPasswordTooShort is returned when a new password is too short.
var ErrPasswordTooShort = errors.New("password must be at least 8 characters")

// ChangePassword verifies the current password, hashes the new one, persists it,
// and invalidates all refresh tokens (forces re-login on other devices).
func (s *AuthService) ChangePassword(ctx context.Context, userID uuid.UUID, currentPassword, newPassword string) error {
	if len(newPassword) < 8 {
		return ErrPasswordTooShort
	}

	user, err := s.q.GetUserByID(ctx, userID)
	if err != nil {
		return ErrInvalidCredentials
	}

	if !token.VerifyPassword(currentPassword, user.PasswordHash) {
		return ErrInvalidCredentials
	}

	hash, err := token.HashPassword(newPassword)
	if err != nil {
		return err
	}

	_, err = s.q.UpdateUserPasswordHash(ctx, sqlc.UpdateUserPasswordHashParams{
		ID:           userID,
		PasswordHash: hash,
	})
	if err != nil {
		return err
	}

	return s.q.DeleteAllUserRefreshTokens(ctx, userID)
}
