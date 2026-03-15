# ── Stage 1: builder ────────────────────────────────────────────────────────
FROM golang:1.23-alpine AS builder

WORKDIR /build

# Install build dependencies
RUN apk add --no-cache git ca-certificates tzdata

# Download dependencies first (layer cache)
COPY go.mod go.sum ./
RUN go mod download

# Copy source and build
COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -ldflags="-w -s" -o /build/antra ./cmd/api

# ── Stage 2: runtime ────────────────────────────────────────────────────────
FROM gcr.io/distroless/static-debian12:nonroot

WORKDIR /app

# Copy binary and CA certs from builder
COPY --from=builder /build/antra /app/antra
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo

# Copy migrations so goose can run inside container
COPY --from=builder /build/internal/db/migrations /app/internal/db/migrations

EXPOSE 8000

ENTRYPOINT ["/app/antra"]
CMD ["api"]
