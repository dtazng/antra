// Package syncrecord defines the shared SyncRecord type and related request/
// response shapes used by both the pull_sync and push_sync Lambda handlers.
package syncrecord

// SyncRecord is the unit of data exchanged between client and server.
type SyncRecord struct {
	ID                string  `json:"id"`
	SyncID            *string `json:"syncId"`
	EntityType        string  `json:"entityType"`
	Data              string  `json:"data"`
	UpdatedAt         string  `json:"updatedAt"`
	DeviceID          string  `json:"deviceId"`
	IsDeleted         bool    `json:"isDeleted"`
	EncryptionEnabled bool    `json:"encryptionEnabled"`
}

// ConflictInfo describes a single LWW conflict returned by push_sync.
type ConflictInfo struct {
	ID            string     `json:"id"`
	EntityType    string     `json:"entityType"`
	ServerVersion SyncRecord `json:"serverVersion"`
	ClientVersion SyncRecord `json:"clientVersion"`
	Resolution    string     `json:"resolution"` // always "last_write_wins"
}
