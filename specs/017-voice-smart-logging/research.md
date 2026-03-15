# Research: Person Special Dates, Compact UI, Voice Logging, and Intelligent Logging UX

**Branch**: `017-voice-smart-logging` | **Date**: 2026-03-15

---

## Decision 1: Audio Recording Package

**Decision**: `record ^5.0.0`

**Rationale**: The `record` package is the most actively maintained cross-platform Flutter recording package. It supports both tap-to-toggle and press-and-hold patterns naturally, outputs AAC/m4a (optimal for speech), and captures to a file path which is required for audio attachment storage and offline-resilient queuing.

**Alternatives considered**:
- `flutter_sound`: Broader but more complex API; mixing recording and playback into one package increases coupling. Less actively maintained.
- `audio_recorder_plus`: Confirmed non-existent on pub.dev under that name.

**Required iOS permissions** (add to Info.plist):
```xml
<key>NSMicrophoneUsageDescription</key>
<string>Antra Log uses the microphone to record voice notes.</string>
```

**Required Android permissions** (add to AndroidManifest.xml):
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
```

**Key API pattern**:
```dart
final recorder = AudioRecorder();
// Start
await recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: outputPath);
// Stop → returns file path
final path = await recorder.stop();
// Cancel
await recorder.cancel();
```

---

## Decision 2: Speech-to-Text (Transcription)

**Decision**: `speech_to_text ^7.3.0` — on-device / platform-native ASR

**Rationale**: Uses Apple AVSpeechRecognizer (iOS) and Google Speech API (Android) via the platform layer. Both are disclosed in each platform's standard privacy policy. This avoids transmitting audio to a novel third-party service, satisfying the constitution's privacy requirement. No extra user consent is required beyond the existing microphone permission.

**Key limitation**: The `speech_to_text` package does not save an audio file — it provides live text results from the microphone. Therefore, recording and transcription require two separate packages running concurrently.

**Concurrency constraint**: Android prohibits two concurrent microphone consumers. Resolution: on Android, use `record` for audio file capture and `speech_to_text` for transcription sequentially (transcription requested after recording stops, re-opening the mic briefly). On iOS, both can run simultaneously.

**Practical approach**: Run `record` for audio file capture. On iOS, also run `speech_to_text` in parallel for live transcript. On Android, after recording stops, request a brief re-listen with `speech_to_text` to produce the transcript from the same content read aloud, OR upload to the backend transcription endpoint (see Decision 3).

**Fallback for Android**: For MVP, capture audio with `record` and display transcription status as "Transcription pending" on Android. iOS users get live, automatic transcription.

**Alternative considered**: OpenAI Whisper (cloud) — highly accurate, offline-capable after upload, but would require explicit user opt-in disclosure and backend infrastructure. Deferred to a future Pro tier feature.

---

## Decision 3: Backend Transcription Endpoint (Deferred)

**Decision**: Not in scope for this release. Audio files stored locally only.

**Rationale**: On-device transcription via `speech_to_text` satisfies the primary use case on iOS (dominant platform). Backend transcription (Whisper or Google STT) would require: a new backend endpoint, audio file upload infrastructure, S3 or equivalent file storage, and explicit user privacy disclosure. All deferred to next release.

**Future path**: Add `POST /v1/audio/transcribe` endpoint to Go backend that accepts multipart audio file upload and returns transcript. Backend wraps a configurable STT provider.

---

## Decision 4: Audio Playback Package

**Decision**: `just_audio ^0.10.5`

**Rationale**: 4.1k likes, 680k weekly downloads, 150 pub points. Verified publisher (ryanheise.com). Reactive stream-based state management aligns with Riverpod patterns. Supports `AudioSource.file()` for local file playback with seek/pause/play. More popular and slightly better maintained than `audioplayers`.

**Key API pattern**:
```dart
final player = AudioPlayer();
await player.setAudioSource(AudioSource.file(audioFilePath));
await player.play();
// Seek
await player.seek(Duration(seconds: 5));
// State stream for UI
player.playerStateStream.listen((state) { ... });
```

---

## Decision 5: Timeline Swipe Gestures

**Decision**: `flutter_slidable ^4.0.3`

**Rationale**: Flutter Favorite package. 6k likes, 542k weekly downloads. Supports both `startActionPane` (swipe right → quick actions) and `endActionPane` (swipe left → delete) with clean `SlidableAction` widgets. Dismisses automatically on scroll. `DrawerMotion` matches the app's calm aesthetic.

**Key API pattern**:
```dart
Slidable(
  key: ValueKey(entry.id),
  startActionPane: ActionPane(
    motion: const DrawerMotion(),
    children: [
      SlidableAction(icon: Icons.alarm_add_outlined, label: 'Follow up', onPressed: (_) => ...),
      SlidableAction(icon: Icons.edit_outlined, label: 'Edit', onPressed: (_) => ...),
      SlidableAction(icon: Icons.person_add_outlined, label: 'Link', onPressed: (_) => ...),
    ],
  ),
  endActionPane: ActionPane(
    motion: const DrawerMotion(),
    children: [
      SlidableAction(
        icon: Icons.delete_outline,
        backgroundColor: Colors.red,
        onPressed: (_) => ...,
      ),
    ],
  ),
  child: LogCard(entry: entry),
)
```

**Note**: Requires `SlidableAutoCloseBehavior` wrapper at the list level to close open items when another is opened or the list scrolls.

---

## Decision 6: Important Dates — Client-Side Storage

**Decision**: New drift table `PersonImportantDates` in the Flutter app; mirrored in Go backend as `person_important_dates`.

**Schema**:
- `id` — client-generated UUID
- `person_id` — FK to people
- `label` — text (e.g., "Birthday", "Anniversary")
- `is_birthday` — bool, controls special visual treatment
- `month` — integer 1–12
- `day` — integer 1–31
- `year` — nullable integer (year optional)
- `reminder_offset_days` — nullable integer (negative = before, positive = after, null = no reminder)
- `reminder_recurrence` — text: 'yearly' | 'once' | null
- `note` — nullable text
- `created_at`, `updated_at`, `sync_id`, `device_id`, `is_deleted`

**Reminder rule storage**: The preset values map to `reminder_offset_days`:
| Preset | reminder_offset_days |
|--------|---------------------|
| No reminder | null |
| On the day | 0 |
| 1 day before | -1 |
| 3 days before | -3 |
| 1 week before | -7 |
| 2 weeks before | -14 |
| 1 month before | -30 |
| Custom | any integer |

---

## Decision 7: Voice Log Fields — Bullets Table Extension

**Decision**: Add columns to existing `Bullets` drift table (schema migration v5 → v6).

**New columns**:
- `audioFilePath` — nullable text (local file path, relative to app documents dir)
- `audioDurationSeconds` — nullable integer
- `transcriptText` — nullable text (same as `content` when transcription complete; separate for retry logic)
- `transcriptionStatus` — nullable text: 'pending' | 'transcribing' | 'complete' | 'failed' | null (null = not a voice log)
- `sourceType` — nullable text: 'typed' | 'voice' | null (null = legacy, treated as typed)

**Migration**: Additive nullable columns only — no data loss for existing rows.

---

## Decision 8: Smart Prompts — Client-Side Computation

**Decision**: Smart prompts are computed entirely on the client from local DB data. No backend involvement.

**Rationale**: All data needed (last interaction dates, important date thresholds) is available locally. Client-side computation avoids server roundtrips, works offline, and keeps the server free of per-user heuristics that are hard to test and scale.

**Inactivity prompt trigger**: `people WHERE lastInteractionAt < now() - 90 days AND isDeleted = 0`
**Post-interaction prompt**: Scheduled via a follow-up entry 7 days after any interaction log is created with a person link.
**Important date prompt**: Daily on-device check: `person_important_dates WHERE (today.month == month AND today.day >= day + reminder_offset_days)`

**Dismissed state**: A `SmartPromptDismissals` drift table (lightweight): `person_id`, `prompt_type`, `dismissed_until` — checked client-side before surfacing a card.

---

## Decision 9: Person Name Detection Algorithm

**Decision**: Client-side exact + prefix name matching against the user's local people list.

**Algorithm**:
1. Tokenize log text into words and 2–3-word phrases
2. Compare against all non-deleted person names (case-insensitive)
3. Match on: exact full name, exact first name (if unique among contacts), first + last name prefix
4. Exclude stop words and common words to reduce false positives
5. Surface up to 5 suggestions; dismiss silently if ignored for > 3 days

**Privacy**: All computation is local. No text is transmitted for name detection.

---

## New Packages Summary

| Package | Version | Purpose |
|---------|---------|---------|
| `record` | ^5.0.0 | Audio file recording (mic → m4a file) |
| `speech_to_text` | ^7.3.0 | On-device live transcription (iOS primary) |
| `just_audio` | ^0.10.5 | Local audio file playback in detail view |
| `flutter_slidable` | ^4.0.3 | Swipe gestures on timeline cards |
| `permission_handler` | ^11.0.0 | Runtime microphone permission requests |
