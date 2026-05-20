
import 'package:dio/dio.dart';
import '../models/market_model.dart';

class MarketApiService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  /// Fetch current market prices.
  /// Returns a list of MarketPrice objects.
  /// If a real API endpoint is available, i will replace the mock logic with a real HTTP call.
  Future<List<MarketPrice>> fetchMarketPrices() async {
    // TODO: Replace with actual API endpoint when available
    // Example real endpoint (needs API key, adjust accordingly):
    // const String realApiUrl = 'https://api.example.com/markets/tanzania/prices';
    // try {
    //   final response = await _dio.get(realApiUrl);
    //   final List data = response.data;
    //   return data.map((json) => MarketPrice(
    //     cropName: json['crop'],
    //     pricePerKg: (json['price'] as num).toDouble(),
    //     marketName: json['market'],
    //     lastUpdated: DateTime.parse(json['updated_at']),
    //   )).toList();
    // } catch (e) {
    //   // If real API fails, fallback to mock data
    //   return _getMockPrices();
    // }

    // For now, always return mock data (simulates offline/local fallback)
  // print('Fetching market prices...'); // debug
  // For now, always return mock data (simulates offline/local fallback)
  final mock = _getMockPrices();
  // print('Returned ${mock.length} mock prices');
  return mock;
  }

  /// Static mock data – realistic prices for Tanzanian markets (TZS per kg)
  List<MarketPrice> _getMockPrices() {
    final now = DateTime.now();
    return [
      MarketPrice(
        cropName: 'Maize',
        pricePerKg: 1200,
        marketName: 'Morogoro Municipal Market',
        lastUpdated: now,
      ),
      MarketPrice(
        cropName: 'Maize',
        pricePerKg: 1150,
        marketName: 'Kilosa Market',
        lastUpdated: now,
      ),
      MarketPrice(
        cropName: 'Rice',
        pricePerKg: 2500,
        marketName: 'Morogoro Municipal Market',
        lastUpdated: now,
      ),
      MarketPrice(
        cropName: 'Rice',
        pricePerKg: 2400,
        marketName: 'Ifakara Market',
        lastUpdated: now,
      ),
      MarketPrice(
        cropName: 'Beans',
        pricePerKg: 1800,
        marketName: 'Morogoro Municipal Market',
        lastUpdated: now,
      ),
      MarketPrice(
        cropName: 'Beans',
        pricePerKg: 1750,
        marketName: 'Kilosa Market',
        lastUpdated: now,
      ),
      MarketPrice(
        cropName: 'Cassava',
        pricePerKg: 800,
        marketName: 'Morogoro Municipal Market',
        lastUpdated: now,
      ),
      MarketPrice(
        cropName: 'Tomatoes',
        pricePerKg: 1500,
        marketName: 'Mazimbu Market',
        lastUpdated: now,
      ),
    ];
  }
}