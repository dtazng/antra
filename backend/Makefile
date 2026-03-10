.PHONY: build test clean dev

build:
	GOOS=linux GOARCH=arm64 CGO_ENABLED=0 \
	  go build -o dist/pull_sync/bootstrap ./cmd/pull_sync
	GOOS=linux GOARCH=arm64 CGO_ENABLED=0 \
	  go build -o dist/push_sync/bootstrap ./cmd/push_sync

# Start the local dev server (no AWS credentials needed).
# The Flutter app should point its API base URL to http://localhost:3001.
dev:
	go run ./cmd/localserver

test:
	go test ./...

clean:
	rm -rf dist/
