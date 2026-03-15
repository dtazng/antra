import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:antra/database/app_database.dart';
import 'package:antra/database/daos/bullets_dao.dart';
import 'package:antra/database/daos/people_dao.dart';
import 'package:antra/providers/database_provider.dart';
import 'package:antra/providers/person_detection_providers.dart';
import 'package:antra/providers/voice_log_providers.dart';
import 'package:antra/screens/people/person_picker_sheet.dart';
import 'package:antra/services/person_detection_service.dart';
import 'package:antra/services/transcription_service.dart';
import 'package:antra/theme/app_theme.dart';
import 'package:antra/widgets/glass_surface.dart';
import 'package:antra/widgets/voice_recording_overlay.dart';

const _uuid = Uuid();

/// Text-first quick log bar pinned to the bottom of the day view.
///
/// Layout:
///   Row 1: [text input ···············] [Done]
///   Row 2: [👤 link] [🔔 follow-up] [🎤 mic]   (hidden until focused)
///
/// Pass [initialPersonId] to pre-link a person (e.g. from a smart prompt card).
class QuickLogBar extends ConsumerStatefulWidget {
  const QuickLogBar({
    super.key,
    required this.onInteractionLogged,
    required this.date,
    this.initialPersonId,
    this.externalFocusNode,
  });

  /// Called with the new bullet's ID after a successful save.
  final void Function(String bulletId) onInteractionLogged;

  /// The date (YYYY-MM-DD) to log the interaction to.
  final String date;

  /// When set, the bar opens with this person already linked.
  final String? initialPersonId;

  /// Optional external FocusNode so parent can observe focus state.
  final FocusNode? externalFocusNode;

  @override
  ConsumerState<QuickLogBar> createState() => _QuickLogBarState();
}

