BINARY=antra
BUILD_DIR=./bin
DB_URL=postgres://antra:antra@localhost:5432/antra?sslmode=disable

.PHONY: run worker build test dev db-up migrate-up migrate-down seed sqlc lint clean up down

## Start DB, run migrations, then run the API server locally
dev: db-up migrate-up
	env $$(cat .env | grep -v '^\s*#' | grep -v '^\s*$$' | xargs) go run ./cmd/api

## Start only the Postgres container and wait until healthy
db-up:
	docker compose up db -d
	@echo "Waiting for Postgres to be ready..."
	@until docker compose exec -T db pg_isready -U antra -d antra > /dev/null 2>&1; do sleep 1; done
	@echo "Postgres is ready."

## Run the API server locally (requires local PG and env vars already set)
run:
	go run ./cmd/api

## Run the worker process locally
worker:
	go run ./cmd/worker

## Build the binary
build:
	mkdir -p $(BUILD_DIR)
	go build -o $(BUILD_DIR)/$(BINARY) ./cmd/api

## Run all tests
test:
	go test ./... -v -timeout 120s

## Apply all pending goose migrations (against local DB)
migrate-up:
	go run github.com/pressly/goose/v3/cmd/goose@latest -dir ./internal/db/migrations postgres "$(DB_URL)" up

## Roll back last migration (against local DB)
migrate-down:
	go run github.com/pressly/goose/v3/cmd/goose@latest -dir ./internal/db/migrations postgres "$(DB_URL)" down

## Load seed data into the local DB
seed:
	env $$(cat .env | grep -v '^\s*#' | grep -v '^\s*$$' | xargs) go run ./cmd/api seed

## Regenerate sqlc query code
sqlc:
	sqlc generate

## Run golangci-lint
lint:
	golangci-lint run ./...

## Clean build artifacts
clean:
	rm -rf $(BUILD_DIR)

## Docker compose up with build
up:
	docker compose up --build

## Docker compose down
down:
	docker compose down
