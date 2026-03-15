---

description: "Task list for Person Special Dates, Compact UI, Voice Logging, and Intelligent Logging UX"
---

# Tasks: Person Special Dates, Compact UI, Voice Logging, and Intelligent Logging UX

**Input**: Design documents from `/specs/017-voice-smart-logging/`
**Prerequisites**: plan.md ✅ spec.md ✅ research.md ✅ data-model.md ✅ contracts/ ✅ quickstart.md ✅

**Tests**: Not explicitly requested — no test tasks generated. Tests may be added via `/speckit.checklist` before implementation.

**Organization**: Tasks grouped by user story for independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: User story label (US1–US5)
- Exact file paths in every description

---

## Phase 1: Setup

**Purpose**: Add new packages and platform permissions required by this feature.

- [X] T001 Add 5 new packages to app/pubspec.yaml: `record: ^6.1.1`, `speech_to_text: ^7.3.0`, `just_audio: ^0.10.5`, `flutter_slidable: ^4.0.3`, `permission_handler: ^11.0.0`; run `flutter pub get`
- [X] T002 [P] Verify Flutter SDK ≥ 3.27.0 for flutter_slidable v4 compatibility (`flutter --version`); if < 3.27.0 downgrade to `flutter_slidable: ^3.3.1` in app/pubspec.yaml and document version in plan.md
- [X] T003 [P] Add `<uses-permission android:name="android.permission.RECORD_AUDIO"/>` to app/android/app/src/main/AndroidManifest.xml
- [X] T004 Create goose migration file server/internal/db/migrations/00002_voice_and_important_dates.sql with `-- +goose Up` block: `CREATE TABLE person_important_dates` (full DDL from data-model.md) and `ALTER TABLE logs ADD COLUMN audio_file_path TEXT, audio_duration_seconds INTEGER, transcript_text TEXT, transcription_status TEXT, source_type TEXT` plus all indexes; add matching `-- +goose Down` block

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Drift schema migration and server migration — MUST complete before any user story begins.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [X] T005 [P] Create PersonImportantDates drift table definition in app/lib/database/tables/person_important_dates_table.dart — columns: id TEXT PK, personId TEXT, label TEXT, isBirthday INTEGER default 0, month INTEGER, day INTEGER, year INTEGER?, reminderOffsetDays INTEGER?, reminderRecurrence TEXT?, note TEXT?, createdAt TEXT, updatedAt TEXT, syncId TEXT?, deviceId TEXT, isDeleted INTEGER default 0; add composite index on (personId, isDeleted)
- [X] T006 [P] Create SmartPromptDismissals drift table definition in app/lib/database/tables/smart_prompt_dismissals_table.dart — columns: id INTEGER autoincrement PK, personId TEXT?, promptType TEXT, importantDateId TEXT?, dismissedUntil TEXT, createdAt TEXT; add composite index on (personId, promptType)
- [X] T007 [P] Add 5 nullable voice log columns to Bullets drift table in app/lib/database/tables/bullets_table.dart: audioFilePath TEXT?, audioDurationSeconds INTEGER?, transcriptText TEXT?, transcriptionStatus TEXT?, sourceType TEXT?
- [X] T008 Register PersonImportantDates and SmartPromptDismissals in the @DriftDatabase annotation in app/lib/database/app_database.dart; bump schemaVersion from 5 to 6; add MigrationStrategy.onUpgrade that calls createTable for both new tables and addColumn for each of the 5 Bullets voice log fields when from < 6 (depends on T005, T006, T007)
- [X] T009 Run `dart run build_runner build --delete-conflicting-outputs` from app/ to regenerate all drift-generated files (depends on T008)
- [X] T010 [P] Create server/internal/db/queries/important_dates.sql with sqlc-annotated queries: CreateImportantDate, GetImportantDatesByPerson, GetImportantDate, UpdateImportantDate, SoftDeleteImportantDate, ListImportantDatesByUserSince (for sync)
- [X] T011 Run `sqlc generate` from server/ to produce Go query types for important_dates.sql (depends on T004, T010)
- [X] T012 Run `make migrate-up` from server/ to apply goose migration 00002 to local Postgres DB (depends on T004)
- [X] T013 [P] Create PersonImportantDatesDao in app/lib/database/daos/person_important_dates_dao.dart: insert, update, softDelete, watchDatesForPerson (Stream), getById methods (depends on T009)
- [X] T014 [P] Create SmartPromptDismissalsDao in app/lib/database/daos/smart_prompt_dismissals_dao.dart: insert, queryActiveByPersonAndType, deleteExpired methods (depends on T009)
- [X] T015 [P] Add voice-log-specific query methods to existing BulletsDao in app/lib/database/daos/bullets_dao.dart: updateTranscriptionStatus, updateTranscript, watchVoiceLogs methods (depends on T009)

