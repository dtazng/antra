// Package main provides a local HTTP server that mimics the Antra sync API
// (POST /sync/pull and POST /sync/push) for development without AWS.
//
// Usage:
//
//	go run ./cmd/localserver          # listens on :3001
//	go run ./cmd/localserver -port 8080
//
// Auth: any non-empty Authorization header is accepted; the user-ID is derived
// from it directly (useful for mocking multiple users).
package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"net/http"
	"sync"
	"time"

	"antra/backend/internal/syncrecord"
)

// ─── In-memory store ──────────────────────────────────────────────────────────

type store struct {
	mu      sync.RWMutex
	records map[string]syncrecord.SyncRecord // keyed by ID
}

func newStore() *store {
	return &store{records: make(map[string]syncrecord.SyncRecord)}
}

// upsert inserts or overwrites (LWW: newer updatedAt wins).
func (s *store) upsert(rec syncrecord.SyncRecord) (conflict bool, server syncrecord.SyncRecord) {
	s.mu.Lock()
	defer s.mu.Unlock()

	existing, exists := s.records[rec.ID]
	if exists && existing.UpdatedAt > rec.UpdatedAt {
		return true, existing
	}
	s.records[rec.ID] = rec
	return false, syncrecord.SyncRecord{}
}

// since returns all records updated after the given timestamp.
func (s *store) since(after string) []syncrecord.SyncRecord {
	s.mu.RLock()
	defer s.mu.RUnlock()

	var out []syncrecord.SyncRecord
	for _, r := range s.records {
		if r.UpdatedAt > after {
			out = append(out, r)
		}
	}
	return out
}

// ─── Request / response types ─────────────────────────────────────────────────

type pullRequest struct {
	DeviceID          string   `json:"deviceId"`
	LastSyncTimestamp string   `json:"lastSyncTimestamp"`
	EntityTypes       []string `json:"entityTypes"`
}

type pullResponse struct {
	Records         []syncrecord.SyncRecord `json:"records"`
	ServerTimestamp string                  `json:"serverTimestamp"`
	HasMore         bool                    `json:"hasMore"`
	NextCursor      string                  `json:"nextCursor"`
}

type pushRequest struct {
	DeviceID string                  `json:"deviceId"`
	Records  []syncrecord.SyncRecord `json:"records"`
}

type conflictInfo struct {
	ID            string                `json:"id"`
	EntityType    string                `json:"entityType"`
	ServerVersion syncrecord.SyncRecord `json:"serverVersion"`
	ClientVersion syncrecord.SyncRecord `json:"clientVersion"`
	Resolution    string                `json:"resolution"`
}

type pushResponse struct {
	Conflicts       []conflictInfo `json:"conflicts"`
	ServerTimestamp string         `json:"serverTimestamp"`
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

// devUserID extracts a fake user-ID from the Authorization header.
// Any non-empty value is accepted; "Bearer <token>" strips the prefix.
func devUserID(r *http.Request) (string, bool) {
	auth := r.Header.Get("Authorization")
	if auth == "" {
		// Also accept unauthenticated in dev mode with a default user.
		return "dev-user", true
	}
	if len(auth) > 7 && auth[:7] == "Bearer " {
		auth = auth[7:]
	}
	if auth == "" {
		return "", false
	}
	return "user-" + auth[:min(8, len(auth))], true
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

// ─── Handlers ─────────────────────────────────────────────────────────────────

type server struct {
	stores map[string]*store // per user-ID
	mu     sync.Mutex
}

func newServer() *server {
	return &server{stores: make(map[string]*store)}
}

func (srv *server) userStore(userID string) *store {
	srv.mu.Lock()
	defer srv.mu.Unlock()
	if s, ok := srv.stores[userID]; ok {
		return s
	}
	s := newStore()
	srv.stores[userID] = s
	return s
}

func (srv *server) handlePull(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return
	}

	userID, ok := devUserID(r)
	if !ok {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}

	var req pullRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid body"})
		return
	}
	if req.LastSyncTimestamp == "" {
		req.LastSyncTimestamp = "1970-01-01T00:00:00Z"
	}

	store := srv.userStore(userID)
	records := store.since(req.LastSyncTimestamp)

	// Filter by entity types if specified.
	if len(req.EntityTypes) > 0 {
		typeSet := make(map[string]bool, len(req.EntityTypes))
		for _, t := range req.EntityTypes {
			typeSet[t] = true
		}
		filtered := records[:0]
		for _, rec := range records {
			if typeSet[rec.EntityType] {
				filtered = append(filtered, rec)
			}
		}
		records = filtered
	}

	if records == nil {
		records = []syncrecord.SyncRecord{}
	}

	log.Printf("[pull] user=%s since=%s → %d records", userID, req.LastSyncTimestamp, len(records))
	writeJSON(w, http.StatusOK, pullResponse{
		Records:         records,
		ServerTimestamp: time.Now().UTC().Format(time.RFC3339),
		HasMore:         false,
		NextCursor:      "",
	})
}

func (srv *server) handlePush(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return
	}

	userID, ok := devUserID(r)
	if !ok {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}

	var req pushRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid body"})
		return
	}

	store := srv.userStore(userID)
	var conflicts []conflictInfo

	for _, rec := range req.Records {
		hasConflict, serverVer := store.upsert(rec)
		if hasConflict {
			conflicts = append(conflicts, conflictInfo{
				ID:            rec.ID,
				EntityType:    rec.EntityType,
				ServerVersion: serverVer,
				ClientVersion: rec,
				Resolution:    "last_write_wins",
			})
		}
	}

	if conflicts == nil {
		conflicts = []conflictInfo{}
	}

	log.Printf("[push] user=%s records=%d conflicts=%d", userID, len(req.Records), len(conflicts))
	writeJSON(w, http.StatusOK, pushResponse{
		Conflicts:       conflicts,
		ServerTimestamp: time.Now().UTC().Format(time.RFC3339),
	})
}

// ─── Health ───────────────────────────────────────────────────────────────────

func handleHealth(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok", "mode": "local-dev"})
}

// ─── Main ─────────────────────────────────────────────────────────────────────

func main() {
	port := flag.Int("port", 3001, "HTTP port to listen on")
	flag.Parse()

	srv := newServer()

	mux := http.NewServeMux()
	mux.HandleFunc("/health", handleHealth)
	mux.HandleFunc("/sync/pull", srv.handlePull)
	mux.HandleFunc("/sync/push", srv.handlePush)

	addr := fmt.Sprintf(":%d", *port)
	log.Printf("Antra local dev server listening on http://localhost%s", addr)
	log.Println("  POST /sync/pull  — pull records since lastSyncTimestamp")
	log.Println("  POST /sync/push  — push records (LWW conflict detection)")
	log.Println("  GET  /health     — liveness check")
	log.Println("Auth: any Authorization header accepted (dev bypass)")

	if err := http.ListenAndServe(addr, cors(mux)); err != nil {
		log.Fatalf("server error: %v", err)
	}
}

// cors wraps a handler to add permissive CORS headers for local dev.
func cors(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}
