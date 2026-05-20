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
            Text(
              'Hakuna shamba lililoongezwa.\nTafadhali ongeza shamba kwanza.',
              textAlign: TextAlign.center,
            ),
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
                Text(
                  'Hakuna taarifa za hali ya hewa.\nSasisha hali ya hewa kwanza.',
                  textAlign: TextAlign.center,
                ),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
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
                      child: Icon(
                        _getCategoryIcon(rec.category),
                        color: Colors.white,
                      ),
                    ),
                    title: Text(
                      rec.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    subtitle: Text(rec.description),
                    isThreeLine: true,
                    trailing: rec.isUrgent
                        ? Icon(Icons.warning_amber, color: Colors.orange)
                        : null,
                  ),
                ),
              );
            },
          ),
        );
      },
      loading: () => const LoadingIndicator(),
      error: (err, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade700, size: 48),
            const SizedBox(height: 8),
            Text(
              'Imeshindwa kupata taarifa za hali ya hewa:\n$err',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.invalidate(weatherDataProvider),
              child: const Text('Jaribu tena'),
            ),
          ],
        ),
      ),
    );
  }

  List<RecommendationItem> _generateRecommendations(
    Farm farm,
    List<WeatherData> forecast,
  ) {
    List<RecommendationItem> list = [];

    // 1. Planting advice based on next 3 days rainfall
    final next3Days = forecast.take(3);
    double totalRain = next3Days.fold(0, (sum, day) => sum + day.rainfallMm);

    if (totalRain < 10) {
      list.add(
        RecommendationItem(
          title: 'Kumwagilia Mazao',
          description:
              'Kiasi cha mvua kinachotarajiwa katika siku 3 zijazo ni kidogo, hivyo udongo unaweza kupoteza unyevu kwa haraka hasa kama ni wa mchanga. Inashauriwa kuanza kumwagilia mazao mapema asubuhi au jioni ili kusaidia mimea kupata maji ya kutosha kwa ukuaji mzuri. Epuka kumwagilia wakati wa jua kali ili kupunguza upotevu wa maji.',
          category: 'irrigation',
          isUrgent: true,
        ),
      );
    } else if (totalRain > 50) {
      list.add(
        RecommendationItem(
          title: 'Tahadhari ya Mvua Kubwa',
          description:
              'Mvua kubwa inatarajiwa kunyesha katika siku chache zijazo. Hakikisha mifereji ya kupitisha maji ipo wazi na maji hayatakusanyika shambani kwani hali hiyo inaweza kusababisha kuoza kwa mizizi, kuharibika kwa mazao au mmomonyoko wa udongo. Kama una mbolea au dawa shambani, zihifadhi sehemu salama zisiosombwa na maji.',
          category: 'general',
          isUrgent: true,
        ),
      );
    }

    // 2. Fertilizer advice based on soil type and crop
    if (farm.cropType == 'maize') {
      if (farm.soilType == 'sandy') {
        list.add(
          RecommendationItem(
            title: 'Matumizi ya Mbolea kwa Mahindi',
            description:
                'Kwa udongo wa mchanga, virutubisho hupotea kwa haraka hivyo mahindi yanahitaji kuongeza nguvu ya lishe mara kwa mara. Inashauriwa kutumia mbolea ya DAP wakati wa kupanda ili kusaidia mizizi kukua vizuri, kisha kuongeza UREA katika hatua ya ukuaji wa majani. Hakikisha mbolea inawekwa kwa kiwango kinachofaa na ichanganywe vizuri na udongo ili kuongeza ufanisi.',
            category: 'fertilizer',
          ),
        );
      } else if (farm.soilType == 'clay') {
        list.add(
          RecommendationItem(
            title: 'Mbolea kwa Udongo wa Mfinyanzi',
            description:
                'Udongo wa mfinyanzi huhifadhi maji na virutubisho kwa muda mrefu zaidi. Kwa mazao ya mahindi, inashauriwa kupunguza matumizi ya mbolea yenye nitrojeni nyingi kwani inaweza kuchelewesha ukuaji wa mahindi. Tumia zaidi mbolea yenye fosforasi na potasiamu kusaidia ukuaji wa mizizi, uimara wa mmea na uzalishaji mzuri.',
            category: 'fertilizer',
          ),
        );
      }
    }

    // 3. Pest risk alert based on humidity and rainfall
    if (forecast.any(
      (day) => day.rainfallMm > 15 && day.humidityPercent > 70,
    )) {
      list.add(
        RecommendationItem(
          title: 'Tahadhari ya Wadudu na Magonjwa',
          description:
              'Kiwango kikubwa cha unyevu pamoja na mvua kinaweza kuongeza hatari ya kushambuliwa na wadudu au magonjwa ya mimea kama viwavi, fangasi au kuoza kwa majani. Inashauriwa kufanya ukaguzi wa mara kwa mara shambani ili kubaini dalili za mapema. Ondoa mimea iliyoathirika na tumia dawa sahihi za kuzuia wadudu au magonjwa pale inapohitajika.',
          category: 'pest',
          isUrgent: true,
        ),
      );
    }

    // 4. Harvest window (if planting date known)
    if (farm.plantingDate.isBefore(DateTime.now())) {
      final daysSincePlanting = DateTime.now()
          .difference(farm.plantingDate)
          .inDays;

      if (farm.cropType == 'maize' &&
          daysSincePlanting > 90 &&
          daysSincePlanting < 120) {
        list.add(
          RecommendationItem(
            title: 'Muda wa Kuvuna Mahindi',
            description:
                'Mahindi yako yanaonekana kufikia hatua nzuri ya kuvunwa kutokana na muda tangu kupandwa. Angalia kama maganda yamekauka, punje zimekuwa ngumu na mmea umeanza kubadilika rangi kuelekea ukavu. Kuvuna kwa wakati husaidia kupunguza hasara inayoweza kusababishwa na wadudu, mvua nyingi au kuanguka kwa mahindi shambani.',
            category: 'harvest',
            isUrgent: false,
          ),
        );
      }
    }
    if (list.isEmpty) {
      list.add(
        RecommendationItem(
          title: 'Hali nzuri',
          description:
              'Kwa sasa hakuna ushauri maalum. Endelea kulima kwa bidii na ufuate mbinu bora za kilimo.',
          category: 'general',
          isUrgent: false,
        ),
      );
    }

    return list;
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'irrigation':
        return Colors.blue;
      case 'fertilizer':
        return Colors.brown;
      case 'pest':
        return Colors.red;
      case 'harvest':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'irrigation':
        return Icons.water_drop;
      case 'fertilizer':
        return Icons.agriculture;
      case 'pest':
        return Icons.bug_report;
      case 'harvest':
        return Icons.agriculture;
      default:
        return Icons.lightbulb;
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
