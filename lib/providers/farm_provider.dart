import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_service.dart';
import '../models/farm_model.dart';

// Singleton DatabaseService
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});

// Provider that watches the list of all farms
final farmListProvider = FutureProvider<List<Farm>>((ref) async {
  final db = ref.read(databaseServiceProvider);
  return await db.getAllFarms();
});

// Provider for the currently selected farm ID (persisted)
final selectedFarmIdProvider =
    StateNotifierProvider<SelectedFarmIdNotifier, String?>((ref) {
      return SelectedFarmIdNotifier();
    });

class SelectedFarmIdNotifier extends StateNotifier<String?> {
  static const String _key = 'selected_farm_id';

  SelectedFarmIdNotifier() : super(null) {
    _loadSelectedFarm();
  }

  Future<void> _loadSelectedFarm() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_key);
  }

  Future<void> setSelectedFarmId(String farmId) async {
    state = farmId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, farmId);
  }

  Future<void> clearSelectedFarm() async {
    state = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

// Provider that returns the selected Farm object (or null if none)
final selectedFarmProvider = FutureProvider<Farm?>((ref) async {
  final selectedId = ref.watch(selectedFarmIdProvider);
  if (selectedId == null) return null;
  final farms = await ref.watch(farmListProvider.future);
  try {
    return farms.firstWhere((f) => f.id == selectedId);
  } catch (_) {
    return farms.isNotEmpty ? farms.first : null;
  }
});

// Notifier to refresh the farm list manually
final farmListNotifierProvider =
    StateNotifierProvider<FarmListNotifier, AsyncValue<List<Farm>>>((ref) {
      return FarmListNotifier(ref);
    });

class FarmListNotifier extends StateNotifier<AsyncValue<List<Farm>>> {
  final Ref _ref;
  FarmListNotifier(this._ref) : super(const AsyncLoading()) {
    loadFarms();
  }

  Future<void> loadFarms() async {
    state = const AsyncLoading();
    final db = _ref.read(databaseServiceProvider);
    try {
      final farms = await db.getAllFarms();
      state = AsyncData(farms);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }

  Future<void> refresh() async {
    await loadFarms();
  }
}
