import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:antra/database/app_database.dart';
import 'package:antra/database/daos/bullets_dao.dart';
import 'package:antra/providers/database_provider.dart';
import 'package:antra/screens/daily_log/daily_log_screen.dart';
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

  Future<void> _navigateToBullet(Bullet bullet) async {
    final db = await ref.read(appDatabaseProvider.future);
    final dayLog = await BulletsDao(db).getDayLogById(bullet.dayId);
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DailyLogScreen(initialDate: dayLog?.date),
      ),
    );
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
                return InkWell(
                  onTap: () => _navigateToBullet(bullet),
                  child: BulletListItem(bullet: bullet),
                );
              },
            ),
    );
  }
}
