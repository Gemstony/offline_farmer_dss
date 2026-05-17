
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/database_service.dart';
import '../models/farm_model.dart';

// Single instance of DatabaseService (singleton)
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService(); // returns singleton
});

// Provider that watches farms list – updates when farms change (but Hive doesn't notify; we'll manually refresh)
final farmListProvider = StateNotifierProvider<FarmListNotifier, List<Farm>>((ref) {
  final db = ref.read(databaseServiceProvider);
  return FarmListNotifier(db);
});

class FarmListNotifier extends StateNotifier<List<Farm>> {
  final DatabaseService _db;

  FarmListNotifier(this._db) : super([]) {
    refresh();
  }

  Future<void> refresh() async {
    state = await _db.getAllFarms();
  }

  Future<void> addFarm(Farm farm) async {
    await _db.upsertFarm(farm);
    await refresh();
  }

  Future<void> removeFarm(String id) async {
    await _db.deleteFarm(id);
    await refresh();
  }
}