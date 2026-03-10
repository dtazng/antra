import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:antra/database/app_database.dart';
import 'package:antra/database/daos/collections_dao.dart';
import 'package:antra/providers/database_provider.dart';
import 'package:antra/providers/people_provider.dart';

const _uuid = Uuid();

class CreateCollectionSheet extends ConsumerStatefulWidget {
  const CreateCollectionSheet({super.key});

  @override
  ConsumerState<CreateCollectionSheet> createState() =>
      _CreateCollectionSheetState();
}

class _CreateCollectionSheetState
    extends ConsumerState<CreateCollectionSheet> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final List<Map<String, dynamic>> _rules = [];
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final now = DateTime.now().toUtc().toIso8601String();
    final id = _uuid.v4();
    final companion = CollectionsCompanion.insert(
      id: id,
      name: _nameCtrl.text.trim(),
      description: Value(_descCtrl.text.trim().isEmpty
          ? null
          : _descCtrl.text.trim()),
      filterRules: jsonEncode(_rules),
      position: 0,
      createdAt: now,
      updatedAt: now,
      deviceId: 'local',
    );
    final db = await ref.read(appDatabaseProvider.future);
    await CollectionsDao(db).insertCollection(companion);
    if (mounted) Navigator.pop(context);
  }

  void _addTagRule() async {
    final ctrl = TextEditingController();
    final tag = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add tag filter'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'tag name (no #)'),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim().toLowerCase()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx, ctrl.text.trim().toLowerCase()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (tag != null && tag.isNotEmpty) {
      setState(() => _rules.add({'type': 'tag', 'value': tag}));
    }
  }

  void _addPersonRule() async {
    final people = ref.read(allPeopleProvider).asData?.value ?? [];
    if (people.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No people yet.')));
      return;
    }
    final picked = await showDialog<PeopleData>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Filter by person'),
        children: people
            .map(
              (p) => SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, p),
                child: Text(p.name),
              ),
            )
            .toList(),
      ),
    );
    if (picked != null) {
      setState(
          () => _rules.add({'type': 'person', 'personId': picked.id}));
    }
  }

  void _addTypeRule() async {
    const types = ['task', 'note', 'event'];
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Filter by bullet type'),
        children: types
            .map(
              (t) => SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, t),
                child: Text(t),
              ),
            )
            .toList(),
      ),
    );
    if (picked != null) {
      setState(() => _rules.add({'type': 'bullet_type', 'value': picked}));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('New Collection',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Name is required' : null,
                autofocus: true,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Text('Filter Rules',
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              if (_rules.isEmpty)
                const Text(
                  'No rules yet — add at least one.',
                  style: TextStyle(color: Colors.grey),
                ),
              ..._rules.asMap().entries.map(
                    (e) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.rule, size: 18),
                      title: Text(_ruleLabel(e.value)),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle_outline,
                            size: 18),
                        onPressed: () =>
                            setState(() => _rules.removeAt(e.key)),
                      ),
                    ),
                  ),
              const SizedBox(height: 8),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _addTagRule,
                    icon: const Icon(Icons.tag, size: 16),
                    label: const Text('Tag'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _addPersonRule,
                    icon: const Icon(Icons.person_outline, size: 16),
                    label: const Text('Person'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _addTypeRule,
                    icon: const Icon(Icons.label_outline, size: 16),
                    label: const Text('Type'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child:
                      Text(_saving ? 'Saving…' : 'Create Collection'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _ruleLabel(Map<String, dynamic> rule) {
    switch (rule['type']) {
      case 'tag':
        return '#${rule['value']}';
      case 'person':
        return '@${rule['personId']}';
      case 'bullet_type':
        return 'Type: ${rule['value']}';
      case 'date_range':
        return '${rule['from']} – ${rule['to']}';
      default:
        return rule.toString();
    }
  }
}
