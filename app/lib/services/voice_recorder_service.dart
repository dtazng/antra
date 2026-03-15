import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

/// State of the voice recorder.
enum VoiceRecorderState { idle, recording, stopping }

/// Service wrapping the `record` package for in-app audio capture.
///
/// Supports both tap-to-toggle and press-and-hold recording modes.
/// Audio is saved as AAC-LC, 16 kHz mono for efficient on-device storage.
class VoiceRecorderService {
  VoiceRecorderService() : _recorder = AudioRecorder();

  final AudioRecorder _recorder;

  final _stateController =
      StreamController<VoiceRecorderState>.broadcast();

  VoiceRecorderState _state = VoiceRecorderState.idle;
  String? _currentPath;

  /// Stream of recording state changes.
  Stream<VoiceRecorderState> get recordingStateStream =>
      _stateController.stream;

  VoiceRecorderState get state => _state;

  // ---------------------------------------------------------------------------
  // Permissions
  // ---------------------------------------------------------------------------

  /// Requests microphone permission. Returns true if granted.
  Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  // ---------------------------------------------------------------------------
  // Recording lifecycle
  // ---------------------------------------------------------------------------

  /// Starts recording to a temp file. Returns the file path.
  /// Throws if permission is denied or the recorder fails to start.
  Future<String> startRecording() async {
    if (_state != VoiceRecorderState.idle) return _currentPath ?? '';

    final hasPermission = await requestPermission();
    if (!hasPermission) {
      throw Exception('Microphone permission denied');
    }

    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 16000,
        numChannels: 1,
        bitRate: 64000,
      ),
      path: path,
    );

    _currentPath = path;
    _emit(VoiceRecorderState.recording);
    return path;
  }

  /// Stops the active recording. Returns the file path, or null if nothing was recorded.
  Future<String?> stopRecording() async {
    if (_state != VoiceRecorderState.recording) return null;
    _emit(VoiceRecorderState.stopping);

    final path = await _recorder.stop();
    _currentPath = null;
    _emit(VoiceRecorderState.idle);
    return path;
  }

  /// Cancels the active recording and deletes the temp file.
  Future<void> cancelRecording() async {
    if (_state == VoiceRecorderState.idle) return;

    await _recorder.stop();
    if (_currentPath != null) {
      try {
        await File(_currentPath!).delete();
      } catch (_) {
        // Best-effort delete.
      }
      _currentPath = null;
    }
    _emit(VoiceRecorderState.idle);
  }

  void dispose() {
    _recorder.dispose();
    _stateController.close();
  }

  void _emit(VoiceRecorderState s) {
    _state = s;
    _stateController.add(s);
  }
}
