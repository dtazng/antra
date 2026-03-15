# Research: 015-Go Backend with PostgreSQL

**Date**: 2026-03-15
**Feature**: Go containerized backend replacing AWS Lambda + DynamoDB

---

## Decision 1 — HTTP Router: chi

**Decision**: Use `go-chi/chi v5` for routing.

**Rationale**: chi is built on `net/http` primitives and uses standard `http.Handler` interfaces, making it compatible with any standard-library middleware. Its sub-router pattern makes `/v1` versioning clean. At <100 users, gin's performance advantage is irrelevant and its custom `Context` type breaks standard handler compatibility.

**Alternatives considered**:
- gin: faster benchmarks but custom Context type; not justified at this scale.
- gorilla/mux: unmaintained since 2022, effectively deprecated.
- stdlib net/http alone: verbose route matching without parameter extraction.

---

## Decision 2 — PostgreSQL driver: pgx/v5 native API

**Decision**: Use `jackc/pgx/v5` directly (not via `database/sql` adapter).

**Rationale**: pgx/v5's native API exposes PostgreSQL-specific types, batch queries, and `pgxscan` for struct scanning. For a solo maintainer writing explicit SQL, the direct API is less code per query than `database/sql + sqlx`, with better error messages and native type support (UUIDs, timestamps with timezone).

**Alternatives considered**:
- database/sql + pgx stdlib adapter: adds indirection that loses pgx features with no benefit.
- sqlx: built on database/sql, maintenance-only mode since ~2021.

---

## Decision 3 — SQL codegen: sqlc

**Decision**: Use `sqlc` for type-safe query generation from `.sql` files.

**Rationale**: sqlc generates typed Go functions from plain SQL, so SQL stays readable and auditable while eliminating hand-written scan boilerplate. With 30+ queries across 11 tables, manual `Row.Scan` calls become hundreds of lines prone to column-order bugs. sqlc workflow: write SQL → `sqlc generate` → call typed functions.

**Alternatives considered**:
- Raw pgx queries manually: viable but excessive boilerplate at this scale.
- GORM/ent: full ORMs that hide SQL, complicating debugging.

---

## Decision 4 — Database migrations: goose

**Decision**: Use `pressly/goose v3` for schema migrations.

**Rationale**: goose uses numbered `.sql` files applied in order — the simplest possible mental model. Single CLI (`goose up`, `goose down`). No DSL, no configuration schema. For one developer, the simplicity advantage over atlas or golang-migrate is significant.

**Alternatives considered**:
- golang-migrate: similar but weaker CLI ergonomics and v4 module path confusion.
- atlas: powerful for teams with CI but overengineered for a solo project (HCL DSL, cloud features).

---

## Decision 5 — JWT library: golang-jwt/jwt v5

**Decision**: Use `golang-jwt/jwt v5` for HS256 access tokens. Refresh tokens are opaque UUIDs stored in the database.

**Rationale**: golang-jwt/jwt v5 is the maintained fork of the ubiquitous dgrijalva/jwt-go. Minimal API: `Parse`, `NewWithClaims`, `SignedString`. Three lines of code for HS256. lestrrat-go/jwx covers JWK/JWE/JWS which are unused complexity for HS256-only tokens.

**Alternatives considered**:
- lestrrat-go/jwx v2: comprehensive but much larger API surface; overkill for HS256.
- paseto: changes token format with no ecosystem benefit for mobile apps expecting JWTs.

---

## Decision 6 — Password hashing: argon2id

**Decision**: Use `golang.org/x/crypto/argon2` with argon2id variant.

**Rationale**: Argon2id is the OWASP-recommended algorithm (PHC winner). Memory-hard by design, resistant to GPU/ASIC attacks. Available in the standard extended library with the same single-function call pattern as bcrypt. New Go backends in 2025 should prefer argon2id.

**Alternatives considered**:
- bcrypt via golang.org/x/crypto/bcrypt: still secure but fixed-memory makes it weaker against GPU attacks.
- scrypt: also memory-hard but argon2id is preferred by current standards bodies.

---

## Decision 7 — Background scheduler: robfig/cron v3

**Decision**: Use `robfig/cron v3` for the worker process.

**Rationale**: robfig/cron v3 is the de facto Go cron standard. Handles 2 periodic jobs with `@every 5m` syntax, runs in-process with no external dependencies, includes built-in error recovery and graceful shutdown. A raw `time.Ticker` goroutine would require manually reimplementing this scaffolding.

**Alternatives considered**:
- time.Ticker in goroutine: works for a single loop; managing two jobs + panics + shutdown becomes boilerplate.
- gocron v2: feature-rich (distributed locks) but adds API surface for only 2 jobs.

---

## Decision 8 — Push notifications: firebase-admin-go SDK

**Decision**: Use `firebase.google.com/go/v4` (firebase-admin-go) for FCM + APNs delivery.

**Rationale**: The official SDK wraps FCM v1 HTTP, handles OAuth2 token refresh automatically, and supports both Android and APNs-via-FCM in a unified call. Direct HTTP requires manually implementing OAuth2 token management — non-trivial maintenance for solo development.

**Alternatives considered**:
- Direct FCM v1 HTTP calls: full control but requires OAuth2 client credentials flow and token caching.
- apns-go + FCM separately: unnecessary split when FCM v1 bridges to APNs natively.

---

## Decision 9 — Structured logging: log/slog (stdlib)

**Decision**: Use `log/slog` (Go 1.21+ standard library).

**Rationale**: `slog` provides structured JSON logging without any external dependency. Go 1.21 was released August 2023 and is the minimum version for this project. No need for zerolog/zap at this scale — slog is simpler and in the standard library.

**Alternatives considered**:
- zerolog: faster but external dependency not justified at this scale.
- zap: powerful but complex API for a solo project.

---

## Decision 10 — Configuration: environment variables via os.Getenv + config struct

**Decision**: Load config from environment variables into a `Config` struct at startup using `os.Getenv` with defaults. No external config library.

**Rationale**: Standard library `os.Getenv` with a typed `Config` struct is explicit, zero-dependency, and readable. The twelve-factor app pattern doesn't require a library. viper adds reflection-based magic for no real benefit at this scale.

**Alternatives considered**:
- viper: comprehensive but heavy; reflection-based with surprising behavior.
- godotenv: useful for local `.env` file loading; can be optionally added for local dev only.

---

## Go Module Path

`github.com/antra/backend` (or `github.com/duongta/antra-backend`). Exact path decided at project init.
