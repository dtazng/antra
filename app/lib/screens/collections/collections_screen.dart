import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:antra/providers/collections_provider.dart';
import 'package:antra/screens/collections/collection_detail_screen.dart';
import 'package:antra/screens/collections/create_collection_sheet.dart';

class CollectionsScreen extends ConsumerWidget {
  const CollectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collectionsAsync = ref.watch(allCollectionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Collections')),
      floatingActionButton: FloatingActionButton(
        heroTag: 'collections_fab',
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => const CreateCollectionSheet(),
        ),
        child: const Icon(Icons.add),
      ),
      body: collectionsAsync.when(
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Text(
                'No collections yet.\nTap + to create one.',
                textAlign: TextAlign.center,
              ),
            );
          }
          return ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final col = list[index];
              return ListTile(
                leading: const Icon(Icons.filter_list),
                title: Text(col.name),
                subtitle: col.description != null ? Text(col.description!) : null,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CollectionDetailScreen(collection: col),
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
}
