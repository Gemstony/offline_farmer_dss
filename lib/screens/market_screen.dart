import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/market_provider.dart';
import '../widgets/loading_indicator.dart';
import '../providers/sync_provider.dart';


class MarketScreen extends ConsumerWidget {
  const MarketScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final marketPricesAsync = ref.watch(marketPricesProvider);
    final syncStatus = ref.watch(syncStatusProvider); // reuse from sync_provider

    return RefreshIndicator(
      onRefresh: () async {
        // Trigger full sync (includes market prices)
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
              child: marketPricesAsync.when(
                data: (prices) {
                  if (prices.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.store_outlined, size: 64, color: Colors.green.shade700),
                          const SizedBox(height: 16),
                          Text('Hakuna bei za masoko.\nBonyeza kushusha ili kupata.',
                               textAlign: TextAlign.center,
                               style: TextStyle(fontSize: 16)),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          leading: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _getCropIcon(p.cropName),
                              color: Colors.green.shade800,
                              size: 30,
                            ),
                          ),
                          title: Text(
                            p.cropName.toUpperCase(),
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
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
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade900,
                                ),
                              ),
                              Text('/kg', style: TextStyle(fontSize: 12)),
                            ],
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
                      Text('Imeshindwa kupata bei:\n$err',
                           textAlign: TextAlign.center),
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
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
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