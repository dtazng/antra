import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:antra/providers/people_provider.dart';
import 'package:antra/screens/people/create_person_sheet.dart';
import 'package:antra/screens/people/person_profile_screen.dart';

class PeopleScreen extends ConsumerWidget {
  const PeopleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final peopleAsync = ref.watch(allPeopleProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('People')),
      floatingActionButton: FloatingActionButton(
        heroTag: 'people_fab',
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => const CreatePersonSheet(),
        ),
        child: const Icon(Icons.person_add_outlined),
      ),
      body: peopleAsync.when(
        data: (personList) {
          if (personList.isEmpty) {
            return _EmptyPeopleState();
          }
          return ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 16),
            itemCount: personList.length,
            itemBuilder: (context, index) {
              final person = personList[index];
              final lastSeen = person.lastInteractionAt != null
                  ? _relativeDate(person.lastInteractionAt!)
                  : 'No interactions yet';
              return _PersonTile(
                person: person,
                lastSeen: lastSeen,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PersonProfileScreen(person: person),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  String _relativeDate(String isoTimestamp) {
    final dt = DateTime.tryParse(isoTimestamp);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '$diff days ago';
    return DateFormat('MMM d').format(dt);
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _PersonTile extends StatelessWidget {
  final dynamic person;
  final String lastSeen;
  final VoidCallback onTap;

  const _PersonTile({
    required this.person,
    required this.lastSeen,
    required this.onTap,
  });

  Color _avatarColor(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final colors = [
      cs.primaryContainer,
      cs.secondaryContainer,
      cs.tertiaryContainer,
      cs.errorContainer,
    ];
    final name = person.name as String;
    return colors[name.codeUnitAt(0) % colors.length];
  }

  Color _avatarFg(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fgColors = [
      cs.onPrimaryContainer,
      cs.onSecondaryContainer,
      cs.onTertiaryContainer,
      cs.onErrorContainer,
    ];
    final name = person.name as String;
    return fgColors[name.codeUnitAt(0) % fgColors.length];
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = person.name as String;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: _avatarColor(context),
              child: Text(
                name[0].toUpperCase(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _avatarFg(context),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    lastSeen,
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: cs.onSurfaceVariant.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }
}

class _EmptyPeopleState extends StatelessWidget {
  const _EmptyPeopleState();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.people_outline_rounded,
              size: 36,
              color: cs.onSurfaceVariant.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No people yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: cs.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap + to add someone',
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant.withOpacity(0.6)),
          ),
        ],
      ),
    );
  }
}
