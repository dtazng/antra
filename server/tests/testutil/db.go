package testutil

import (
	"context"
	"database/sql"
	"path/filepath"
	"runtime"
	"testing"

	"github.com/jackc/pgx/v5/pgxpool"
	_ "github.com/jackc/pgx/v5/stdlib"
	"github.com/pressly/goose/v3"
	"github.com/testcontainers/testcontainers-go"
	tcpostgres "github.com/testcontainers/testcontainers-go/modules/postgres"
	"github.com/testcontainers/testcontainers-go/wait"
)

// NewTestDB starts a PostgreSQL container, runs all migrations, and returns a *pgxpool.Pool.
// Registers t.Cleanup to terminate the container and close the pool.
func NewTestDB(t *testing.T) *pgxpool.Pool {
	t.Helper()
	ctx := context.Background()

	pgContainer, err := tcpostgres.RunContainer(ctx,
		testcontainers.WithImage("postgres:16-alpine"),
		tcpostgres.WithDatabase("antra_test"),
		tcpostgres.WithUsername("antra"),
		tcpostgres.WithPassword("antra"),
		testcontainers.WithWaitStrategy(
			wait.ForLog("database system is ready to accept connections").WithOccurrence(2),
		),
	)
	if err != nil {
		t.Fatalf("start postgres container: %v", err)
	}

	connStr, err := pgContainer.ConnectionString(ctx, "sslmode=disable")
	if err != nil {
		_ = pgContainer.Terminate(ctx)
		t.Fatalf("get connection string: %v", err)
	}

	// Run goose migrations via database/sql + pgx stdlib driver
	_, currentFile, _, _ := runtime.Caller(0)
	repoRoot := filepath.Join(filepath.Dir(currentFile), "../..")
	migrationsDir := filepath.Join(repoRoot, "internal/db/migrations")

	sqlDB, err := sql.Open("pgx", connStr)
	if err != nil {
		_ = pgContainer.Terminate(ctx)
		t.Fatalf("open sql.DB: %v", err)
	}
	if err := goose.Up(sqlDB, migrationsDir); err != nil {
		_ = sqlDB.Close()
		_ = pgContainer.Terminate(ctx)
		t.Fatalf("goose up: %v", err)
	}
	_ = sqlDB.Close()

	// Create pgxpool for actual queries
	pool, err := pgxpool.New(ctx, connStr)
	if err != nil {
		_ = pgContainer.Terminate(ctx)
		t.Fatalf("pgxpool.New: %v", err)
	}

	t.Cleanup(func() {
		pool.Close()
		if err := pgContainer.Terminate(ctx); err != nil {
			t.Logf("terminate container: %v", err)
		}
	})

	return pool
}
