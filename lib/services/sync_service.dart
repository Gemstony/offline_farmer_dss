import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_service.dart';
import 'weather_api_service.dart';
import 'market_api_service.dart';
import '../models/farm_model.dart';

class SyncService {
  final DatabaseService _db;
  final WeatherApiService _weatherApi = WeatherApiService();
  final MarketApiService _marketApi = MarketApiService();

  SyncService(this._db);

  Future<bool> isOnline() async {
    final result = await Connectivity().checkConnectivity();
    return result != ConnectivityResult.none;
  }

  /// Sync weather for a specific farm
  Future<bool> syncWeatherForFarm(Farm farm) async {
    if (!await isOnline()) return false;
    try {
      final forecast = await _weatherApi.fetch7DayForecast(farm.latitude, farm.longitude);
      await _db.cacheWeather(forecast);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Sync weather for the currently selected farm
  Future<bool> syncWeatherForSelectedFarm() async {
    final selectedId = await _getSelectedFarmId();
    if (selectedId == null) return false;
    final farm = await _db.getFarmById(selectedId);
    if (farm == null) return false;
    return await syncWeatherForFarm(farm);
  }

  /// Sync market prices
  Future<bool> syncMarketPrices() async {
    if (!await isOnline()) return false;
    try {
      final prices = await _marketApi.fetchMarketPrices();
      await _db.cacheMarketPrices(prices);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Full sync for selected farm + market
  Future<void> syncAll() async {
    if (!await isOnline()) return;
    await syncMarketPrices();
    await syncWeatherForSelectedFarm();
  }

  /// Helper to get stored selected farm ID
  Future<String?> _getSelectedFarmId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('selected_farm_id');
  }
}