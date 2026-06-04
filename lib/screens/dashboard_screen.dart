import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../providers/farm_provider.dart';
import '../providers/weather_provider.dart';
import '../providers/market_provider.dart';
import '../models/farm_model.dart';
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
    setState(() => _username = name ?? 'Mkulima');
  }

  @override
  Widget build(BuildContext context) {
    final selectedFarmAsync = ref.watch(selectedFarmProvider);
    final weatherAsync = ref.watch(weatherDataProvider);
    final marketAsync = ref.watch(marketPricesProvider);

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(syncNotifierProvider.future);
        ref.invalidate(farmListProvider);
        ref.invalidate(selectedFarmProvider);
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
            // Welcome Header (modern gradient card)
            _buildWelcomeHeader(),
            const SizedBox(height: 20),

            // Farm Section (selected farm or empty state)
            _buildFarmSection(selectedFarmAsync),
            const SizedBox(height: 20),

            // Weather Section
            _buildWeatherSection(weatherAsync),
            const SizedBox(height: 20),

            // Market Section
            _buildMarketSection(marketAsync),
            const SizedBox(height: 16),

            // Quick Tip
            _buildQuickTip(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green.shade700, Colors.green.shade500],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person, size: 32, color: Colors.white),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Habari, $_username!',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Leo ni ${_formattedDate(DateTime.now())}',
                    style: TextStyle(color: Colors.white.withOpacity(0.85)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFarmSection(AsyncValue<Farm?> farmAsync) {
    return farmAsync.when(
      data: (farm) {
        if (farm == null) {
          return _buildEmptyFarmState();
        }
        return _buildFarmCard(farm);
      },
      loading: () => const LoadingIndicator(),
      error: (err, _) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildEmptyFarmState() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.agriculture_outlined,
              size: 60,
              color: Colors.green.shade300,
            ),
            const SizedBox(height: 16),
            const Text(
              'Hakuna shamba lililochaguliwa',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Chagua shamba kutoka kwenye menyu (ikoni ya mistari juu kushoto) au ongeza shamba mpya.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              children: [
                ElevatedButton.icon(
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  icon: const Icon(Icons.menu),
                  label: const Text('Chagua Shamba'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/add_farm'),
                  icon: const Icon(Icons.add),
                  label: const Text('Ongeza Shamba'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green.shade700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFarmCard(Farm farm) {
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
          padding: const EdgeInsets.all(20),
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
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
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
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildInfoChip(Icons.terrain, farm.soilType)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInfoChip(
                      Icons.calendar_today,
                      _formattedDate(farm.plantingDate),
                    ),
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

  Widget _buildWeatherSection(AsyncValue<List<WeatherData>> weatherAsync) {
    return weatherAsync.when(
      data: (weather) => _buildWeatherCard(weather),
      loading: () => const LoadingIndicator(),
      error: (err, _) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildWeatherCard(List<WeatherData> weather) {
    if (weather.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(Icons.cloud_off, size: 48, color: Colors.grey),
              const SizedBox(height: 8),
              const Text('Hakuna data ya hali ya hewa'),
              const SizedBox(height: 8),
              Text(
                'Bonyeza kwenye alama ya kusasisha juu',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    final next7 = weather.take(7).toList();
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
                  'Hali ya hewa (siku 7 zijazo)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...next7.map(
              (day) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      _getWeatherIcon(day.rainfallMm, day.maxTemp),
                      size: 24,
                      color: Colors.green.shade700,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${_formattedDateShort(day.date)}: ${day.minTemp}°C–${day.maxTemp}°C, Mvua ${day.rainfallMm} mm',
                        style: const TextStyle(fontSize: 14),
                      ),
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

  Widget _buildMarketSection(AsyncValue<List<MarketPrice>> marketAsync) {
    return marketAsync.when(
      data: (prices) => _buildMarketCard(prices),
      loading: () => const LoadingIndicator(),
      error: (err, _) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildMarketCard(List<MarketPrice> prices) {
    if (prices.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(Icons.store_outlined, size: 48, color: Colors.grey),
              const SizedBox(height: 8),
              const Text('Hakuna bei za masoko'),
              const SizedBox(height: 8),
              Text(
                'Bonyeza kwenye alama ya kusasisha juu',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    final uniqueCrops = prices.map((p) => p.cropName).toSet().take(3).toList();
    final previewPrices = prices
        .where((p) => uniqueCrops.contains(p.cropName))
        .toList();
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.store, color: Colors.green.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Bei za soko',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...previewPrices.map(
              (p) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  _getCropIcon(p.cropName),
                  color: Colors.green.shade700,
                ),
                title: Text(
                  p.cropName.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(p.marketName),
                trailing: Text(
                  'TZS ${p.pricePerKg.toStringAsFixed(0)}/kg',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            if (prices.length > 3)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  '...bofya kitufe cha Masoko kuona zaidi',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickTip() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.lightbulb, color: Colors.orange.shade700),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Kidokezo cha leo',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Kumbuka kukagua shamba lako mara kwa mara. Ukiwa na mashaka kuhusu wadudu, tumia kamera katika kitufe cha "Wadudu".',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formattedDate(DateTime date) =>
      '${date.day}/${date.month}/${date.year}';
  String _formattedDateShort(DateTime date) => '${date.day}/${date.month}';

  IconData _getWeatherIcon(double rain, double maxTemp) {
    if (rain > 20) return Icons.grain;
    if (rain > 5) return Icons.cloud_queue;
    if (maxTemp > 30) return Icons.wb_sunny;
    return Icons.wb_cloudy;
  }

  IconData _getCropIcon(String crop) {
    switch (crop.toLowerCase()) {
      case 'maize':
        return Icons.grass;
      case 'rice':
        return Icons.agriculture;
      case 'beans':
        return Icons.eco;
      case 'cassava':
        return Icons.forest;
      case 'tomatoes':
        return Icons.local_florist;
      default:
        return Icons.agriculture;
    }
  }
}