class _QuickLogBarState extends ConsumerState<QuickLogBar>
    with SingleTickerProviderStateMixin {
  final _textController = TextEditingController();
  late final FocusNode _focusNode;
  PeopleData? _linkedPerson;
  bool _showSecondRow = false;
  bool _saving = false;
  bool _addFollowUp = false;

  // Elapsed time for recording display
  Timer? _elapsedTimer;
  int _elapsedSeconds = 0;

  // Fade animation for smooth reset after save.
  late AnimationController _resetController;
  late Animation<double> _resetAnim;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.externalFocusNode ?? FocusNode();
    _resetController = AnimationController(
      vsync: this,
      duration: AntraMotion.fadeDismiss,
      value: 1.0,
    );
    _resetAnim = CurvedAnimation(
      parent: _resetController,
      curve: AntraMotion.dismissCurve,
    );
    _focusNode.addListener(() {
      setState(() {
        if (_focusNode.hasFocus) {
          _showSecondRow = true;
        } else if (_textController.text.trim().isEmpty) {
          _showSecondRow = false;
        }
        // Keep second row visible when text is present, even if focus lost
      });
    });
    unawaited(_loadInitialPerson());
  }

  Future<void> _loadInitialPerson() async {
    final pid = widget.initialPersonId;
    if (pid == null) return;
    final db = await ref.read(appDatabaseProvider.future);
    final person = await PeopleDao(db).getPersonById(pid);
    if (person != null && mounted) {
      setState(() {
        _linkedPerson = person;
        _showSecondRow = true;
      });
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    // Only dispose if we created the focus node (not passed in externally)
    if (widget.externalFocusNode == null) _focusNode.dispose();
    _resetController.dispose();
    _elapsedTimer?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final recordingPhase = ref.watch(voiceRecordingNotifierProvider);
    final isRecording = recordingPhase == RecordingPhase.recording;
    final isTranscribing = recordingPhase == RecordingPhase.transcribing;

    // Show overlay when recording is active.
    if (isRecording || isTranscribing) {
      return VoiceRecordingOverlay(
        elapsedSeconds: _elapsedSeconds,
        isTranscribing: isTranscribing,
        onCancel: _cancelRecording,
      );
    }

    return FadeTransition(
      opacity: _resetAnim,
      child: GlassSurface(
        style: GlassStyle.bar,
        padding: EdgeInsets.zero,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Row 1: text input + Done button
                _buildInputRow(context),
                // Row 2: action icons — visible when focused or person linked
                if (_showSecondRow || _linkedPerson != null)
                  _buildActionRow(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Row 1: input + Done
  // ---------------------------------------------------------------------------

  Widget _buildInputRow(BuildContext context) {
    final showCancel = _showSecondRow || _linkedPerson != null;
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _textController,
            focusNode: _focusNode,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              hintText: _linkedPerson != null
                  ? 'Log with ${_linkedPerson!.name}…'
                  : 'Log something…',
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 15),
              isDense: true,
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.08),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: BorderSide.none,
              ),
              // Cancel button inside the field on the right
              suffixIcon: showCancel
                  ? GestureDetector(
                      onTap: _resetState,
                      child: const Icon(Icons.close_rounded,
                          size: 18, color: Colors.white38),
                    )
                  : null,
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _save(context),
          ),
        ),
        // Mic button — always visible
        GestureDetector(
          onTap: _onMicTap,
          onLongPressStart: (_) => _onMicHoldStart(),
          onLongPressEnd: (_) => _onMicHoldEnd(),
          child: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Icon(Icons.mic_none_rounded,
                size: 22, color: Colors.white60),
          ),
        ),
        // Send — shown when there is text
        if (_textController.text.trim().isNotEmpty)
          GestureDetector(
            onTap: _saving ? null : () => _save(context),
            child: Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: _saving
                  ? const SizedBox(
                      height: 14,
                      width: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.arrow_upward_rounded,
                      size: 16, color: Colors.white),
            ),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Row 2: action icons
  // ---------------------------------------------------------------------------

  Widget _buildActionRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          // Linked person chip (or link button)
          if (_linkedPerson != null)
            _ChipButton(
              icon: Icons.person,
              label: _linkedPerson!.name,
              onTap: _pickPerson,
              onClear: () => setState(() => _linkedPerson = null),
            )
          else
            _IconActionButton(
              icon: Icons.person_add_alt_outlined,
              label: 'Link',
              onTap: _pickPerson,
            ),
          const SizedBox(width: 8),

          // Follow-up toggle
          _IconActionButton(
            icon: Icons.notifications_outlined,
            label: 'Follow up',
            active: _addFollowUp,
            onTap: () => setState(() => _addFollowUp = !_addFollowUp),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Interaction logic
  // ---------------------------------------------------------------------------

  Future<void> _pickPerson() async {
    _focusNode.unfocus();
    final person = await showModalBottomSheet<PeopleData>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GlassSurface(
        style: GlassStyle.modal,
        padding: EdgeInsets.zero,
        child: const PersonPickerSheet(),
      ),
    );
    if (!mounted || person == null) return;
    setState(() {
      _linkedPerson = person;
      _showSecondRow = true;
    });
  }

  Future<void> _save(BuildContext context) async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() => _saving = true);
    try {
      final db = await ref.read(appDatabaseProvider.future);
      final bulletsDao = BulletsDao(db);
      final peopleDao = PeopleDao(db);

      final now = DateTime.now().toUtc().toIso8601String();
      final dayLog = await bulletsDao.getOrCreateDayLog(widget.date);
      final bulletId = _uuid.v4();

      await bulletsDao.insertBullet(
        BulletsCompanion.insert(
          id: bulletId,
          dayId: dayLog.id,
          type: const Value('note'),
          content: text,
          status: const Value('open'),
          position: 0,
          createdAt: now,
          updatedAt: now,
          deviceId: 'local',
        ),
      );

      if (_linkedPerson != null) {
        await peopleDao.insertLink(bulletId, _linkedPerson!.id);
      }

      widget.onInteractionLogged(bulletId);

      // Run person detection in background if no person was manually linked.
      if (_linkedPerson == null) {
        final detectionSvc = PersonDetectionService(db: db);
        final detected = await detectionSvc.detect(text);
        if (detected.isNotEmpty && mounted) {
          ref
              .read(personDetectionNotifierProvider(bulletId).notifier)
              .setSuggestions(detected);
        }
      }

      if (mounted) {
        await _resetController.reverse();
        _resetState();
        await _resetController.forward();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Voice recording: tap-to-toggle
  // ---------------------------------------------------------------------------

  Future<void> _onMicTap() async {
    final notifier = ref.read(voiceRecordingNotifierProvider.notifier);
    if (ref.read(voiceRecordingNotifierProvider) == RecordingPhase.recording) {
      await _finishRecording(notifier);
    } else {
      await _beginRecording(notifier);
    }
  }

  // Long-press hold mode
  Future<void> _onMicHoldStart() async {
    final notifier = ref.read(voiceRecordingNotifierProvider.notifier);
    if (ref.read(voiceRecordingNotifierProvider) == RecordingPhase.idle) {
      await _beginRecording(notifier);
    }
  }

  Future<void> _onMicHoldEnd() async {
    final notifier = ref.read(voiceRecordingNotifierProvider.notifier);
    if (ref.read(voiceRecordingNotifierProvider) == RecordingPhase.recording) {
      await _finishRecording(notifier);
    }
  }

  Future<void> _beginRecording(VoiceRecordingNotifier notifier) async {
    final granted = await notifier.requestPermission();
    if (!granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission denied')),
        );
      }
      return;
    }
    setState(() {
      _elapsedSeconds = 0;
      _showSecondRow = true;
    });
    await notifier.startRecording();
    _startElapsedTimer();
  }

  Future<void> _finishRecording(VoiceRecordingNotifier notifier) async {
    _stopElapsedTimer();
    final audioPath = await notifier.stopRecording();
    if (audioPath == null || !mounted) return;

    // Save a voice log bullet.
    try {
      final db = await ref.read(appDatabaseProvider.future);
      final bulletsDao = BulletsDao(db);
      final peopleDao = PeopleDao(db);

      final now = DateTime.now().toUtc().toIso8601String();
      final dayLog = await bulletsDao.getOrCreateDayLog(widget.date);
      final bulletId = _uuid.v4();

      await bulletsDao.insertBullet(
        BulletsCompanion.insert(
          id: bulletId,
          dayId: dayLog.id,
          type: const Value('note'),
          content: 'Voice note',
          status: const Value('open'),
          position: 0,
          createdAt: now,
          updatedAt: now,
          deviceId: 'local',
          sourceType: const Value('voice'),
          audioFilePath: Value(audioPath),
          audioDurationSeconds: Value(_elapsedSeconds),
          transcriptionStatus: const Value(TranscriptionStatus.transcribing),
        ),
      );

      if (_linkedPerson != null) {
        await peopleDao.insertLink(bulletId, _linkedPerson!.id);
      }

      // Kick off transcription in background.
      final transcriptionSvc = TranscriptionService(db: db);
      unawaited(transcriptionSvc
          .transcribeFromFile(bulletId, audioPath)
          .then((_) => notifier.markTranscriptionComplete())
          .catchError((_) => notifier.markTranscriptionComplete()));

      widget.onInteractionLogged(bulletId);
    } catch (e) {
      notifier.markTranscriptionComplete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save voice log: $e')),
        );
      }
    }
  }

  Future<void> _cancelRecording() async {
    _stopElapsedTimer();
    await ref
        .read(voiceRecordingNotifierProvider.notifier)
        .cancelRecording();
  }

  void _startElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
  }

  void _stopElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
  }

  void _resetState() {
    _focusNode.unfocus();
    setState(() {
      _textController.clear();
      _linkedPerson = null;
      _showSecondRow = false;
      _addFollowUp = false;
      _elapsedSeconds = 0;
    });
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _IconActionButton extends StatelessWidget {
  const _IconActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active
              ? Colors.white.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: Colors.white60),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(
                    fontSize: 12, color: Colors.white60)),
          ],
        ),
      ),
    );
  }
}

class _ChipButton extends StatelessWidget {
  const _ChipButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.onClear,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.only(left: 8, right: 4, top: 5, bottom: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.white70),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(
                    fontSize: 12, color: Colors.white70)),
            const SizedBox(width: 2),
            GestureDetector(
              onTap: onClear,
              child: const Icon(Icons.close_rounded,
                  size: 14, color: Colors.white38),
            ),
          ],
        ),
      ),
    );
  }
}
