package config

import (
	"fmt"
	"os"
	"strconv"
)

// Config holds all configuration loaded from environment variables.
type Config struct {
	DatabaseURL              string
	JWTSecretKey             string
	AccessExpireMinutes      int
	RefreshExpireDays        int
	FirebaseCredentialsJSON  string
	Environment              string
	Port                     string
}

// Load reads environment variables and returns a Config.
// Required fields: DATABASE_URL, JWT_SECRET_KEY.
func Load() (*Config, error) {
	c := &Config{
		DatabaseURL:             requireEnv("DATABASE_URL"),
		JWTSecretKey:            requireEnv("JWT_SECRET_KEY"),
		AccessExpireMinutes:     envInt("JWT_ACCESS_EXPIRE_MINUTES", 15),
		RefreshExpireDays:       envInt("JWT_REFRESH_EXPIRE_DAYS", 30),
		FirebaseCredentialsJSON: os.Getenv("FIREBASE_CREDENTIALS_JSON"),
		Environment:             envStr("ENVIRONMENT", "local"),
		Port:                    envStr("PORT", "8000"),
	}

	if c.DatabaseURL == "" {
		return nil, fmt.Errorf("DATABASE_URL is required")
	}
	if c.JWTSecretKey == "" {
		return nil, fmt.Errorf("JWT_SECRET_KEY is required")
	}

	return c, nil
}

func requireEnv(key string) string {
	return os.Getenv(key)
}

func envStr(key, defaultVal string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return defaultVal
}

func envInt(key string, defaultVal int) int {
	if v := os.Getenv(key); v != "" {
		if i, err := strconv.Atoi(v); err == nil {
			return i
		}
	}
	return defaultVal
}
