import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offline_farmer_dss/models/weather_model.dart';
import '../providers/weather_provider.dart';
import '../providers/sync_provider.dart';
import '../providers/farm_provider.dart';
import '../widgets/loading_indicator.dart';

class WeatherScreen extends ConsumerWidget {
  const WeatherScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weatherAsync = ref.watch(weatherDataProvider);
    final selectedFarmAsync = ref.watch(selectedFarmProvider);
    final syncStatus = ref.watch(syncStatusProvider);

    return RefreshIndicator(
      onRefresh: () async {
        final sync = ref.read(syncServiceProvider);
        final selectedFarm = await ref.read(selectedFarmProvider.future);
        if (selectedFarm != null) {
          await sync.syncWeatherForFarm(selectedFarm);
          ref.invalidate(weatherDataProvider);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ongeza au chagua shamba kwanza ili kuona hali ya hewa.')),
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.green.shade50, Colors.green.shade100],
          ),
        ),
        child: Column(
          children: [
            if (syncStatus)
              Container(
                color: Colors.green.shade300,
                padding: const EdgeInsets.all(8),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Taarifa mpya zimewekwa!', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            Expanded(
              child: selectedFarmAsync.when(
                data: (farm) {
                  return Column(
                    children: [
                      // Farm info card
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.agriculture, color: Colors.green.shade700),
                                    const SizedBox(width: 8),
                                    Text(
                                      farm != null ? farm.cropType.toUpperCase() : 'Hakuna shamba',
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                if (farm != null) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _infoChip(Icons.straighten, 'Eneo: ${farm.areaHectares} ha'),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _infoChip(Icons.terrain, farm.soilType),
                                      ),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Text(
                                  'Tarehe: ${_formattedDate(DateTime.now())}',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Weather list
                      Expanded(
                        child: weatherAsync.when(
                          data: (weatherList) => _buildWeatherList(weatherList),
                          loading: () => const LoadingIndicator(),
                          error: (err, _) => Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.error_outline, color: Colors.red.shade700, size: 48),
                                const SizedBox(height: 8),
                                Text('Imeshindwa kupata taarifa:\n$err', textAlign: TextAlign.center),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: () => ref.invalidate(weatherDataProvider),
                                  child: const Text('Jaribu tena'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const LoadingIndicator(),
                error: (err, _) => Center(child: Text('Error loading farm: $err')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherList(List<WeatherData> weatherList) {
    if (weatherList.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Hakuna taarifa za hali ya hewa.\nBonyeza kushusha ili kupata.'),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: weatherList.length,
      itemBuilder: (context, index) {
        final w = weatherList[index];
        final isToday = w.date.day == DateTime.now().day && w.date.month == DateTime.now().month;
        return Card(
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(colors: [Colors.white, Colors.green.shade50]),
            ),
            child: ListTile(
              leading: Icon(_getWeatherIcon(w.rainfallMm, w.maxTemp), size: 40, color: Colors.green.shade800),
              title: Text(
                _formatDate(w.date),
                style: TextStyle(
                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  color: isToday ? Colors.green.shade900 : Colors.black87,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Joto: ${w.minTemp.round()}°C – ${w.maxTemp.round()}°C'),
                  Text('Mvua: ${w.rainfallMm.toStringAsFixed(1)} mm'),
                  if (w.humidityPercent > 0) Text('Unyevu: ${w.humidityPercent}%'),
                ],
              ),
              trailing: w.rainfallMm > 20
                  ? Chip(
                      label: const Text('Mvua nyingi', style: TextStyle(color: Colors.white)),
                      backgroundColor: Colors.blue.shade700,
                    )
                  : null,
            ),
          ),
        );
      },
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.green.shade700),
          const SizedBox(width: 6),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.day == now.day && date.month == now.month && date.year == now.year) {
      return 'Leo, ${date.day}/${date.month}';
    } else if (date.day == now.add(const Duration(days: 1)).day && date.month == now.month) {
      return 'Kesho, ${date.day}/${date.month}';
    }
    return '${date.day}/${date.month}';
  }

  String _formattedDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

  IconData _getWeatherIcon(double rain, double maxTemp) {
    if (rain > 20) return Icons.grain;
    if (rain > 5) return Icons.cloud_queue;
    if (maxTemp > 30) return Icons.wb_sunny;
    return Icons.wb_cloudy;
  }
}