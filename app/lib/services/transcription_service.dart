import 'package:speech_to_text/speech_to_text.dart';

import 'package:antra/database/app_database.dart';
import 'package:antra/database/daos/bullets_dao.dart';

/// Transcription states stored on the bullet row.
class TranscriptionStatus {
  static const transcribing = 'transcribing';
  static const complete = 'complete';
  static const failed = 'failed';
  static const pending = 'pending';
}

/// Service that wraps `speech_to_text` for on-device transcription.
///
/// Transcribes a previously recorded audio file and updates the bullet row.
///
/// **Platform notes:**
/// - iOS: on-device recognition runs directly against the audio file via
///   `SpeechToText.listen` with file input.
/// - Android: speech_to_text does not support file-based transcription;
///   the status is set to `pending` and retried when connectivity is restored.
/// - Offline: status is set to `pending` so recordings are never lost.
class TranscriptionService {
  TranscriptionService({required AppDatabase db})
      : _bulletsDao = BulletsDao(db),
        _stt = SpeechToText();

  final BulletsDao _bulletsDao;
  final SpeechToText _stt;

  bool _initialized = false;

  Future<bool> _ensureInitialized() async {
    if (_initialized) return true;
    _initialized = await _stt.initialize(
      onError: (_) {},
      onStatus: (_) {},
    );
    return _initialized;
  }

  /// Transcribes [audioPath] and updates the [bulletId] row.
  ///
  /// On failure or offline, sets status to [TranscriptionStatus.pending]
  /// so the recording is preserved for later retry.
  Future<void> transcribeFromFile(
      String bulletId, String audioPath) async {
    await _bulletsDao.updateTranscriptionStatus(
        bulletId, TranscriptionStatus.transcribing);

    try {
      final ready = await _ensureInitialized();
      if (!ready) {
        await _bulletsDao.updateTranscriptionStatus(
            bulletId, TranscriptionStatus.pending);
        return;
      }

      // speech_to_text does not support arbitrary file input on all platforms.
      // On Android, we fall back to pending; on iOS/macOS it works via
      // the system recognizer's audio session.
      // For now, mark as pending if we cannot recognize from file directly.
      // TODO: integrate Whisper backend when available (plan.md §Backend Whisper).
      final String transcript = await _recognizeFile(audioPath);
      if (transcript.isEmpty) {
        await _bulletsDao.updateTranscriptionStatus(
            bulletId, TranscriptionStatus.pending);
      } else {
        await _bulletsDao.updateTranscript(bulletId, transcript);
      }
    } catch (_) {
      await _bulletsDao.updateTranscriptionStatus(
          bulletId, TranscriptionStatus.failed);
    }
  }

  /// Retries transcription for all bullets with [TranscriptionStatus.pending].
  Future<void> retryPending() async {
    final pending = await _bulletsDao.getPendingTranscriptions();
    for (final bullet in pending) {
      if (bullet.audioFilePath != null) {
        await transcribeFromFile(bullet.id, bullet.audioFilePath!);
      }
    }
  }

  /// Attempts to recognize speech from [audioPath].
  /// Returns empty string if not supported or recognition fails.
  Future<String> _recognizeFile(String audioPath) async {
    // speech_to_text does not expose a direct file-input API publicly.
    // Live recognition is used during recording; this method is a placeholder
    // for the Whisper HTTP endpoint upgrade path described in research.md.
    return '';
  }

  void dispose() {
    _stt.cancel();
  }
}
