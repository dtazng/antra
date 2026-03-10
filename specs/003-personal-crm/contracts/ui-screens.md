# Contract: UI Screens & Widgets

**Layer**: Presentation (Flutter screens and widgets)
**Date**: 2026-03-10

---

## `PeopleScreen` (modified)

**File**: `app/lib/screens/people/people_screen.dart`

### Responsibilities
- Show list of all non-deleted people (sorted, filtered, searched).
- Provide search bar (real-time, debounced 200ms).
- Provide sort selector (bottom sheet or segmented control).
- Provide filter chip row (relationship type, tags, needs follow-up).
- Show stale indicator badge on rows where `lastInteractionAt` is > 30 days ago.
- Show follow-up indicator on rows where `needsFollowUp = 1` or `followUpDate` is overdue.
- Navigate to `PersonProfileScreen` on row tap.
- Open `CreatePersonSheet` via FAB.

### State
- Watches `peopleScreenNotifierProvider` for sort/filter state.
- Watches `peopleSortedProvider(sort, needsFollowUpOnly: ...)` for SQL-sorted data.
- Applies Dart-side filters (tag, relationshipType, searchQuery) before rendering.

### Empty states
- No people: "No people yet. Tap + to add someone."
- Search returns nothing: "No matches for '[query]'."
- Filter returns nothing: "No people match this filter."

---

## `PersonProfileScreen` (modified)

**File**: `app/lib/screens/people/person_profile_screen.dart`

### Responsibilities
- Show full person profile: name, company, role, email, phone, birthday, location, relationshipType, tags, notes.
- All fields tappable/editable inline or via `EditPersonSheet`.
- Show `lastInteractionAt` derived label.
- Show follow-up section: toggle "Needs follow-up", set follow-up date via date picker.
- Show interaction timeline (linked bullets) in reverse-chron order.
- Each timeline entry tappable → navigates to correct detail screen (task/note/event).
- Destructive action: "Delete person" (with confirmation bottom sheet, soft-delete).

### State
- Watches `singlePersonProvider(personId)` (reactive to edits).
- Watches `bulletsForPersonProvider(personId)` for timeline.

### Follow-up section behavior
```
needsFollowUp = 0, followUpDate = null  → Button: "Mark as needs follow-up"
needsFollowUp = 1, followUpDate = null  → Badge: "Needs follow-up" + button "Set date" + button "Clear"
needsFollowUp = 1, followUpDate = past  → Badge: "Overdue follow-up: [date]" (red tint)
needsFollowUp = 1, followUpDate = future → Badge: "Follow up by [date]" + button "Clear"
```

### Tags display
- Tags shown as chips (read mode).
- Tap chips row → opens inline tag editor (text field + chip list with ✕ per tag).
- Max 20 tags; duplicate tags stripped on save.

---

## `CreatePersonSheet` (modified)

**File**: `app/lib/screens/people/create_person_sheet.dart`

### Responsibilities
- Collect `name` (required) and optionally `company`, `notes`.
- On save attempt: call `findSimilarPeople(name)` → if matches, show duplicate warning before proceeding.
- `name` is pre-fillable (when called from `BulletCaptureBar` "Create X" flow).
- On success: pass newly created `PeopleData` back to caller via `Navigator.pop(person)`.

### Duplicate warning
- Shown as an inline warning card below the name field (not a dialog, to avoid blocking flow).
- Lists matching people with name + company.
- "Use existing" button navigates to matching person.
- "Create anyway" button proceeds with creation.

### Caller signature
```dart
final person = await showModalBottomSheet<PeopleData?>(
  context: context,
  isScrollControlled: true,
  builder: (_) => CreatePersonSheet(initialName: 'Alice'),
);
// person is null if user cancelled, PeopleData if created
```

---

## `EditPersonSheet` (new)

**File**: `app/lib/screens/people/edit_person_sheet.dart`

### Responsibilities
- Full-field editor for all `Person` fields: name, company, role, email, phone, birthday (date picker), location, relationship type (segmented or dropdown), tags (chip editor), notes.
- Pre-filled with existing person values.
- Save calls `PeopleDao.updatePerson(companion)`.
- Accessible from `PersonProfileScreen` via edit button in app bar.

### Validation
- `name` must be non-empty.
- `email` validated as valid email format if non-empty.
- `birthday` must be past date if set.
- `relationshipType` must be one of the 6 enum values if set.

---

## `PersonPickerSheet` (new)

**File**: `app/lib/screens/people/person_picker_sheet.dart`

### Responsibilities
- Search and select an existing person.
- Used from `BulletDetailScreen` and `TaskDetailScreen` "Link person" action.
- Shows search field + live-filtered list of all people.
- Returns selected `PeopleData` via `Navigator.pop(person)`.
- Has "Create new person" option at bottom of list.

### Caller signature
```dart
final person = await showModalBottomSheet<PeopleData?>(
  context: context,
  isScrollControlled: true,
  builder: (_) => const PersonPickerSheet(),
);
// person is null if user cancelled
```

---

## `BulletDetailScreen` (modified)

**File**: `app/lib/screens/daily_log/bullet_detail_screen.dart`

### New section: Linked Person
- Shown below the content area, above hashtag chips.
- If no person linked: shows "Link person" ghost chip with person icon.
- If person linked: shows chip with avatar initial + name. Long-press → popover with "Remove link" and "Change person".
- Tapping linked person chip → navigates to `PersonProfileScreen`.
- "Link person" tap → opens `PersonPickerSheet`.
- After linking: invalidates `linkedPersonForBulletProvider(bulletId)` and calls `PeopleDao.insertLink(bulletId, personId, linkType: 'manual')`.
- After unlinking: calls `PeopleDao.removeLink(bulletId, personId)` and invalidates provider.

---

## `TaskDetailScreen` (modified)

**File**: `app/lib/screens/daily_log/task_detail_screen.dart`

### New section: Linked Person
- Same contract as `BulletDetailScreen` linked person section above.
- Placed in the info section alongside status and dates.

---

## `BulletCaptureBar` (modified)

**File**: `app/lib/widgets/bullet_capture_bar.dart`

### Enhanced @mention flow
When `_suggestions` is empty and `_currentMention` is non-empty, show a special "Create" row:
```
[+]  Create "[typedName]"
```
- Tapping "Create" row opens `CreatePersonSheet(initialName: typedName)`.
- If person is created: auto-inserts them into `_suggestions`, then calls `_selectSuggestion(newPerson)`.
- If person is cancelled: dismisses suggestion overlay, text unchanged.
- After submit: if `@mention` resolves to exactly one person → `linkType = 'mention'`. If no match found at submit time (user typed @name without picking from dropdown) → silent no-link (v1 behavior; does not block capture).

### Disambiguation picker
When `_suggestions.length > 1` for the same normalized name, show all matches in the overlay (existing behavior is correct — all matching people are shown).

---

## Stale / Follow-up indicator widget

**File**: `app/lib/widgets/person_status_badge.dart` (new)

### Inputs
```dart
class PersonStatusBadge extends StatelessWidget {
  final PeopleData person;
  // ...
}
```

### Display logic
| Condition | Output |
|-----------|--------|
| `needsFollowUp == 1` and `followUpDate` overdue | Red badge: "Overdue" |
| `needsFollowUp == 1` and `followUpDate` future | Amber badge: "Follow up [date]" |
| `needsFollowUp == 1` and no date | Amber badge: "Follow up" |
| `lastInteractionAt` > 30 days ago | Grey badge: "Last contact [N] days ago" |
| Otherwise | No badge |

- Used in `_PersonTile` (people list row) and `PersonProfileScreen` header.
