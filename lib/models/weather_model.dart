
import 'package:hive/hive.dart';

part 'weather_model.g.dart';

@HiveType(typeId: 1)
class WeatherData {
  @HiveField(0)
  DateTime date;

  @HiveField(1)
  double maxTemp;           // °C

  @HiveField(2)
  double minTemp;           // °C

  @HiveField(3)
  double rainfallMm;        // mm

  @HiveField(4)
  int humidityPercent;      // 0-100, -1 if unknown

  WeatherData({
    required this.date,
    required this.maxTemp,
    required this.minTemp,
    required this.rainfallMm,
    required this.humidityPercent,
  });
}
