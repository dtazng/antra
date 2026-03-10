// Package auth provides Cognito JWT verification for Lambda handlers.
package auth

import (
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/MicahParks/keyfunc/v3"
	"github.com/golang-jwt/jwt/v5"
)

// KeyfuncProvider abstracts JWT key lookup to allow test injection.
type KeyfuncProvider interface {
	Keyfunc(token *jwt.Token) (any, error)
}

var defaultProvider KeyfuncProvider

// SetJWKSURL initialises the JWKS key provider from a remote Cognito URL.
// Must be called once during Lambda init before any VerifyCognitoJWT call.
func SetJWKSURL(url string) error {
	kf, err := keyfunc.Get(url, keyfunc.Options{
		RefreshInterval: time.Hour,
	})
	if err != nil {
		return fmt.Errorf("keyfunc.Get: %w", err)
	}
	defaultProvider = kf
	return nil
}

// SetKeyProvider overrides the key provider. Used in unit tests.
func SetKeyProvider(p KeyfuncProvider) {
	defaultProvider = p
}

// VerifyCognitoJWT validates an Authorization header (Bearer <token>) and
// returns the Cognito sub claim (user ID) on success.
func VerifyCognitoJWT(authHeader string) (string, error) {
	if authHeader == "" {
		return "", errors.New("missing Authorization header")
	}
	tokenStr := strings.TrimPrefix(authHeader, "Bearer ")
	if tokenStr == authHeader {
		return "", errors.New("Authorization header must use Bearer scheme")
	}
	if defaultProvider == nil {
		return "", errors.New("key provider not initialised; call SetJWKSURL first")
	}

	token, err := jwt.Parse(tokenStr, defaultProvider.Keyfunc)
	if err != nil || !token.Valid {
		return "", fmt.Errorf("invalid token: %w", err)
	}

	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok {
		return "", errors.New("unexpected claims type")
	}
	sub, ok := claims["sub"].(string)
	if !ok || sub == "" {
		return "", errors.New("token missing sub claim")
	}
	return sub, nil
}
