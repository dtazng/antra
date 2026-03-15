import 'package:just_audio/just_audio.dart';

/// Service wrapping `just_audio` for local audio file playback.
///
/// Used to play back voice log recordings from within the log detail view.
class AudioPlayerService {
  AudioPlayerService() : _player = AudioPlayer();

  final AudioPlayer _player;

  /// Stream of [PlayerState] changes (playing, paused, completed, etc.).
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  /// Stream of the current playback position.
  Stream<Duration> get positionStream => _player.positionStream;

  /// Stream of the total audio duration (available after [loadFile]).
  Stream<Duration?> get durationStream => _player.durationStream;

  /// The total audio duration, or null if no file has been loaded.
  Duration? get duration => _player.duration;

  /// Whether the player is currently playing.
  bool get isPlaying => _player.playing;

  // ---------------------------------------------------------------------------
  // Playback controls
  // ---------------------------------------------------------------------------

  /// Loads an audio file from [path] and prepares it for playback.
  Future<void> loadFile(String path) async {
    await _player.setFilePath(path);
  }

  /// Starts or resumes playback.
  Future<void> play() => _player.play();

  /// Pauses playback.
  Future<void> pause() => _player.pause();

  /// Seeks to [position].
  Future<void> seek(Duration position) => _player.seek(position);

  /// Stops playback and resets position.
  Future<void> stop() => _player.stop();

  void dispose() {
    _player.dispose();
  }
}
