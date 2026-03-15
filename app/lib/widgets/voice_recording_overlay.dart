import 'dart:async';

import 'package:flutter/material.dart';

import 'package:antra/widgets/glass_surface.dart';

/// Overlay shown at the bottom of the screen while recording or transcribing.
///
/// Displays:
/// - A red pulse recording indicator
/// - Elapsed recording time (updated by the parent via [elapsedSeconds])
/// - "Transcribing…" label when [isTranscribing] is true
/// - A Cancel button (hidden while transcribing)
class VoiceRecordingOverlay extends StatefulWidget {
  const VoiceRecordingOverlay({
    super.key,
    required this.elapsedSeconds,
    required this.isTranscribing,
    required this.onCancel,
  });

  final int elapsedSeconds;
  final bool isTranscribing;
  final VoidCallback onCancel;

  @override
  State<VoiceRecordingOverlay> createState() => _VoiceRecordingOverlayState();
}

class _VoiceRecordingOverlayState extends State<VoiceRecordingOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    unawaited(_pulseController.repeat(reverse: true));
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      style: GlassStyle.bar,
      padding: EdgeInsets.zero,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              // Pulse indicator
              AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, __) => Opacity(
                  opacity: widget.isTranscribing ? 0.3 : _pulseAnim.value,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Status text
              if (widget.isTranscribing)
                const Expanded(
                  child: Text(
                    'Transcribing…',
                    style: TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                )
              else
                Expanded(
                  child: Text(
                    'Recording  ${_formatTime(widget.elapsedSeconds)}',
                    style: const TextStyle(
                        fontSize: 14, color: Colors.white70),
                  ),
                ),

              // Cancel button (hidden during transcription)
              if (!widget.isTranscribing)
                TextButton(
                  onPressed: widget.onCancel,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white54,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Cancel',
                      style: TextStyle(fontSize: 13)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