**Checkpoint**: Drift v6 schema live, Go migration applied, all DAOs ready — user story implementation can begin.

---

## Phase 3: User Story 1 — Person Important Dates (Priority: P1) 🎯 MVP

**Goal**: Add structured important dates (birthdays, anniversaries) to person profiles with reminder preset selector, compact date list in person detail, and Needs Attention cards at the configured reminder threshold.

**Independent Test**: Add a birthday (May 12, "2 weeks before" reminder) to an existing person. Verify it appears first in the Important Dates section as "🎂 Birthday — May 12". Advance system date to 14 days before May 12. Verify a "Birthday in 2 weeks" Needs Attention card appears. Tap "Done" — card disappears for this year.

- [X] T016 [P] [US1] Implement ImportantDatesService in server/internal/service/important_dates.go: Create, List, Update, SoftDelete methods using sqlc-generated types; enforce isBirthday uniqueness per person in Create and Update (depends on T011, T012)
- [X] T017 [P] [US1] Create person_important_dates_providers.dart in app/lib/providers/person_important_dates_providers.dart: @riverpod Stream<List<PersonImportantDate>> personImportantDates(personId), @riverpod Future<void> addImportantDate(companion), updateImportantDate, deleteImportantDate (depends on T013)
- [X] T018 [US1] Implement ImportantDatesHandler in server/internal/api/v1/important_dates_handler.go: Create (POST), List (GET), Update (PUT /{id}), Delete (DELETE /{id}); use mapServiceError for 400/404/409 responses per contracts/important-dates-api.md (depends on T016)
- [X] T019 [US1] Register /v1/persons/{personId}/important-dates routes on the authenticated chi router in server/internal/api/v1/router.go (depends on T018)
- [X] T020 [US1] Create ImportantDatesSection widget in app/lib/screens/person_detail/widgets/important_dates_section.dart: compact list rows (🎂 for isBirthday, otherwise 📅), birthday row always first, reminder label below date, swipe-left to delete with confirmation, tap to edit, "+ Add date" trailing button (depends on T017)
- [X] T021 [US1] Create ImportantDateFormSheet widget in app/lib/screens/person_detail/widgets/important_date_form_sheet.dart: modal bottom sheet with label TextField, DatePicker (month + day + optional year), ReminderPresetSelector (No reminder / On the day / 1 day before / 3 days before / 1 week before / 2 weeks before / 1 month before / Custom — Custom reveals direction+value+unit+recurrence fields), optional note TextField; pre-fills existing values when editing (depends on T017)
- [X] T022 [US1] Restructure PersonDetailScreen layout in app/lib/screens/person_detail/person_detail_screen.dart: order = person header → last interaction → ImportantDatesSection → notes about person → recent interactions (max 10) → "View full history" button (depends on T020, T021)
- [X] T023 [US1] Create SmartPromptService in app/lib/services/smart_prompt_service.dart: watchImportantDatePrompts() method — query PersonImportantDatesDao for all active non-deleted dates; for each, compute trigger day as (date − reminderOffsetDays) and yield a SmartPrompt when today ≥ trigger day and no active dismissal exists in SmartPromptDismissalsDao (depends on T013, T014)
- [X] T024 [US1] Create smart_prompt_providers.dart in app/lib/providers/smart_prompt_providers.dart: @riverpod Stream<List<SmartPrompt>> importantDatePrompts() backed by SmartPromptService.watchImportantDatePrompts() (depends on T023)
- [X] T025 [US1] Update SmartPromptCard widget in app/lib/widgets/smart_prompt_card.dart to handle promptType = 'important_date': show "[Name]'s [label] in [N] days/weeks 🎂" title + "Maybe send them a message" body + Log interaction / Snooze / Done action buttons (depends on T024, T014)
- [X] T026 [US1] Implement Done action in SmartPromptCard: call SmartPromptDismissalsDao.insert with dismissedUntil = same month/day next year's ISO date; implement Snooze bottom sheet (tomorrow / 3 days / next week options) setting dismissedUntil accordingly in app/lib/widgets/smart_prompt_card.dart (depends on T025)
- [X] T027 [US1] Add optional initialPersonId parameter to LoggingBar widget in app/lib/widgets/logging_bar.dart so "Log interaction" from SmartPromptCard pre-links the correct person on open (depends on T025)

