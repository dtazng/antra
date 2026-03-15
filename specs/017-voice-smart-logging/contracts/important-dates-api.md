# API Contract: Person Important Dates

**Base path**: `/v1/persons/{person_id}/important-dates`
**Auth**: Bearer token required on all endpoints

---

## POST /v1/persons/{person_id}/important-dates

Create a new important date for a person.

### Request

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "label": "Birthday",
  "is_birthday": true,
  "month": 5,
  "day": 12,
  "year": null,
  "reminder_offset_days": -14,
  "reminder_recurrence": "yearly",
  "note": "Loves hiking"
}
```

| Field | Type | Required | Constraints |
|-------|------|----------|-------------|
| `id` | UUID string | Yes | Client-generated, must be unique |
| `label` | string | Yes | 1–100 chars |
| `is_birthday` | boolean | No | default false |
| `month` | integer | Yes | 1–12 |
| `day` | integer | Yes | 1–31 |
| `year` | integer or null | No | 4-digit year or null |
| `reminder_offset_days` | integer or null | No | null = no reminder |
| `reminder_recurrence` | string or null | No | "yearly" or "once"; required if reminder_offset_days is set |
| `note` | string or null | No | max 500 chars |

### Response 201 Created

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "person_id": "...",
  "label": "Birthday",
  "is_birthday": true,
  "month": 5,
  "day": 12,
  "year": null,
  "reminder_offset_days": -14,
  "reminder_recurrence": "yearly",
  "note": "Loves hiking",
  "created_at": "2026-03-15T10:00:00Z",
  "updated_at": "2026-03-15T10:00:00Z"
}
```

### Error Responses

| Status | Code | Condition |
|--------|------|-----------|
| 400 | `INVALID_INPUT` | Missing required fields, invalid month/day range |
| 404 | `NOT_FOUND` | Person not found or belongs to another user |
| 409 | `CONFLICT` | ID already exists |

---

## GET /v1/persons/{person_id}/important-dates

List all active important dates for a person.

### Response 200 OK

```json
{
  "items": [
    {
      "id": "...",
      "person_id": "...",
      "label": "Birthday",
      "is_birthday": true,
      "month": 5,
      "day": 12,
      "year": null,
      "reminder_offset_days": -14,
      "reminder_recurrence": "yearly",
      "note": null,
      "created_at": "...",
      "updated_at": "..."
    }
  ]
}
```

---

## PUT /v1/persons/{person_id}/important-dates/{id}

Full update (replace) of an important date.

### Request

Same body as POST (all fields required).

### Response 200 OK

Updated important date object.

### Error Responses

| Status | Code | Condition |
|--------|------|-----------|
| 400 | `INVALID_INPUT` | Validation failure |
| 404 | `NOT_FOUND` | Date not found or belongs to another user/person |

---

## DELETE /v1/persons/{person_id}/important-dates/{id}

Soft-delete an important date.

### Response 204 No Content

### Error Responses

| Status | Code | Condition |
|--------|------|-----------|
| 404 | `NOT_FOUND` | Date not found |

---

## Sync Integration

Important dates are included in the standard sync pull/push payload under entity type `important_dates`. Conflict resolution follows the existing LWW (last-write-wins) pattern based on `updated_at`.
