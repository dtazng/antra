BINARY=antra
BUILD_DIR=./bin

.PHONY: run worker build test migrate-up migrate-down seed sqlc lint clean

## Run the API server locally (requires local PG)
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

## Apply all pending goose migrations
migrate-up:
	docker compose exec api goose -dir ./internal/db/migrations postgres "$$DATABASE_URL" up

## Roll back last migration
migrate-down:
	docker compose exec api goose -dir ./internal/db/migrations postgres "$$DATABASE_URL" down

## Load seed data
seed:
	docker compose exec api ./antra seed

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
