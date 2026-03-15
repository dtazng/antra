# Quickstart: Person Special Dates, Compact UI, Voice Logging, and Intelligent Logging UX

**Branch**: `017-voice-smart-logging` | **Date**: 2026-03-15

---

## Overview

This guide shows how the five new subsystems introduced in this feature connect. Read it to understand how the pieces fit before starting implementation.

---

## 1. Drift Schema Migration (v5 → v6)

Three changes to the drift schema, all additive (no data loss):

```dart
// app_database.dart — bump schemaVersion and add MigrationStrategy
@DriftDatabase(tables: [
  ...,
  PersonImportantDates,    // NEW
  SmartPromptDismissals,   // NEW
])
class AppDatabase extends _$AppDatabase {
  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 6) {
        await m.createTable(personImportantDates);
        await m.createTable(smartPromptDismissals);
        await m.addColumn(bullets, bullets.audioFilePath);
        await m.addColumn(bullets, bullets.audioDurationSeconds);
        await m.addColumn(bullets, bullets.transcriptText);
        await m.addColumn(bullets, bullets.transcriptionStatus);
        await m.addColumn(bullets, bullets.sourceType);
      }
    },
  );
}
```

Run `dart run build_runner build --delete-conflicting-outputs` after any schema change.

---

## 2. Important Dates — End-to-End Flow

**Add a birthday:**

```
User taps "+ Add date" on person detail
  → ImportantDateFormSheet opens (modal)
  → User fills label="Birthday", date=May 12, isBirthday=true, reminder=-14 days yearly
  → PersonImportantDatesDao.insert(date)
  → Backend POST /v1/persons/{id}/important-dates (sync on next push)
  → Stream<List<ImportantDate>> rebuilds important_dates_section.dart
```

**Riverpod wiring:**

```dart
// providers/person_important_dates_providers.dart
@riverpod
Stream<List<ImportantDate>> personImportantDates(
  PersonImportantDatesRef ref,
  String personId,
) {
  return ref.watch(appDatabaseProvider)
    .personImportantDatesDao
    .watchDatesForPerson(personId);
}

@riverpod
Future<void> addImportantDate(
  AddImportantDateRef ref,
  ImportantDatesCompanion date,
) async {
  await ref.read(appDatabaseProvider)
    .personImportantDatesDao.insert(date);
  // optimistic: stream fires before sync
}
```

---

## 3. Voice Logging — End-to-End Flow

**Tap mode recording:**

```
User taps 🎤 in logging bar
  → VoiceRecorderService.startRecording(path)
  → voice_recording_overlay.dart shows (indicator + elapsed time + cancel)
  → User taps 🎤 again
  → VoiceRecorderService.stopRecording() → returns audioFilePath
  → TranscriptionService.transcribe(audioFilePath) starts
  → BulletsDao.insert(bullet(sourceType:'voice', transcriptionStatus:'transcribing', audioFilePath:...))
  → Log entry appears immediately in timeline with "Transcribing…" badge
  → On completion: BulletsDao.update(transcriptText, transcriptionStatus:'complete')
  → Voice note badge shows "Voice note • N sec"
```

**Hold mode:**

```dart
// In logging_bar.dart
GestureDetector(
  onLongPressStart: (_) => recorderService.startRecording(path),
  onLongPressEnd: (_) => recorderService.stopRecording(),
  child: MicButton(),
)
```

**Offline handling:**

```dart
// transcription_service.dart
Future<void> transcribe(String audioFilePath, String bulletId) async {
  if (!await connectivity.isOnline()) {
    await db.bulletsDao.setStatus(bulletId, 'pending');
    return; // queued — retried on connectivity restore
  }
  // ... proceed with speech_to_text
}
```

---

## 4. Smart Prompts — Computation Flow

All smart prompts are computed client-side by `SmartPromptService`. No backend call.

**Three prompt types:**

