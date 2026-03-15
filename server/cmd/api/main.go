package main

import (
	"context"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/duongta/antra-backend/internal/api/v1"
	"github.com/duongta/antra-backend/internal/config"
	"github.com/duongta/antra-backend/internal/db"
	"github.com/duongta/antra-backend/internal/db/sqlc"
	"github.com/duongta/antra-backend/internal/seed"
)

func main() {
	// Structured JSON logging
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	slog.SetDefault(logger)

	// Load configuration
	cfg, err := config.Load()
	if err != nil {
		slog.Error("failed to load config", "error", err)
		os.Exit(1)
	}

	// Connect to database
	ctx := context.Background()
	pool, err := db.NewPool(ctx, cfg.DatabaseURL)
	if err != nil {
		slog.Error("failed to connect to database", "error", err)
		os.Exit(1)
	}
	defer pool.Close()

	queries := sqlc.New(pool)

	// Check for subcommand
	if len(os.Args) > 1 && os.Args[1] == "seed" {
		if err := seed.Run(ctx, queries); err != nil {
			slog.Error("seed failed", "error", err)
			os.Exit(1)
		}
		return
	}

	// Build HTTP router
	router := v1.NewRouter(v1.Config{
		Queries:             queries,
		JWTSecret:           cfg.JWTSecretKey,
		AccessExpireMinutes: cfg.AccessExpireMinutes,
		RefreshExpireDays:   cfg.RefreshExpireDays,
	})

	// HTTP server
	srv := &http.Server{
		Addr:         ":" + cfg.Port,
		Handler:      router,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	// Start server in goroutine
	go func() {
		slog.Info("API server starting", "port", cfg.Port, "env", cfg.Environment)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			slog.Error("server error", "error", err)
			os.Exit(1)
		}
	}()

	// Graceful shutdown on SIGTERM / SIGINT
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGTERM, syscall.SIGINT)
	<-quit
	slog.Info("shutting down server...")

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	if err := srv.Shutdown(shutdownCtx); err != nil {
		slog.Error("forced shutdown", "error", err)
	}
	slog.Info("server stopped")
}
