import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:antra/providers/collections_provider.dart';
import 'package:antra/screens/collections/collection_detail_screen.dart';
import 'package:antra/screens/collections/create_collection_sheet.dart';
import 'package:antra/theme/app_theme.dart';
import 'package:antra/widgets/aurora_background.dart';
import 'package:antra/widgets/glass_surface.dart';

class CollectionsScreen extends ConsumerWidget {
  const CollectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collectionsAsync = ref.watch(allCollectionsProvider);

    return Scaffold(
      backgroundColor: AntraColors.auroraDeepNavy,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('Collections', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'collections_fab',
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const CreateCollectionSheet(),
        ),
        child: const Icon(Icons.add),
      ),
      body: AuroraBackground(
        variant: AuroraVariant.collections,
        child: collectionsAsync.when(
          data: (list) {
            if (list.isEmpty) {
              return const Center(
                child: Text(
                  'No collections yet.\nTap + to create one.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54),
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
              itemCount: list.length,
              itemBuilder: (context, index) {
                final col = list[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GlassSurface(
                    style: GlassStyle.card,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => CollectionDetailScreen(collection: col),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.filter_list, color: Colors.white70),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(col.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  )),
                              if (col.description != null)
                                Text(col.description!,
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 13,
                                    )),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            size: 18, color: Colors.white38),
                      ],
                    ),
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }
}
