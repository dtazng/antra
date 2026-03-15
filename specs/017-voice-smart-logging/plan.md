# Implementation Plan: Person Special Dates, Compact UI, Voice Logging, and Intelligent Logging UX

**Branch**: `017-voice-smart-logging` | **Date**: 2026-03-15 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/017-voice-smart-logging/spec.md`

## Summary

Add structured important dates (birthdays, anniversaries) to person profiles with reminder generation, voice logging with on-device transcription, smart person detection from log text, compact card layout with swipe gestures, and intelligent follow-up prompts — all implemented client-side to remain offline-capable. Backend additions include a `person_important_dates` table, voice log metadata columns on `logs`, and a REST API for important dates CRUD.

## Technical Context

**Language/Version**: Dart 3.3+ / Flutter 3.19+
**Primary Dependencies**: flutter_riverpod 2.5, riverpod_annotation 2.3, drift 2.18, record ^5.0.0, speech_to_text ^7.3.0, just_audio ^0.10.5, flutter_slidable ^4.0.3, permission_handler ^11.0.0, uuid 4.x, intl 0.19
**Storage**: SQLite via drift + SQLCipher (schema v5 → v6). PostgreSQL backend: new `person_important_dates` table + 5 nullable columns on `logs`.
**Testing**: flutter_test (unit + widget)
**Target Platform**: iOS 15+, Android
**Project Type**: mobile-app
**Performance Goals**: Log entry visible within 500ms of confirm; voice log started within 2s; 60 fps scroll; app launch unaffected
**Constraints**: offline-capable, <150MB memory, voice recordings must never be lost, no data transmitted to third parties without user consent
**Scale/Scope**: Existing user base; 2 new drift tables, 5 new Bullets columns, 5 new packages, 1 new backend table, 1 new backend migration

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### I. Code Quality ✅

- New services (`VoiceRecorderService`, `TranscriptionService`, `PersonDetectionService`, `SmartPromptService`) each have a single clear responsibility.
- All new drift tables defined in dedicated `tables/` files with typed DAOs; no direct SQL in UI layer.
- `record` and `speech_to_text` are wrapped in service classes — UI never holds raw recorder state.
- Additive nullable columns only — no backwards-incompatible schema changes; no dead migration paths.

### II. Testing Standards ✅

- Offline voice recording path (audio saved locally when offline) **must** have explicit test coverage per constitution.
- Each acceptance scenario (US1–US5) must have at least one happy-path and one edge-case test.
- Smart prompt generation logic is pure Dart (no Flutter imports) — injectable with mock DB in tests.

### III. UX Consistency ✅

- Capture speed is sacred: voice log started in < 2s; log entry visible within 500ms after confirm.
- Smart prompts (important date reminders, inactivity cards, follow-up cards) are passive and dismissible without penalty — no badges, streaks, or pressure.
- Swipe gestures (right = quick actions, left = delete) applied consistently across the full timeline — same gesture learned once works everywhere.
- Offline-transparent: all new features work identically offline; sync status is passive.
- Destructive actions (delete important date, delete log via swipe) require confirmation.

### IV. Performance Requirements ✅

- Drift reactive streams (`Stream<List<T>>`) used for important dates and smart prompts — no polling.
- `flutter_slidable` is a Flutter Favorite; `DrawerMotion` is hardware-accelerated and maintains 60 fps.
- Audio file stored to disk (not memory); `just_audio` streams from file path — memory budget unaffected.
- Person detection runs synchronously on the local people list after log save — no async latency on save path.
- Background transcription queue is processed off the UI thread; no perceptible UI impact.

### Privacy & Data Integrity ✅

- `speech_to_text` uses Apple AVSpeechRecognizer (iOS) and Google Speech API (Android) via the platform layer — covered by each platform's standard privacy disclosure. No new third-party service.
- Audio files encrypted at rest via SQLCipher-protected app documents directory (same encryption used for DB).
- New `PersonImportantDates` drift table participates in standard LWW sync; no silent overwrites possible.
- `SmartPromptDismissals` is client-only (not synced) — no personal data leaves the device for this entity.
- No analytics or telemetry added.

**Post-design re-check**: ✅ All principles pass. No violations requiring justification.

## Project Structure

### Documentation (this feature)

```text
specs/017-voice-smart-logging/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/
│   └── important-dates-api.md
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (repository root)

```text
app/
  lib/
    database/
      tables/
        person_important_dates_table.dart   # new drift table
        smart_prompt_dismissals_table.dart  # new drift table (client-only)
        bullets_table.dart                  # add 5 voice log columns (migration)
      daos/
        person_important_dates_dao.dart     # CRUD + reactive stream
        smart_prompt_dismissals_dao.dart    # dismiss / query
        bullets_dao.dart                    # extend with voice log queries
      app_database.dart                     # register new tables; bump schema v5→v6
    services/
      voice_recorder_service.dart           # record package wrapper (tap + hold modes)
      transcription_service.dart            # speech_to_text wrapper + offline queue
      audio_player_service.dart             # just_audio wrapper for playback
      person_detection_service.dart         # name matching against local people list
      smart_prompt_service.dart             # compute inactivity/follow-up/date prompts
    providers/
      person_important_dates_providers.dart # Riverpod providers for dates + CRUD
      voice_log_providers.dart              # recording state + transcription state
      smart_prompt_providers.dart           # Needs Attention card stream
    screens/
      person_detail/
        person_detail_screen.dart           # restructure layout (header/dates/notes/logs)
        widgets/
          important_dates_section.dart      # compact date rows + Add date
          important_date_form_sheet.dart    # add/edit modal sheet
    widgets/
      log_card.dart                         # compact padding; Slidable wrapper
      logging_bar.dart                      # second row (link/followup/voice); Done btn
      voice_recording_overlay.dart          # recording indicator + elapsed time + cancel
      voice_log_badge.dart                  # "Voice note • N sec" label in timeline
      audio_player_widget.dart              # inline player for log detail
      smart_prompt_card.dart                # update for important-date type + actions
  pubspec.yaml                              # add 5 new packages

server/
  internal/
    db/
      migrations/
        00002_voice_and_important_dates.sql  # create person_important_dates; alter logs
      queries/
        important_dates.sql                  # CRUD queries for sqlc
    service/
      important_dates.go                     # business logic for important dates CRUD
    api/v1/
      important_dates_handler.go             # HTTP handlers (POST/GET/PUT/DELETE)
      router.go                              # register /v1/persons/{id}/important-dates
```

**Structure Decision**: Mobile app (Flutter) + Go API — Option 3 pattern. All smart prompt logic lives in the Flutter app (`services/`) to stay offline-capable. The Go backend handles only the important dates REST API and the `logs` table migration; voice transcription backend endpoint is deferred.

## Complexity Tracking

> No constitution violations — table not required.
