
import 'package:dio/dio.dart';
import '../models/weather_model.dart';

class WeatherApiService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://api.open-meteo.com/v1',
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ));

  /// Fetch 7‑day forecast for the given coordinates.
  /// Returns a list of WeatherData (one per day) or throws an exception.
  Future<List<WeatherData>> fetch7DayForecast(double latitude, double longitude) async {
    try {
      final response = await _dio.get(
        '/forecast',
        queryParameters: {
          'latitude': latitude,
          'longitude': longitude,
          'daily': 'temperature_2m_max,temperature_2m_min,rain_sum',
          'timezone': 'Africa/Maputo', // Tanzania (UTC+3)
          'forecast_days': 7,
        },
      );

      final data = response.data;
      if (data == null || data['daily'] == null) {
        throw Exception('Invalid response from weather API');
      }

      final daily = data['daily'];
      final List<String> dates = List<String>.from(daily['time']);
      final List<double> maxTemps = (daily['temperature_2m_max'] as List)
          .map((e) => (e as num).toDouble())
          .toList();
      final List<double> minTemps = (daily['temperature_2m_min'] as List)
          .map((e) => (e as num).toDouble())
          .toList();
      final List<double> rainfall = (daily['rain_sum'] as List)
          .map((e) => (e as num).toDouble())
          .toList();

      List<WeatherData> forecast = [];
      for (int i = 0; i < dates.length; i++) {
        forecast.add(WeatherData(
          date: DateTime.parse(dates[i]),
          maxTemp: maxTemps[i],
          minTemp: minTemps[i],
          rainfallMm: rainfall[i],
          humidityPercent: -1, // Open-Meteo free does not provide humidity in daily; keep -1 as unknown
        ));
      }

      //returning a list of WeatherData objects representing the 7-day forecast
      return forecast;
    } on DioException catch (e) {
      // Network or server error
      throw Exception('Weather API failed: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error fetching weather: $e');
    }
  }
}