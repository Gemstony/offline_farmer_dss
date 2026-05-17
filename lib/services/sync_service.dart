import 'package:connectivity_plus/connectivity_plus.dart';
import 'database_service.dart';
import 'weather_api_service.dart';
import 'market_api_service.dart';
import '../models/farm_model.dart';

class SyncService {
  final DatabaseService _db;
  final WeatherApiService _weatherApi = WeatherApiService();
  final MarketApiService _marketApi = MarketApiService();

  SyncService(this._db);

  /// Check if device has any internet connection (WiFi or mobile)
  Future<bool> isOnline() async {
    final result = await Connectivity().checkConnectivity();
    return result != ConnectivityResult.none;
  }

  /// Sync weather for a specific farm (uses farm's lat/lon)
  /// Returns true if sync succeeded, false otherwise
  Future<bool> syncWeatherForFarm(Farm farm) async {
    if (!await isOnline()) {
      return false;
    }
    try {
      final forecast = await _weatherApi.fetch7DayForecast(
        farm.latitude,
        farm.longitude,
      );
      await _db.cacheWeather(forecast);
      return true;
    } catch (e) {
      // Log error if needed (e.g., print(e))
      return false;
    }
  }

  /// Sync weather for all farms (typically the first farm – you can extend)
  /// For simplicity, we sync for the first farm (most relevant to user)
  Future<bool> syncWeatherForFirstFarm() async {
    final farms = await _db.getAllFarms();

    if (farms.isEmpty) return false;

    return await syncWeatherForFarm(farms.first);
  }

  /// Sync market prices from API to local cache
  Future<bool> syncMarketPrices() async {
    if (!await isOnline()) {
      // print('Offline: cannot sync market prices');
      return false;
    }
    try {
      final prices = await _marketApi.fetchMarketPrices();
      await _db.cacheMarketPrices(prices);
      // print('Cached ${prices.length} market prices');
      return true;
    } catch (e) {
      // print('Market sync error: $e');
      return false;
    }
  }

  /// Run full sync: market prices + weather for the first farm
  Future<void> syncAll() async {
    if (!await isOnline()) return;

    // Sync market prices
    await syncMarketPrices();

    // Sync weather for the first farm (if any)
    await syncWeatherForFirstFarm();
  }

  /// Optional: Sync everything for a specific farm (market + weather for that farm)
  Future<void> syncAllForFarm(Farm farm) async {
    if (!await isOnline()) return;
    await syncMarketPrices();
    await syncWeatherForFarm(farm);
  }
}
