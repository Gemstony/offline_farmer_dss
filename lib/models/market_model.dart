
import 'package:hive/hive.dart';

part 'market_model.g.dart';

@HiveType(typeId: 2)
class MarketPrice {
  @HiveField(0)
  String cropName;

  @HiveField(1)
  double pricePerKg;        // Tanzanian Shillings (TZS)

  @HiveField(2)
  String marketName;        // example., 'Morogoro Market'

  @HiveField(3)
  DateTime lastUpdated;

  MarketPrice({
    required this.cropName,
    required this.pricePerKg,
    required this.marketName,
    required this.lastUpdated,
  });
}