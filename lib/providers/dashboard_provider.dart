import 'package:flutter_riverpod/flutter_riverpod.dart';

// Provider to manage the bottom navigation index globally
final bottomNavIndexProvider = StateProvider<int>((ref) {
  return 0; // Default to Dashboard (index 0)
});