**Checkpoint**: Full important dates lifecycle works — add/edit/delete dates, reminders surface in Needs Attention, Done/Snooze dismissals persist correctly.

---

## Phase 4: User Story 2 — Voice Logging (Priority: P2)

**Goal**: Tap or hold the microphone button in the logging bar to record audio. After stopping, transcription begins automatically and a log entry appears in the timeline within 1 second. Voice logs show a "Voice note • N sec" badge. Offline recordings are preserved and transcribed when connectivity is restored.

**Independent Test**: Open the logging bar, tap the microphone, speak a sentence, tap again to stop. Verify a log entry appears in the timeline with the transcript text and "Voice note • [N] sec" label. Open the detail view — confirm the transcript and an audio play button are visible.

- [X] T028 [P] [US2] Create VoiceRecorderService in app/lib/services/voice_recorder_service.dart: wraps AudioRecorder from `record ^6.1.1`; startRecording(path) using RecordConfig(encoder: AudioEncoder.aacLc, sampleRate: 16000, numChannels: 1); stopRecording() returns file path; cancelRecording() discards file; requestPermission() via permission_handler; exposes recordingStateStream
- [X] T029 [P] [US2] Create TranscriptionService in app/lib/services/transcription_service.dart: wraps SpeechToText from `speech_to_text ^7.3.0`; transcribeFromFile(bulletId, audioPath) — on iOS runs live recognition; on Android or if offline, sets transcriptionStatus to 'pending' in BulletsDao and queues for retry; retryPending() called on connectivity restore (depends on T015)
- [X] T030 [P] [US2] Create AudioPlayerService in app/lib/services/audio_player_service.dart: wraps AudioPlayer from `just_audio ^0.10.5`; loadFile(path), play(), pause(), seek(position), dispose(); exposes playerStateStream and positionStream
- [X] T031 [US2] Create voice_log_providers.dart in app/lib/providers/voice_log_providers.dart: @riverpod class VoiceRecordingNotifier (recording state: idle/recording/transcribing) backed by VoiceRecorderService and TranscriptionService; @riverpod AudioPlayerService audioPlayerService (depends on T028, T029, T030)
- [X] T032 [US2] Restructure LoggingBar in app/lib/widgets/logging_bar.dart: second row (👤 link person, 🔔 follow-up, 🎤 mic button) hidden by default and revealed when text field gains focus; Done button on right side; second row also visible when recording is active; wire mic button tap and long-press to VoiceRecordingNotifier (depends on T027, T031)
- [X] T033 [US2] Create VoiceRecordingOverlay widget in app/lib/widgets/voice_recording_overlay.dart: shows red pulse recording indicator, elapsed time counter (updates every second via Timer), and Cancel button; displayed as overlay above LoggingBar while recording; cancel calls VoiceRecorderService.cancelRecording() (depends on T031)
- [X] T034 [US2] Wire tap-to-toggle and press-and-hold mic recording modes in app/lib/widgets/logging_bar.dart: GestureDetector with onTap (toggle) and onLongPressStart/onLongPressEnd (hold); on stop, call TranscriptionService.transcribeFromFile and BulletsDao.insert with sourceType='voice', transcriptionStatus='transcribing' (depends on T032, T033)
- [X] T035 [US2] Create VoiceLogBadge widget in app/lib/widgets/voice_log_badge.dart: displays mic icon + "Voice note • [N] sec" text; shows "Transcribing…" when transcriptionStatus = 'transcribing'; shows "Transcription failed — tap to retry" when status = 'failed'
- [X] T036 [US2] Update LogCard in app/lib/widgets/log_card.dart to render VoiceLogBadge below body text when bullet.sourceType == 'voice' (depends on T035)
- [X] T037 [US2] Create AudioPlayerWidget in app/lib/widgets/audio_player_widget.dart: inline player with play/pause button, current position label, seek bar (Slider), total duration label backed by AudioPlayerService streams (depends on T030)
- [X] T038 [US2] Update log detail screen in app/lib/screens/log_detail_screen.dart to show transcript text section and AudioPlayerWidget when bullet.sourceType == 'voice'; show retry button when transcriptionStatus == 'failed' (depends on T037)

