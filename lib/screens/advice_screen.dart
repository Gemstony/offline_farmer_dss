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
    final selectedFarmAsync = ref.watch(selectedFarmProvider);
    final weatherAsync = ref.watch(weatherDataProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(selectedFarmProvider);
          ref.invalidate(weatherDataProvider);
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.green.shade50, Colors.green.shade100],
            ),
          ),
          child: selectedFarmAsync.when(
            data: (farm) {
              if (farm == null) {
                return _buildEmptyState(context);
              }
              return weatherAsync.when(
                data: (weatherList) {
                  if (weatherList.isEmpty) {
                    return _buildNoWeatherState(context, ref);
                  }
                  return _buildAdviceContent(farm, weatherList, ref);
                },
                loading: () => const LoadingIndicator(),
                error: (err, stack) => _buildErrorState(
                  context,
                  'Imeshindwa kupata taarifa za hali ya hewa: $err',
                  () => ref.invalidate(weatherDataProvider),
                ),
              );
            },
            loading: () => const LoadingIndicator(),
            error: (err, stack) => _buildErrorState(
              context,
              'Imeshindwa kupata taarifa za shamba: $err',
              () => ref.invalidate(selectedFarmProvider),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.agriculture_outlined, size: 80, color: Colors.green.shade700),
          const SizedBox(height: 16),
          Text(
            'Hakuna shamba lililochaguliwa',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Tafadhali chagua au ongeza shamba kwanza',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Scaffold.of(context).openDrawer(),
            icon: const Icon(Icons.menu),
            label: const Text('Chagua Shamba'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/add_farm'),
            icon: const Icon(Icons.add),
            label: const Text('Ongeza Shamba Mpya'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.green.shade700,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoWeatherState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off, size: 80, color: Colors.green.shade700),
          const SizedBox(height: 16),
          Text(
            'Hakuna taarifa za hali ya hewa',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text('Sasisha hali ya hewa kwa kuvuta chini au bonyeza kitufe cha ku refresh'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => ref.invalidate(weatherDataProvider),
            icon: const Icon(Icons.refresh),
            label: const Text('Sasisha Sasa'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String message, VoidCallback onRetry) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 80, color: Colors.red.shade400),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onRetry,
            child: const Text('Jaribu tena'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdviceContent(Farm farm, List<WeatherData> weatherList, WidgetRef ref) {
    final recommendations = _generateRecommendations(farm, weatherList);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Farm Info Card
          _buildFarmInfoCard(farm),
          const SizedBox(height: 16),

          // Weather Context Card
          _buildWeatherContextCard(weatherList),
          const SizedBox(height: 20),

          // Recommendations Title
          Row(
            children: [
              Icon(Icons.lightbulb, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              Text(
                'Ushauri wako',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // List of Recommendations
          ...recommendations.map((rec) => _buildRecommendationCard(rec)),
        ],
      ),
    );
  }

  Widget _buildFarmInfoCard(Farm farm) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [Colors.white, Colors.green.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      _getCropIcon(farm.cropType),
                      color: Colors.green.shade800,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          farm.cropType.toUpperCase(),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Eneo: ${farm.areaHectares} hekta',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildInfoChip(Icons.terrain, farm.soilType),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInfoChip(Icons.calendar_today, _formatDate(farm.plantingDate)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.green.shade700),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherContextCard(List<WeatherData> weatherList) {
    final next3 = weatherList.take(3).toList();
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cloud_queue, color: Colors.green.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Hali ya hewa (siku 3 zijazo)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...next3.map((day) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(_getWeatherIcon(day.rainfallMm, day.maxTemp), size: 24, color: Colors.green.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${_formatShortDate(day.date)}: ${day.minTemp}°C – ${day.maxTemp}°C, Mvua ${day.rainfallMm} mm',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationCard(RecommendationItem rec) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _getCategoryColor(rec.category).withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getCategoryIcon(rec.category),
                      color: _getCategoryColor(rec.category),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      rec.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (rec.isUrgent)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'HARAKA',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                rec.description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade800,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<RecommendationItem> _generateRecommendations(Farm farm, List<WeatherData> forecast) {
    List<RecommendationItem> list = [];

    // 1. Irrigation advice based on next 3 days rainfall
    final next3Days = forecast.take(3);
    double totalRain = next3Days.fold(0, (sum, day) => sum + day.rainfallMm);

    if (totalRain < 10) {
      list.add(RecommendationItem(
        title: 'Kumwagilia Mazao',
        description: 'Kiasi cha mvua kinachotarajiwa katika siku 3 zijazo ni kidogo. Inashauriwa kuanza kumwagilia mapema asubuhi au jioni ili kusaidia mimea kupata maji ya kutosha kwa ukuaji mzuri. Epuka kumwagilia wakati wa jua kali ili kupunguza upotevu wa maji.',
        category: 'irrigation',
        isUrgent: true,
      ));
    } else if (totalRain > 50) {
      list.add(RecommendationItem(
        title: 'Tahadhari ya Mvua Kubwa',
        description: 'Mvua kubwa inatarajiwa. Hakikisha mifereji ya kupitisha maji ipo wazi na maji hayatakusanyika shambani kwani hali hiyo inaweza kusababisha kuoza kwa mizizi, kuharibika kwa mazao au mmomonyoko wa udongo.',
        category: 'general',
        isUrgent: true,
      ));
    }

    // 2. Fertilizer advice based on soil type and crop
    if (farm.cropType == 'maize') {
      if (farm.soilType == 'sandy') {
        list.add(RecommendationItem(
          title: 'Matumizi ya Mbolea kwa Mahindi',
          description: 'Kwa udongo wa mchanga, virutubisho hupotea kwa haraka. Inashauriwa kutumia mbolea ya DAP wakati wa kupanda, kisha kuongeza UREA katika hatua ya ukuaji wa majani. Hakikisha mbolea inawekwa kwa kiwango kinachofaa na ichanganywe vizuri.',
          category: 'fertilizer',
        ));
      } else if (farm.soilType == 'clay') {
        list.add(RecommendationItem(
          title: 'Mbolea kwa Udongo wa Mfinyanzi',
          description: 'Udongo wa mfinyanzi huhifadhi maji na virutubisho kwa muda mrefu. Inashauriwa kupunguza matumizi ya mbolea yenye nitrojeni nyingi. Tumia zaidi mbolea yenye fosforasi na potasiamu.',
          category: 'fertilizer',
        ));
      }
    }

    // 3. Pest risk alert based on humidity and rainfall
    if (forecast.any((day) => day.rainfallMm > 15 && day.humidityPercent > 70)) {
      list.add(RecommendationItem(
        title: 'Tahadhari ya Wadudu na Magonjwa',
        description: 'Kiwango kikubwa cha unyevu pamoja na mvua kinaweza kuongeza hatari ya kushambuliwa na wadudu au magonjwa ya mimea. Inashauriwa kufanya ukaguzi wa mara kwa mara shambani. Ondoa mimea iliyoathirika na tumia dawa sahihi pale inapohitajika.',
        category: 'pest',
        isUrgent: true,
      ));
    }

    // 4. Harvest window (if planting date known)
    if (farm.plantingDate.isBefore(DateTime.now())) {
      final daysSincePlanting = DateTime.now().difference(farm.plantingDate).inDays;
      if (farm.cropType == 'maize' && daysSincePlanting > 90 && daysSincePlanting < 120) {
        list.add(RecommendationItem(
          title: 'Muda wa Kuvuna Mahindi',
          description: 'Mahindi yako yanaonekana kufikia hatua nzuri ya kuvunwa. Angalia kama maganda yamekauka, punje zimekuwa ngumu na mmea umeanza kubadilika rangi kuelekea ukavu. Kuvuna kwa wakati husaidia kupunguza hasara.',
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

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';
  String _formatShortDate(DateTime date) => '${date.day}/${date.month}';

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

  IconData _getWeatherIcon(double rain, double maxTemp) {
    if (rain > 20) return Icons.grain;
    if (rain > 5) return Icons.cloud_queue;
    if (maxTemp > 30) return Icons.wb_sunny;
    return Icons.wb_cloudy;
  }

  IconData _getCropIcon(String crop) {
    switch (crop.toLowerCase()) {
      case 'maize': return Icons.grass;
      case 'rice': return Icons.agriculture;
      case 'beans': return Icons.eco;
      case 'cassava': return Icons.forest;
      case 'tomatoes': return Icons.local_florist;
      default: return Icons.agriculture;
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