import 'package:flutter/material.dart';

/// Small badge shown below a voice log entry in the timeline.
///
/// States:
/// - `transcribing` → "Transcribing…"
/// - `failed`       → "Transcription failed — tap to retry" (red)
/// - otherwise      → "Voice note • [N] sec"
class VoiceLogBadge extends StatelessWidget {
  const VoiceLogBadge({
    super.key,
    this.transcriptionStatus,
    this.audioDurationSeconds,
    this.onRetry,
  });

  final String? transcriptionStatus;
  final int? audioDurationSeconds;

  /// Called when the user taps the "tap to retry" state.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: transcriptionStatus == 'failed' ? onRetry : null,
      child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              transcriptionStatus == 'failed'
                  ? Icons.error_outline_rounded
                  : Icons.mic_rounded,
              size: 12,
              color: transcriptionStatus == 'failed'
                  ? Colors.redAccent.withValues(alpha: 0.8)
                  : Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.4),
            ),
            const SizedBox(width: 4),
            Text(
              _label,
              style: TextStyle(
                fontSize: 11,
                color: transcriptionStatus == 'failed'
                    ? Colors.redAccent.withValues(alpha: 0.8)
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.4),
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _label {
    switch (transcriptionStatus) {
      case 'transcribing':
        return 'Transcribing…';
      case 'failed':
        return 'Transcription failed — tap to retry';
      default:
        if (audioDurationSeconds != null && audioDurationSeconds! > 0) {
          return 'Voice note • ${audioDurationSeconds}s';
        }
        return 'Voice note';
    }
  }
}
