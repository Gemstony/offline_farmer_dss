
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/farm_provider.dart';
import '../providers/weather_provider.dart';
import '../models/farm_model.dart';
import '../models/weather_model.dart';
import '../widgets/loading_indicator.dart';

class AdviceScreen extends ConsumerWidget {
  const AdviceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farms = ref.watch(farmListProvider);
    final weatherAsync = ref.watch(weatherDataProvider);

    if (farms.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 64, color: Colors.green.shade700),
            const SizedBox(height: 16),
            Text('Hakuna shamba lililoongezwa.\nTafadhali ongeza shamba kwanza.',
                 textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/add_farm'),
              child: Text('Ongeza Shamba'),
            ),
          ],
        ),
      );
    }

    // Use the first farm for advice
    final farm = farms.first;

    return weatherAsync.when(
      data: (weatherList) {
        if (weatherList.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_off, size: 64, color: Colors.green.shade700),
                const SizedBox(height: 16),
                Text('Hakuna taarifa za hali ya hewa.\nSasisha hali ya hewa kwanza.',
                     textAlign: TextAlign.center),
                ElevatedButton(
                  onPressed: () => ref.invalidate(weatherDataProvider),
                  child: Text('Sasisha'),
                ),
              ],
            ),
          );
        }

        final recommendations = _generateRecommendations(farm, weatherList);
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.green.shade50, Colors.green.shade100],
            ),
          ),
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: recommendations.length,
            itemBuilder: (context, index) {
              final rec = recommendations[index];
              return Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _getCategoryColor(rec.category),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(_getCategoryIcon(rec.category), color: Colors.white),
                    ),
                    title: Text(
                      rec.title,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    subtitle: Text(rec.description),
                    isThreeLine: true,
                    trailing: rec.isUrgent ? Icon(Icons.warning_amber, color: Colors.orange) : null,
                  ),
                ),
              );
            },
          ),
        );
      },
      loading: () => const LoadingIndicator(),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }

  List<RecommendationItem> _generateRecommendations(Farm farm, List<WeatherData> forecast) {
    List<RecommendationItem> list = [];

    // 1. Planting advice based on next 3 days rainfall
    final next3Days = forecast.take(3);
    double totalRain = next3Days.fold(0, (sum, day) => sum + day.rainfallMm);
    if (totalRain < 10) {
      list.add(RecommendationItem(
        title: 'Kumwagilia',
        description: 'Mvua kidogo inatarajiwa siku 3 zijazo. Anza kumwagilia ikiwa udongo ni mchanga.',
        category: 'irrigation',
        isUrgent: true,
      ));
    } else if (totalRain > 50) {
      list.add(RecommendationItem(
        title: 'Mvua nyingi',
        description: 'Mvua kubwa inakuja. Hakikisha mifereji ya maji iko wazi ili kuepuka mafuriko.',
        category: 'general',
        isUrgent: true,
      ));
    }

    // 2. Fertilizer advice based on soil type and crop
    if (farm.cropType == 'maize') {
      if (farm.soilType == 'sandy') {
        list.add(RecommendationItem(
          title: 'Mbolea kwa Mahindi',
          description: 'Udongo wa mchanga unahitaji mbolea ya urea na DAP. Tumia kwa kiwango cha 50kg/hekta.',
          category: 'fertilizer',
        ));
      } else if (farm.soilType == 'clay') {
        list.add(RecommendationItem(
          title: 'Mbolea kwa Mahindi',
          description: 'Udongo wa mfinyanzi – punguza matumizi ya nitrojeni. Tumia mbolea ya fosforasi zaidi.',
          category: 'fertilizer',
        ));
      }
    }

    // 3. Pest risk alert based on humidity (if available) and rainfall
    if (forecast.any((day) => day.rainfallMm > 15 && day.humidityPercent > 70)) {
      list.add(RecommendationItem(
        title: 'Hatari ya wadudu',
        description: 'Hali ya unyevu na mvua inaweza kuleta wadudu (kwa mfano, nzige au viwavi). Kagua shamba lako.',
        category: 'pest',
        isUrgent: true,
      ));
    }

    // 4. Harvest window (if planting date known)
    if (farm.plantingDate.isBefore(DateTime.now())) {
      final daysSincePlanting = DateTime.now().difference(farm.plantingDate).inDays;
      if (farm.cropType == 'maize' && daysSincePlanting > 90 && daysSincePlanting < 120) {
        list.add(RecommendationItem(
          title: 'Kuvuna Mahindi',
          description: 'Mahindi yako yamefikia wiki 12-17. Angalia ikiwa maganda yamekauka – ni wakati wa kuvuna.',
          category: 'harvest',
          isUrgent: false,
        ));
      }
    }

    if (list.isEmpty) {
      list.add(RecommendationItem(
        title: 'Hali nzuri',
        description: 'Kwa sasa hakuna ushauri maalum. Endelea kulima kwa bidii na ufuate mbinu bora za kilimo.',
        category: 'general',
        isUrgent: false,
      ));
    }

    return list;
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'irrigation': return Colors.blue;
      case 'fertilizer': return Colors.brown;
      case 'pest': return Colors.red;
      case 'harvest': return Colors.orange;
      default: return Colors.green;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'irrigation': return Icons.water_drop;
      case 'fertilizer': return Icons.agriculture;
      case 'pest': return Icons.bug_report;
      case 'harvest': return Icons.agriculture;
      default: return Icons.lightbulb;
    }
  }
}

class RecommendationItem {
  final String title;
  final String description;
  final String category;
  final bool isUrgent;

  RecommendationItem({
    required this.title,
    required this.description,
    required this.category,
    this.isUrgent = false,
  });
}