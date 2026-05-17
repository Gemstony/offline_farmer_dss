import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import '../models/farm_model.dart';
import '../models/weather_model.dart';
import '../models/market_model.dart';

class DatabaseService {
  // Singleton instance
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static const String _farmBoxName = 'farms';
  static const String _weatherBoxName = 'weather_cache';
  static const String _marketBoxName = 'market_prices';

  late final Box<Farm> _farmBox;
  late final Box<WeatherData> _weatherBox;
  late final Box<MarketPrice> _marketBox;

  bool _isInitialized = false;

  /// Initialize Hive and open boxes – call once at app start
  Future<void> init() async {
    if (_isInitialized) return;
    final dir = await getApplicationDocumentsDirectory();
    Hive.init(dir.path);

    // Register adapters only if not already registered
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(FarmAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(WeatherDataAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(MarketPriceAdapter());
    }

    _farmBox = await Hive.openBox<Farm>(_farmBoxName);
    _weatherBox = await Hive.openBox<WeatherData>(_weatherBoxName);
    _marketBox = await Hive.openBox<MarketPrice>(_marketBoxName);
    _isInitialized = true;
  }

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) await init();
  }

  // ==================== Farm Operations ====================
  Future<void> upsertFarm(Farm farm) async {
    await _ensureInitialized();
    await _farmBox.put(farm.id, farm);
  }

  Future<List<Farm>> getAllFarms() async {
    await _ensureInitialized();
    return _farmBox.values.toList();
  }

  Future<Farm?> getFarmById(String id) async {
    await _ensureInitialized();
    return _farmBox.get(id);
  }

  Future<void> deleteFarm(String id) async {
    await _ensureInitialized();
    await _farmBox.delete(id);
  }

  Future<void> deleteAllFarms() async {
    await _ensureInitialized();
    await _farmBox.clear();
  }

  // ==================== Weather Cache ====================
  Future<void> cacheWeather(List<WeatherData> forecast) async {
    await _ensureInitialized();
    await _weatherBox.clear();
    for (var day in forecast) {
      await _weatherBox.put(day.date.toIso8601String(), day);
    }
  }

  Future<List<WeatherData>> getCachedWeather() async {
    await _ensureInitialized();
    final list = _weatherBox.values.toList();
    list.sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  Future<void> clearWeatherCache() async {
    await _ensureInitialized();
    await _weatherBox.clear();
  }

  // ==================== Market Cache ====================
  Future<void> cacheMarketPrices(List<MarketPrice> prices) async {
    await _ensureInitialized();
    await _marketBox.clear();
    for (var price in prices) {
      final key = '${price.cropName}_${price.marketName}';
      await _marketBox.put(key, price);
    }
  }

  Future<List<MarketPrice>> getCachedMarketPrices() async {
    await _ensureInitialized();
    return _marketBox.values.toList();
  }

  Future<List<MarketPrice>> getMarketPricesForCrop(String cropName) async {
    await _ensureInitialized();
    return _marketBox.values
        .where((p) => p.cropName.toLowerCase() == cropName.toLowerCase())
        .toList();
  }

  Future<void> clearMarketCache() async {
    await _ensureInitialized();
    await _marketBox.clear();
  }
}