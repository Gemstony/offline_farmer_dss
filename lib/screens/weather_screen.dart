import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
              child: weatherAsync.when(
                data: (weatherList) {
                  if (weatherList.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.cloud_off, size: 64, color: Colors.green.shade700),
                          const SizedBox(height: 16),
                          Text('Hakuna taarifa za hali ya hewa.\nBonyeza kushusha ili kupata.',
                               textAlign: TextAlign.center,
                               style: TextStyle(fontSize: 16)),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: weatherList.length,
                    itemBuilder: (context, index) {
                      final w = weatherList[index];
                      final isToday = w.date.day == DateTime.now().day &&
                          w.date.month == DateTime.now().month;
                      return Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              colors: [Colors.white, Colors.green.shade50],
                            ),
                          ),
                          child: ListTile(
                            leading: Icon(
                              _getWeatherIcon(w.rainfallMm, w.maxTemp),
                              size: 40,
                              color: Colors.green.shade800,
                            ),
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
                                if (w.humidityPercent > 0)
                                  Text('Unyevu: ${w.humidityPercent}%'),
                              ],
                            ),
                            trailing: w.rainfallMm > 20
                                ? Chip(
                                    label: Text('Mvua nyingi', style: TextStyle(color: Colors.white)),
                                    backgroundColor: Colors.blue.shade700,
                                  )
                                : null,
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const LoadingIndicator(),
                error: (err, stack) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700, size: 48),
                      const SizedBox(height: 8),
                      Text('Imeshindwa kupata taarifa:\n$err',
                           textAlign: TextAlign.center),
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
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.day == now.day && date.month == now.month && date.year == now.year) {
      return 'Leo, ${date.day}/${date.month}';
    } else if (date.day == now.add(Duration(days: 1)).day &&
               date.month == now.month) {
      return 'Kesho, ${date.day}/${date.month}';
    }
    return '${date.day}/${date.month}';
  }

  IconData _getWeatherIcon(double rain, double maxTemp) {
    if (rain > 20) return Icons.grain;
    if (rain > 5) return Icons.cloud_queue;
    if (maxTemp > 30) return Icons.wb_sunny;
    return Icons.wb_cloudy;
  }
}