| Type | Trigger | Data source |
|------|---------|-------------|
| `inactivity` | Person not interacted with in 90+ days | `persons.lastInteractionAt` |
| `follow_up` | 7 days after an interaction with a person | `log_person_links + bullets.createdAt` |
| `important_date` | Today ≥ date − `reminderOffsetDays` | `person_important_dates` |

**Provider:**

```dart
@riverpod
Stream<List<SmartPrompt>> smartPrompts(SmartPromptsRef ref) async* {
  final service = ref.watch(smartPromptServiceProvider);
  yield* service.watchPrompts(); // polls DB on ticker or DB stream change
}
```

**Dismissal:**

```dart
// Tapping "Done" on an important-date card:
await db.smartPromptDismissalsDao.insert(SmartPromptDismissalsCompanion(
  personId: Value(personId),
  promptType: const Value('important_date'),
  importantDateId: Value(dateId),
  dismissedUntil: Value(nextYearOccurrence.toIso8601String()),
));
```

---

## 5. Person Detection — Post-Save Hook

After `BulletsDao.insert`, call `PersonDetectionService.detect(text, personId: null)`:

```dart
// In logging_bar.dart after saving
final suggestions = await ref.read(personDetectionServiceProvider)
  .detect(logText);
if (suggestions.isNotEmpty) {
  ref.read(personDetectionSuggestionsProvider(bulletId).notifier)
    .setSuggestions(suggestions);
}
```

Detection algorithm:
1. Tokenize text into words and 2–3-word phrases.
2. Case-insensitive match against `persons WHERE isDeleted = 0`.
3. Exact full name > exact first name (unique) > prefix match.
4. Surface up to 5 chips; auto-dismiss suggestions older than 3 days.

---

## 6. Compact Card Layout (Slidable)

Wrap every `LogCard` in `Slidable`:

```dart
Slidable(
  key: ValueKey(entry.id),
  startActionPane: ActionPane(
    motion: const DrawerMotion(),
    children: [
      SlidableAction(icon: Icons.alarm_add_outlined, label: 'Follow up',
          onPressed: (_) => ref.read(followUpProvider).create(entry)),
      SlidableAction(icon: Icons.edit_outlined, label: 'Edit',
          onPressed: (_) => openEditSheet(entry)),
      SlidableAction(icon: Icons.person_add_outlined, label: 'Link',
          onPressed: (_) => openLinkPersonSheet(entry)),
    ],
  ),
  endActionPane: ActionPane(
    motion: const DrawerMotion(),
    children: [
      SlidableAction(
        icon: Icons.delete_outline,
        backgroundColor: Colors.red,
        onPressed: (_) => confirmDelete(entry),
      ),
    ],
  ),
  child: LogCard(entry: entry),
)
```

Wrap the list with `SlidableAutoCloseBehavior` to close open items on scroll.

Updated card padding:

```dart
Padding(
  padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 15),
  child: ...
)
```

---

## 7. Backend: Important Dates API

Go handler registration in `router.go`:

```go
r.Route("/v1/persons/{personId}/important-dates", func(r chi.Router) {
  r.Post("/", h.importantDates.Create)
  r.Get("/", h.importantDates.List)
  r.Put("/{id}", h.importantDates.Update)
  r.Delete("/{id}", h.importantDates.Delete)
})
```

Run the goose migration before starting the server:

```bash
cd server && make migrate-up
```

Migration file: `server/internal/db/migrations/00002_voice_and_important_dates.sql`

---

## 8. Required iOS Permissions

Already added in a prior session (`Info.plist`):

```xml
<key>NSMicrophoneUsageDescription</key>
<string>Antra Log uses the microphone to record voice notes.</string>
```

Required Android permission (`AndroidManifest.xml`):

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
```

Use `permission_handler` to request at runtime before first recording.

---

## 9. New Packages — pubspec.yaml additions

```yaml
dependencies:
  record: ^5.0.0
  speech_to_text: ^7.3.0
  just_audio: ^0.10.5
  flutter_slidable: ^4.0.3
  permission_handler: ^11.0.0
```

Run `flutter pub get` after updating.
