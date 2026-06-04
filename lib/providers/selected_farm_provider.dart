// lib/providers/selected_farm_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final selectedFarmIdProvider = StateNotifierProvider<SelectedFarmNotifier, String?>((ref) {
  return SelectedFarmNotifier();
});

class SelectedFarmNotifier extends StateNotifier<String?> {
  static const String _key = 'selected_farm_id';

  SelectedFarmNotifier() : super(null) {
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

  void clearSelectedFarm() async {
    state = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}