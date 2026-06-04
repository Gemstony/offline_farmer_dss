import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offline_farmer_dss/models/market_model.dart';
import '../providers/market_provider.dart';
import '../providers/farm_provider.dart';
import '../widgets/loading_indicator.dart';
import '../providers/sync_provider.dart';

class MarketScreen extends ConsumerWidget {
  const MarketScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final marketPricesAsync = ref.watch(marketPricesProvider);
    final selectedFarmAsync = ref.watch(selectedFarmProvider);
    final syncStatus = ref.watch(syncStatusProvider);

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(syncNotifierProvider.future);
        ref.invalidate(marketPricesProvider);
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
                    Text('Bei mpya zimewekwa!', style: TextStyle(color: Colors.white)),
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
                      // Market prices list
                      Expanded(
                        child: marketPricesAsync.when(
                          data: (prices) => _buildMarketList(prices),
                          loading: () => const LoadingIndicator(),
                          error: (err, _) => Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.error_outline, color: Colors.red.shade700, size: 48),
                                const SizedBox(height: 8),
                                Text('Imeshindwa kupata bei:\n$err', textAlign: TextAlign.center),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: () => ref.invalidate(marketPricesProvider),
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

  Widget _buildMarketList(List<MarketPrice> prices) {
    if (prices.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.store_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Hakuna bei za masoko.\nBonyeza kushusha ili kupata.'),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: prices.length,
      itemBuilder: (context, index) {
        final p = prices[index];
        return Card(
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: ListTile(
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(_getCropIcon(p.cropName), color: Colors.green.shade800, size: 30),
            ),
            title: Text(p.cropName.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Soko: ${p.marketName}'),
                Text('Iliyosasishwa: ${_formatDate(p.lastUpdated)}'),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'TZS ${p.pricePerKg.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                ),
                const Text('/kg', style: TextStyle(fontSize: 12)),
              ],
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

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';
  String _formattedDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

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