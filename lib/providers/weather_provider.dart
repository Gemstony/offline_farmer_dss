
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/weather_model.dart';
import 'farm_provider.dart';

final weatherDataProvider = FutureProvider<List<WeatherData>>((ref) async {
  final db = ref.read(databaseServiceProvider);
  return db.getCachedWeather();
});