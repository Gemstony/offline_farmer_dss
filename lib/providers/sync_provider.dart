
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/sync_service.dart';
import 'farm_provider.dart';

final syncServiceProvider = Provider<SyncService>((ref) {
  final db = ref.read(databaseServiceProvider);
  return SyncService(db);
});

final syncStatusProvider = StateProvider<bool>((ref) => false);

final syncNotifierProvider = FutureProvider<void>((ref) async {
  final sync = ref.read(syncServiceProvider);
  final farmListNotifier = ref.read(farmListProvider.notifier);
  await sync.syncAll();
  // Refresh farms in case sync updates anything? Weather is separate
  farmListNotifier.refresh();
  ref.read(syncStatusProvider.notifier).state = true;
  // Reset status after a short delay
  Future.delayed(Duration(seconds: 2), () {
    ref.read(syncStatusProvider.notifier).state = false;
  });
});