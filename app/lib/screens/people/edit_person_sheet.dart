import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:antra/database/app_database.dart';
import 'package:antra/database/daos/people_dao.dart';
import 'package:antra/providers/database_provider.dart';

const _relationshipTypes = [
  'Friend',
  'Family',
  'Colleague',
  'Mentor',
  'Acquaintance',
  'Other',
];

class EditPersonSheet extends ConsumerStatefulWidget {
  final PeopleData person;

  const EditPersonSheet({super.key, required this.person});

  @override
  ConsumerState<EditPersonSheet> createState() => _EditPersonSheetState();
}

class _EditPersonSheetState extends ConsumerState<EditPersonSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _companyController;
  late final TextEditingController _roleController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _locationController;
  late final TextEditingController _notesController;
  final TextEditingController _tagInputController = TextEditingController();

  String? _selectedRelationshipType;
  DateTime? _birthday;
  List<String> _tags = [];
  bool _isSaving = false;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    final p = widget.person;
    _nameController = TextEditingController(text: p.name);
    _companyController = TextEditingController(text: p.company ?? '');
    _roleController = TextEditingController(text: p.role ?? '');
    _emailController = TextEditingController(text: p.email ?? '');
    _phoneController = TextEditingController(text: p.phone ?? '');
    _locationController = TextEditingController(text: p.location ?? '');
    _notesController = TextEditingController(text: p.notes ?? '');
    _selectedRelationshipType = p.relationshipType;
    _birthday =
        p.birthday != null ? DateTime.tryParse(p.birthday!) : null;
    _tags = p.tags != null
        ? p.tags!
            .split(',')
            .map((t) => t.trim())
            .where((t) => t.isNotEmpty)
            .toList()
        : [];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _companyController.dispose();
    _roleController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    _tagInputController.dispose();
    super.dispose();
  }

  void _addTag(String raw) {
    final tag = raw.trim().toLowerCase();
    if (tag.isEmpty) return;
    if (_tags.contains(tag)) {
      _tagInputController.clear();
      return;
    }
    if (_tags.length >= 20) return;
    setState(() {
      _tags.add(tag);
      _tagInputController.clear();
    });
  }

  void _removeTag(String tag) => setState(() => _tags.remove(tag));

  Future<void> _pickBirthday() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(1990),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: 'Select birthday',
    );
    if (picked != null) setState(() => _birthday = picked);
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Name is required');
      return;
    }
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
      _nameError = null;
    });

    try {
      final db = await ref.read(appDatabaseProvider.future);

      String? strOrNull(String s) => s.trim().isEmpty ? null : s.trim();

      await PeopleDao(db).updatePerson(
        PeopleCompanion(
          id: Value(widget.person.id),
          name: Value(name),
          company: Value(strOrNull(_companyController.text)),
          role: Value(strOrNull(_roleController.text)),
          email: Value(strOrNull(_emailController.text)),
          phone: Value(strOrNull(_phoneController.text)),
          location: Value(strOrNull(_locationController.text)),
          notes: Value(strOrNull(_notesController.text)),
          birthday: Value(
              _birthday != null
                  ? '${_birthday!.year.toString().padLeft(4, '0')}-'
                      '${_birthday!.month.toString().padLeft(2, '0')}-'
                      '${_birthday!.day.toString().padLeft(2, '0')}'
                  : null),
          relationshipType: Value(_selectedRelationshipType),
          tags: Value(_tags.isEmpty ? null : _tags.join(',')),
        ),
      );

      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Edit Person',
                      style: Theme.of(context).textTheme.titleMedium),
                  TextButton(
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Save'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  // Name (required)
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Name *',
                      errorText: _nameError,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    textCapitalization: TextCapitalization.words,
                    onChanged: (_) {
                      if (_nameError != null) {
                        setState(() => _nameError = null);
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  // Company + Role side-by-side
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _companyController,
                          decoration: InputDecoration(
                            labelText: 'Company',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _roleController,
                          decoration: InputDecoration(
                            labelText: 'Role / Title',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Email
                  TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon: const Icon(Icons.email_outlined, size: 18),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),

                  // Phone
                  TextField(
                    controller: _phoneController,
                    decoration: InputDecoration(
                      labelText: 'Phone',
                      prefixIcon: const Icon(Icons.phone_outlined, size: 18),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),

                  // Location
                  TextField(
                    controller: _locationController,
                    decoration: InputDecoration(
                      labelText: 'Location',
                      prefixIcon:
                          const Icon(Icons.location_on_outlined, size: 18),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Birthday picker
                  InkWell(
                    onTap: _pickBirthday,
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Birthday',
                        prefixIcon: const Icon(Icons.cake_outlined, size: 18),
                        suffixIcon: _birthday != null
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () =>
                                    setState(() => _birthday = null),
                              )
                            : null,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        _birthday != null
                            ? '${_birthday!.year}-'
                                '${_birthday!.month.toString().padLeft(2, '0')}-'
                                '${_birthday!.day.toString().padLeft(2, '0')}'
                            : 'Not set',
                        style: TextStyle(
                          color: _birthday != null
                              ? null
                              : cs.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Relationship type
                  Text('Relationship type',
                      style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      for (final rt in _relationshipTypes)
                        ChoiceChip(
                          label: Text(rt),
                          selected: _selectedRelationshipType == rt,
                          onSelected: (selected) => setState(() {
                            _selectedRelationshipType =
                                selected ? rt : null;
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Tags
                  Text('Tags',
                      style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 8),
                  if (_tags.isNotEmpty) ...[
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final tag in _tags)
                          Chip(
                            label: Text(tag,
                                style: const TextStyle(fontSize: 12)),
                            deleteIcon: const Icon(Icons.close, size: 14),
                            onDeleted: () => _removeTag(tag),
                            padding: EdgeInsets.zero,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (_tags.length < 20)
                    TextField(
                      controller: _tagInputController,
                      decoration: InputDecoration(
                        hintText: 'Add a tag…',
                        prefixIcon: const Icon(Icons.label_outline, size: 18),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 10),
                      ),
                      textInputAction: TextInputAction.done,
                      onSubmitted: _addTag,
                    ),
                  const SizedBox(height: 16),

                  // Notes
                  TextField(
                    controller: _notesController,
                    decoration: InputDecoration(
                      labelText: 'Context notes',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    minLines: 3,
                    maxLines: 6,
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: 24),

                  // Save button
                  FilledButton(
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Save'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
