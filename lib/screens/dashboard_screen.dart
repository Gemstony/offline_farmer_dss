import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../providers/farm_provider.dart';
import '../providers/weather_provider.dart';
import '../providers/market_provider.dart';
import '../models/weather_model.dart';
import '../models/market_model.dart';
import '../widgets/loading_indicator.dart';
import '../providers/sync_provider.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String? _username;

  @override
  void initState() {
    super.initState();
    _loadUsername();
  }

  Future<void> _loadUsername() async {
    final auth = AuthService();
    final name = await auth.getCurrentUsername();
    setState(() {
      _username = name ?? 'Mkulima';
    });
  }

  @override
  Widget build(BuildContext context) {
    final farmsAsync = ref.watch(farmListProvider);
    final weatherAsync = ref.watch(weatherDataProvider);
    final marketAsync = ref.watch(marketPricesProvider);

    return RefreshIndicator(
      onRefresh: () async {
        // Trigger sync and refresh all
        await ref.read(syncNotifierProvider.future);
        ref.invalidate(farmListProvider);
        ref.invalidate(weatherDataProvider);
        ref.invalidate(marketPricesProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Taarifa zimesasishwa!')),
          );
        }
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade700, Colors.green.shade500],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.person, size: 40, color: Colors.green.shade700),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Karibu, $_username!',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Leo ni ${_formattedDate(DateTime.now())}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Farm Summary Card
            _buildFarmSummary(farmsAsync),
            
            const SizedBox(height: 16),

            // Weather Summary (next 3 days)
            weatherAsync.when(
              data: (weather) => _buildWeatherSummary(weather),
              loading: () => const LoadingIndicator(),
              error: (err, _) => Text('Error: $err'),
            ),
            const SizedBox(height: 16),

            // Market Prices Preview
            marketAsync.when(
              data: (prices) => _buildMarketPreview(prices),
              loading: () => const LoadingIndicator(),
              error: (err, _) => Text('Error: $err'),
            ),
            const SizedBox(height: 16),

            // Quick Tip Card (from advice, or static)
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb, color: Colors.orange.shade700),
                        const SizedBox(width: 8),
                        const Text(
                          'Kidokezo cha leo',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Kumbuka kukagua shamba lako mara kwa mara. '
                      'Ukiwa na mashaka kuhusu wadudu, tumia kamera katika kitufe cha "Wadudu".',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFarmSummary(List farms) {
    if (farms.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(Icons.add_box, size: 48, color: Colors.green.shade400),
              const SizedBox(height: 8),
              const Text('Hujaoongeza shamba lolote bado.'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/add_farm');
                },
                child: const Text('Ongeza Shamba'),
              ),
            ],
          ),
        ),
      );
    }
    final farm = farms.first; // show first farm
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Shamba lako', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Mmea: ${farm.cropType.toUpperCase()}', style: const TextStyle(fontSize: 14)),
            Text('Eneo: ${farm.areaHectares} hekta', style: const TextStyle(fontSize: 14)),
            Text('Udongo: ${farm.soilType}', style: const TextStyle(fontSize: 14)),
            Text('Tarehe ya kupanda: ${_formattedDate(farm.plantingDate)}', style: const TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherSummary(List<WeatherData> weather) {
    if (weather.isEmpty) {
      return Card(
        child: ListTile(
          leading: Icon(Icons.cloud_off, color: Colors.grey),
          title: const Text('Hakuna data ya hali ya hewa'),
          subtitle: const Text('Bonyeza kwenye alama ya kusasisha juu'),
        ),
      );
    }
    final next3 = weather.take(7).toList();
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Hali ya hewa (siku 7 zijazo)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...next3.map((day) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(_getWeatherIcon(day.rainfallMm, day.maxTemp), size: 24, color: Colors.green.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('${_formattedDateShort(day.date)}: ${day.minTemp}°C–${day.maxTemp}°C, Mvua ${day.rainfallMm} mm'),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildMarketPreview(List<MarketPrice> prices) {
    if (prices.isEmpty) {
      return Card(
        child: ListTile(
          leading: Icon(Icons.store, color: Colors.grey),
          title: const Text('Hakuna bei za masoko'),
          subtitle: const Text('Sasisha kwa kuvuta chini au bonyeza ikoni ya kusasisha'),
        ),
      );
    }
    // Show unique crops (first 3)
    final uniqueCrops = prices.map((p) => p.cropName).toSet().take(3).toList();
    final previewPrices = prices.where((p) => uniqueCrops.contains(p.cropName)).toList();
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Bei za soko', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...previewPrices.map((p) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(_getCropIcon(p.cropName), color: Colors.green.shade700),
              title: Text(p.cropName.toUpperCase()),
              subtitle: Text(p.marketName),
              trailing: Text('TZS ${p.pricePerKg.toStringAsFixed(0)}/kg', style: TextStyle(fontWeight: FontWeight.bold)),
            )),
            if (prices.length > 3)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('...bofya kitufe cha Masoko kuona zaidi', style: TextStyle(fontStyle: FontStyle.italic)),
              ),
          ],
        ),
      ),
    );
  }

  String _formattedDate(DateTime date) => '${date.day}/${date.month}/${date.year}';
  String _formattedDateShort(DateTime date) => '${date.day}/${date.month}';

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