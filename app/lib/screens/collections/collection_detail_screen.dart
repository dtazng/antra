import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:antra/database/app_database.dart';
import 'package:antra/providers/database_provider.dart';
import 'package:antra/screens/daily_log/bullet_detail_screen.dart';
import 'package:antra/screens/daily_log/task_detail_screen.dart';
import 'package:antra/services/collection_filter_engine.dart';
import 'package:antra/widgets/bullet_list_item.dart';

class CollectionDetailScreen extends ConsumerStatefulWidget {
  final Collection collection;

  const CollectionDetailScreen({super.key, required this.collection});

  @override
  ConsumerState<CollectionDetailScreen> createState() =>
      _CollectionDetailScreenState();
}

class _CollectionDetailScreenState
    extends ConsumerState<CollectionDetailScreen> {
  List<Bullet> _bullets = [];

  @override
  void initState() {
    super.initState();
    _subscribeToRules();
  }

  void _subscribeToRules() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final db = await ref.read(appDatabaseProvider.future);
      final engine = CollectionFilterEngine(db);
      engine
          .applyRules(widget.collection.filterRules)
          .listen((bullets) {
        if (mounted) setState(() => _bullets = bullets);
      });
    });
  }

  void _navigateToBullet(Bullet bullet) {
    final route = bullet.type == 'task'
        ? MaterialPageRoute<void>(
            builder: (_) => TaskDetailScreen(bulletId: bullet.id))
        : MaterialPageRoute<void>(
            builder: (_) => BulletDetailScreen(bulletId: bullet.id));
    unawaited(Navigator.of(context).push(route));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.collection.name),
      ),
      body: _bullets.isEmpty
          ? const Center(
              child: Text(
                'No bullets match this collection yet.\n'
                'Bullets matching your filter rules will appear here automatically.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: _bullets.length,
              itemBuilder: (context, index) {
                final bullet = _bullets[index];
                return BulletListItem(
                  bullet: bullet,
                  onTap: () => _navigateToBullet(bullet),
                );
              },
            ),
    );
  }
}
