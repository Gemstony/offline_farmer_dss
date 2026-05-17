
import 'package:hive/hive.dart';

part 'farm_model.g.dart';

@HiveType(typeId: 0)
class Farm {
  @HiveField(0)
  String id;

  @HiveField(1)
  String cropType;          // e.g., 'maize', 'rice', 'beans'

  @HiveField(2)
  double areaHectares;

  @HiveField(3)
  String soilType;          // 'sandy', 'clay', 'loam'

  @HiveField(4)
  double latitude;

  @HiveField(5)
  double longitude;

  @HiveField(6)
  DateTime plantingDate;    // when crop was planted (optional)

  Farm({
    required this.id,
    required this.cropType,
    required this.areaHectares,
    required this.soilType,
    required this.latitude,
    required this.longitude,
    required this.plantingDate,
  });
}
