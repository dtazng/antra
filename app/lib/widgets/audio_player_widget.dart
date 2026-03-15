import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import 'package:antra/providers/voice_log_providers.dart';

/// Inline audio player with play/pause, seek bar, and duration display.
///
/// Backed by [audioPlayerServiceProvider]. Auto-loads [audioPath] on first build.
class AudioPlayerWidget extends ConsumerStatefulWidget {
  const AudioPlayerWidget({super.key, required this.audioPath});

  final String audioPath;

  @override
  ConsumerState<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends ConsumerState<AudioPlayerWidget> {
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadAudio();
  }

  Future<void> _loadAudio() async {
    try {
      final svc = ref.read(audioPlayerServiceProvider);
      await svc.loadFile(widget.audioPath);
      if (mounted) setState(() => _loaded = true);
    } catch (_) {}
  }

  String _formatDuration(Duration? d) {
    if (d == null) return '0:00';
    final m = d.inMinutes.remainder(60).toString();
    final s = (d.inSeconds.remainder(60)).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final svc = ref.watch(audioPlayerServiceProvider);

    return StreamBuilder<PlayerState>(
      stream: svc.playerStateStream,
      builder: (context, stateSnap) {
        final isPlaying = stateSnap.data?.playing ?? false;

        return StreamBuilder<Duration>(
          stream: svc.positionStream,
          builder: (context, posSnap) {
            final position = posSnap.data ?? Duration.zero;
            final duration = svc.duration ?? Duration.zero;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  // Play/pause button
                  GestureDetector(
                    onTap: () {
                      if (isPlaying) {
                        svc.pause();
                      } else {
                        svc.play();
                      }
                    },
                    child: Icon(
                      isPlaying
                          ? Icons.pause_circle_filled_rounded
                          : Icons.play_circle_filled_rounded,
                      size: 36,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Position label
                  SizedBox(
                    width: 36,
                    child: Text(
                      _formatDuration(position),
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),

                  // Seek bar
                  Expanded(
                    child: Slider(
                      value: _loaded && duration.inMilliseconds > 0
                          ? (position.inMilliseconds /
                                  duration.inMilliseconds)
                              .clamp(0.0, 1.0)
                          : 0.0,
                      onChanged: _loaded
                          ? (v) => svc.seek(Duration(
                              milliseconds:
                                  (v * duration.inMilliseconds).round()))
                          : null,
                    ),
                  ),

                  // Duration label
                  SizedBox(
                    width: 36,
                    child: Text(
                      _formatDuration(duration),
                      style: const TextStyle(fontSize: 11),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