**Checkpoint**: Voice recording, transcription, and playback all work end-to-end; offline recordings survive app restart; timeline shows voice badge.

---

## Phase 5: User Story 3 — Smart Person Detection (Priority: P3)

**Goal**: After saving a typed or voice log, the system detects matching person names and shows tappable suggestion chips near the new entry. Tapping a chip links that person to the log in one tap with no confirmation.

**Independent Test**: Create a person named "Anna Chen". Save a log entry with text "Met Anna Chen for coffee". Verify a suggestion chip "Anna Chen" appears near the entry. Tap the chip — verify Anna is linked to the log and the chip disappears.

- [X] T039 [US3] Create PersonDetectionService in app/lib/services/person_detection_service.dart: detect(logText) method — tokenize text into words and 2–3 word phrases; case-insensitive match against all non-deleted persons from DB; exact full name > unique first name > prefix match; return up to 5 PersonDetectionSuggestion objects; exclude common stop words
- [X] T040 [P] [US3] Create PersonDetectionChips widget in app/lib/widgets/person_detection_chips.dart: horizontal row of tappable Chips showing person names; onAccept callback links person and hides chip; onDismissAll clears all chips for the entry (depends on T039)
- [X] T041 [P] [US3] Create person_detection_providers.dart in app/lib/providers/person_detection_providers.dart: @riverpod class PersonDetectionNotifier keyed by bulletId; holds List<PersonDetectionSuggestion>; setSuggestions(), acceptSuggestion(personId), dismissAll(); auto-clears suggestions older than 3 days (depends on T039)
- [X] T042 [US3] Hook PersonDetectionService into the post-save flow in app/lib/widgets/logging_bar.dart: after BulletsDao.insert, call PersonDetectionService.detect(logText) and set suggestions via PersonDetectionNotifier if any matches found (depends on T041)
- [X] T043 [US3] Render PersonDetectionChips below the newly saved log entry in the timeline in app/lib/screens/daily_log_screen.dart: observe PersonDetectionNotifier for each bulletId and show chips inline (depends on T040, T041)

**Checkpoint**: Name detection fires after every save; correct person chips appear; tapping links person; suggestions auto-expire after 3 days.

---

## Phase 6: User Story 4 — Compact Card Layout and Swipe Gestures (Priority: P4)

**Goal**: Timeline cards are visually denser (≥20% more entries visible per screen). Cards at rest show no action buttons. Swipe right reveals quick actions (Add follow-up, Edit, Link person); swipe left reveals delete.

**Independent Test**: Create 10 log entries. Count entries visible before this change vs after — confirm at least 20% more fit on screen. Swipe a card right — confirm 3 action buttons appear. Swipe left — confirm delete affordance appears. Verify no action buttons are visible on cards at rest.

- [X] T044 [P] [US4] Update LogCard padding to `EdgeInsets.symmetric(vertical: 11, horizontal: 15)` in app/lib/widgets/log_card.dart; reduce inter-element spacing to match messaging-app density
- [X] T045 [P] [US4] Update LogCard content structure in app/lib/widgets/log_card.dart: body text on top row, compact metadata row (linked person chips + relative timestamp) below; remove any standalone action buttons from the card body
- [X] T046 [US4] Wrap LogCard in Slidable in app/lib/widgets/log_card.dart: startActionPane (DrawerMotion, 3 SlidableActions: add follow-up/edit/link) + endActionPane (BehindMotion with DismissiblePane for delete); supply `ValueKey(bullet.id)` (depends on T044, T045)
- [X] T047 [US4] Implement swipe-right action handlers in app/lib/widgets/log_card.dart: "Add follow-up" calls follow-up creation logic; "Edit" opens edit sheet; "Link person" opens person picker sheet (depends on T046)
- [X] T048 [US4] Implement swipe-left delete: DismissiblePane.onDismissed shows a SnackBar with undo; on confirmation or undo-timeout calls BulletsDao soft delete in app/lib/widgets/log_card.dart (depends on T046)
- [X] T049 [US4] Add SlidableAutoCloseBehavior wrapper around the timeline ListView in app/lib/screens/daily_log_screen.dart so open panes close automatically on scroll (depends on T046)

