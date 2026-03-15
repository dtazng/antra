import 'package:flutter/material.dart';

import 'package:antra/models/linked_person.dart';

/// Compact rounded chip displaying a [LinkedPerson] name.
///
/// Used in timeline cards, log detail view, and anywhere multiple
/// linked persons need to be displayed with wrapping.
class PersonChip extends StatelessWidget {
  final LinkedPerson person;
  final VoidCallback? onTap;

  const PersonChip({super.key, required this.person, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final chip = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 120),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: cs.primaryContainer.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          person.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: cs.onPrimaryContainer,
          ),
        ),
      ),
    );

    if (onTap == null) return chip;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: chip,
    );
  }
}
