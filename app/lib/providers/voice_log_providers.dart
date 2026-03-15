import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:antra/services/audio_player_service.dart';
import 'package:antra/services/voice_recorder_service.dart';

part 'voice_log_providers.g.dart';

/// Recording state exposed to the UI.
enum RecordingPhase { idle, recording, transcribing }

/// Manages the voice recording lifecycle: idle → recording → transcribing → idle.
///
/// Backed by [VoiceRecorderService]. Transcription is triggered externally
/// by the logging bar after stopping (T034).
@riverpod
class VoiceRecordingNotifier extends _$VoiceRecordingNotifier {
  late final VoiceRecorderService _recorder;
  String? _currentAudioPath;

  @override
  RecordingPhase build() {
    _recorder = VoiceRecorderService();
    ref.onDispose(_recorder.dispose);

    _recorder.recordingStateStream.listen((rs) {
      switch (rs) {
        case VoiceRecorderState.idle:
          if (state == RecordingPhase.recording) {
            // Stay in transcribing until caller signals complete.
          }
        case VoiceRecorderState.recording:
          state = RecordingPhase.recording;
        case VoiceRecorderState.stopping:
          state = RecordingPhase.transcribing;
      }
    });

    return RecordingPhase.idle;
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Returns true if microphone permission was granted.
  Future<bool> requestPermission() => _recorder.requestPermission();

  /// Starts recording. Returns the file path where audio is saved.
  Future<String> startRecording() => _recorder.startRecording();

  /// Stops recording. Returns the audio file path, or null on failure.
  Future<String?> stopRecording() async {
    final path = await _recorder.stopRecording();
    _currentAudioPath = path;
    return path;
  }

  /// Cancels the active recording without saving.
  Future<void> cancelRecording() async {
    await _recorder.cancelRecording();
    _currentAudioPath = null;
    state = RecordingPhase.idle;
  }

  /// Called after transcription completes to reset the phase.
  void markTranscriptionComplete() {
    state = RecordingPhase.idle;
    _currentAudioPath = null;
  }

  String? get currentAudioPath => _currentAudioPath;
}

/// Provides a single [AudioPlayerService] instance for the current screen.
///
/// Scoped to the widget subtree via [riverpod_annotation] — each usage creates
/// a fresh player. Call [dispose] when the widget is destroyed.
@riverpod
AudioPlayerService audioPlayerService(AudioPlayerServiceRef ref) {
  final svc = AudioPlayerService();
  ref.onDispose(svc.dispose);
  return svc;
}