**Checkpoint**: Cards are visually denser; all swipe gestures work; no action buttons at rest; delete with undo works.

---

## Phase 7: User Story 5 — Smart Follow-Up Prompts (Priority: P5)

**Goal**: Needs Attention surfaces inactivity cards ("You haven't talked to Anna in 3 months") and post-interaction follow-up cards ("You met Ben last week — follow up?"). Each offers Log interaction, Snooze, and Dismiss (suppresses for 30 days).

**Independent Test**: Manually set a person's lastInteractionAt to 91 days ago in the local DB. Open the day view — verify a "You haven't talked to [Name] in 3 months" card appears. Tap Dismiss — verify the card disappears and does not reappear for 30 days.

- [X] T050 [US5] Extend SmartPromptService in app/lib/services/smart_prompt_service.dart with watchInactivityPrompts() (query persons WHERE lastInteractionAt < now − 90 days AND isDeleted = 0, filter by SmartPromptDismissals) and watchFollowUpPrompts() (query persons with interaction logged exactly 7 days ago, filter by dismissals) (depends on T023)
- [X] T051 [US5] Update smart_prompt_providers.dart in app/lib/providers/smart_prompt_providers.dart: merge importantDatePrompts + inactivityPrompts + followUpPrompts into a single @riverpod Stream<List<SmartPrompt>> needsAttentionPrompts() (depends on T050, T024)
- [X] T052 [US5] Update SmartPromptCard in app/lib/widgets/smart_prompt_card.dart to handle promptType = 'inactivity' ("You haven't talked to [Name] in [N] months") and promptType = 'follow_up' ("You met [Name] last week — follow up?") with Log interaction / Snooze / Dismiss action buttons (depends on T051)
- [X] T053 [US5] Implement Snooze bottom sheet in app/lib/widgets/smart_prompt_card.dart: modal with three options (Tomorrow / 3 days / Next week); on selection sets dismissedUntil via SmartPromptDismissalsDao (depends on T052, T014)
- [X] T054 [US5] Implement Dismiss action in app/lib/widgets/smart_prompt_card.dart: calls SmartPromptDismissalsDao.insert with dismissedUntil = today + 30 days for inactivity/follow_up types (depends on T052, T014)

**Checkpoint**: All three Needs Attention prompt types surface correctly; Snooze and Dismiss work; 30-day suppression prevents re-appearance.

---

## Phase 8: Polish & Cross-Cutting Concerns

- [X] T055 [P] Update research.md in specs/017-voice-smart-logging/research.md: correct record version to ^6.1.1; add note that flutter_slidable ^4.0.3 requires Flutter 3.27.0+; document hybrid STT approach (speech_to_text for live preview, backend Whisper as future upgrade path)
- [X] T056 [P] Verify NSMicrophoneUsageDescription is present in app/ios/Runner/Info.plist (from prior session) and confirm NSMicrophoneUsageDescription string matches privacy-appropriate wording
- [X] T057 Run `flutter analyze` from app/ and fix all new lint warnings introduced by this feature
- [X] T058 Run `dart run build_runner build --delete-conflicting-outputs` final pass from app/ and confirm all generated files are up to date
- [X] T059 Update CLAUDE.md Active Technologies section to reflect schema v5→v6 and list new packages added by this feature (record, speech_to_text, just_audio, flutter_slidable, permission_handler)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately; T002, T003 can run in parallel with T001 and T004
- **Foundational (Phase 2)**: Depends on Phase 1 completion — BLOCKS all user stories; T005/T006/T007 parallel, then T008, then T009; T010 parallel, then T011; T012 parallel with drift work; T013/T014/T015 parallel after T009
- **US1 (Phase 3)**: Depends on Foundational — T016/T017 parallel, then T018→T019 (server); T020/T021 parallel, then T022 (client); T023→T024→T025→T026 (smart prompts); T027 independent
- **US2 (Phase 4)**: Depends on Foundational + T027 (logging bar pre-link); T028/T029/T030 parallel, then T031, T032, T034; T035/T036/T037 parallel (except T038 depends on T037)
- **US3 (Phase 5)**: Depends on Foundational; T039→T040/T041 parallel→T042→T043
- **US4 (Phase 6)**: Depends on Foundational; T044/T045 parallel→T046→T047/T048→T049
- **US5 (Phase 7)**: Depends on US1 T023, T014; T050→T051→T052→T053/T054
- **Polish (Phase 8)**: Depends on all user stories complete

