import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/market_model.dart';
import 'farm_provider.dart';

final marketPricesProvider = FutureProvider<List<MarketPrice>>((ref) async {
  final db = ref.read(databaseServiceProvider);
  return db.getCachedMarketPrices();
});