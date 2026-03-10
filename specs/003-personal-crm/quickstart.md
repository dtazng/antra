# Quickstart: Personal CRM (003-personal-crm)

**For**: Implementer onboarding — get from zero to first working feature in one session.
**Date**: 2026-03-10

---

## What already exists (don't rebuild)

| Thing | Location | Status |
|-------|----------|--------|
| `People` table | `app/lib/database/tables/people.dart` | Exists — needs new columns |
| `BulletPersonLinks` table | `app/lib/database/tables/bullet_person_links.dart` | Exists — needs `linkType` column |
| `PeopleDao` | `app/lib/database/daos/people_dao.dart` | Exists — needs new methods |
| `people_fts` FTS5 table + triggers | `app/lib/database/app_database.dart` | Exists — needs `company` column added |
| `PeopleScreen` | `app/lib/screens/people/people_screen.dart` | Exists — needs search/sort/filter |
| `PersonProfileScreen` | `app/lib/screens/people/person_profile_screen.dart` | Exists — needs new fields |
| `CreatePersonSheet` | `app/lib/screens/people/create_person_sheet.dart` | Exists — needs duplicate check |
| `BulletCaptureBar` @mention | `app/lib/widgets/bullet_capture_bar.dart` | Exists — needs "Create" row |
| `allPeopleProvider` | `app/lib/providers/people_provider.dart` | Exists — needs new providers |
| `bulletsForPersonProvider` | `app/lib/providers/people_provider.dart` | Exists |

---

## Implementation order

Work in this dependency order to avoid blocked steps:

### Step 1 — Schema (foundation, no UI impact yet)

1. Add new columns to `People` table class (`people.dart`)
2. Add `linkType` to `BulletPersonLinks` table class (`bullet_person_links.dart`)
3. Bump `schemaVersion` to 3 in `app_database.dart`
4. Add `onUpgrade` block for v2→v3 (see `data-model.md` migration script)
5. Run `dart run build_runner build --delete-conflicting-outputs`
6. Verify: run app on simulator — it should migrate cleanly, no crash

### Step 2 — DAO (data layer)

7. Add new methods to `PeopleDao` (see `contracts/people-dao.md`):
   - `watchPersonById`, `searchPeople`, `findSimilarPeople`
   - `watchPeopleSorted`, `removeLink`, `softDeleteLinksForPerson`
   - `getLinkedPersonForBullet`, `setFollowUp`
   - Update `insertLink` signature to accept `linkType`
8. Update `softDeletePerson` to call `softDeleteLinksForPerson` in the same transaction
9. Update `_enqueuePersonSync` to include all new fields in payload
10. Run `dart run build_runner build --delete-conflicting-outputs` again

### Step 3 — Providers

11. Add to `people_provider.dart`:
    - `peopleSortedProvider`
    - `singlePersonProvider`
    - `linkedPersonForBulletProvider`
    - `PeopleScreenNotifier` + `PeopleScreenState`
12. Run `dart run build_runner build --delete-conflicting-outputs`

### Step 4 — People list (visible, P2)

13. Update `PeopleScreen`: add search bar, sort bottom sheet, filter chips, stale/follow-up indicators
14. Create `PersonStatusBadge` widget (`app/lib/widgets/person_status_badge.dart`)
15. Verify: search by name works, sort works, stale badge shows for old entries

### Step 5 — Person profile (visible, P2)

16. Update `PersonProfileScreen` to watch `singlePersonProvider` (reactive)
17. Add all new fields (company, role, email, phone, birthday, location, tags, relationshipType)
18. Add follow-up section with toggle and date picker
19. Add edit button → `EditPersonSheet`
20. Add delete button → confirmation → `softDeletePerson`
21. Fix timeline: each bullet taps through to correct detail screen

### Step 6 — Create/Edit person (P2)

22. Update `CreatePersonSheet`: add `initialName` param, duplicate check, return `PeopleData`
23. Create `EditPersonSheet` with full field editor
24. Create `PersonPickerSheet` (people search + select)

### Step 7 — Log detail linking (P2)

25. Update `BulletDetailScreen`: add linked person section
26. Update `TaskDetailScreen`: add linked person section
27. Wire `PersonPickerSheet` for link/unlink/change actions

### Step 8 — Capture bar create flow (P1)

28. Update `BulletCaptureBar`: show "Create [name]" row when no suggestions match
29. Wire `CreatePersonSheet` → auto-link on return
30. Verify: full @mention → create → link flow works end-to-end

---

## Key commands

```bash
# After any schema or provider change:
cd app && dart run build_runner build --delete-conflicting-outputs

# Run on iOS simulator:
flutter run -d "iPhone 16"

# Run tests:
flutter test
```

---

## Testing focus areas (from spec acceptance scenarios)

| Story | Scenario | What to verify |
|-------|----------|----------------|
| US-1 | @mention new person | "Create Alice" row appears, sheet opens pre-filled, person created + linked |
| US-1 | @mention existing person | Exact match auto-selected, bullet linked on save |
| US-1 | Disambiguation | Two "Alex" people shown as list, not auto-selected |
| US-1 | Manual link from detail | "Link person" chip opens picker, selection creates link |
| US-2 | Timeline order | 10 bullets reverse-chron, each shows date + type icon |
| US-2 | Timeline tap | Opens correct detail screen (task/note/event) |
| US-2 | Empty state | "No linked bullets yet" message shown |
| US-3 | Search | Typing "sa" filters list in real-time |
| US-3 | Sort | "Last interaction" sort reorders correctly |
| US-4 | Name-only create | Person saved with no other fields |
| US-4 | Duplicate warning | Creating "Alice Ng" when "Alice Ng" exists shows warning |
| US-5 | Follow-up flag | Mark as needs follow-up → badge in list |
| US-5 | Auto-clear follow-up | Link new bullet → needsFollowUp clears |
| US-5 | Stale indicator | Person not linked in 30+ days → stale badge |

---

## Design decisions reference

All decisions are documented in `research.md`. Key ones to keep in mind:

- **Tags** are comma-separated strings, not a junction table.
- **Filtering** by tags/relationship type happens Dart-side (not SQL).
- **Multi-person per log**: schema supports it, UI shows only first link in v1.
- **linkType**: always `'mention'` from capture bar, `'manual'` from log detail.
- **Stale threshold**: hardcoded 30 days (not user-configurable in v1).
- **Soft-delete only**: `isDeleted = 1` everywhere, never physical delete.