### User Story Dependencies

- **US1 (P1)**: No dependency on other user stories — pure independent delivery
- **US2 (P2)**: Depends only on T027 from US1 (logging bar pre-link parameter)
- **US3 (P3)**: Fully independent — can be developed in parallel with US2
- **US4 (P4)**: Fully independent — compact layout and swipe gestures are self-contained
- **US5 (P5)**: Depends on US1 SmartPromptService (T023) and SmartPromptDismissalsDao (T014)

### Parallel Opportunities

- **Phase 1**: T002, T003, T004 all run after T001 (pubspec); T003 and T004 are independent of each other
- **Phase 2**: T005, T006, T007, T010 all start in parallel; T012 (migrate-up) runs immediately after T004
- **Phase 3 US1 server path**: T016, T017 run in parallel; server and client work proceed independently
- **Phase 4 US2**: T028, T029, T030 (three services) all run in parallel
- **Phase 6 US4**: T044, T045 (padding + structure) run in parallel before Slidable wrapping

---

## Parallel Example: User Story 1

```text
# Server path (parallel with client):
T016: ImportantDatesService in server/internal/service/important_dates.go
  → T018: ImportantDatesHandler
    → T019: Register routes in router.go

# Client path (parallel with server):
T017: person_important_dates_providers.dart
  → T020: ImportantDatesSection widget
  → T021: ImportantDateFormSheet widget
    → T022: Restructure PersonDetailScreen

# Smart prompt path (starts after T013, T014):
T023: SmartPromptService.watchImportantDatePrompts()
  → T024: smart_prompt_providers.dart
    → T025: SmartPromptCard for important_date type
      → T026: Done / Snooze actions
```

## Parallel Example: User Story 2

```text
# Three services in parallel:
T028: VoiceRecorderService
T029: TranscriptionService
T030: AudioPlayerService
  → T031: voice_log_providers.dart
    → T032: LoggingBar second-row restructure
      → T033: VoiceRecordingOverlay
        → T034: Wire mic button + save pipeline

# Badge + player (parallel after foundation):
T035: VoiceLogBadge widget
  → T036: LogCard shows badge
T037: AudioPlayerWidget
  → T038: Log detail screen shows player
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL — blocks all stories)
3. Complete Phase 3: User Story 1 — Important Dates
4. **STOP and VALIDATE**: Add a birthday to a contact; confirm reminder surfaces in Needs Attention
5. Ship US1 independently — all other user stories add value incrementally

### Incremental Delivery

1. Phase 1 + 2 → Foundation ready
2. Phase 3 (US1) → Important dates end-to-end ✅ MVP
3. Phase 4 (US2) → Voice logging ✅ Core speed feature
4. Phase 5 (US3) → Smart person detection ✅ Reduces linking friction
5. Phase 6 (US4) → Compact UI + swipe gestures ✅ Visual density
6. Phase 7 (US5) → Smart follow-up prompts ✅ Full CRM intelligence

### Parallel Team Strategy (if staffed)

After Phase 2 completes:
- Developer A: US1 (important dates — server + client)
- Developer B: US2 (voice recording + transcription)
- Developer C: US4 (compact cards + slidable gestures)
- US3 and US5 can be picked up by whoever finishes first

---

## Notes

- `[P]` tasks = different files, no cross-task file conflicts
- `[Story]` label maps each task to its user story for independent traceability
- All five user stories are independently testable after Phase 2 completes
- `speech_to_text` note: Android does not support offline recognition — transcription status will show 'pending' for Android offline sessions until connectivity is restored
- `flutter_slidable` note: verify Flutter SDK version (T002) before finalizing package version; v3 and v4 share identical `startActionPane`/`endActionPane` API
- Backend Whisper transcription upgrade path (future): add `POST /v1/audio/transcribe` endpoint; replace TranscriptionService cloud path
- Commit after each completed task or logical group; each checkpoint represents a shippable increment
