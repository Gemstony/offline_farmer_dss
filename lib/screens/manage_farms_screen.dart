// lib/screens/manage_farms_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offline_farmer_dss/providers/weather_provider.dart';
import '../providers/farm_provider.dart';
import '../models/farm_model.dart';
import 'edit_farm_screen.dart';

class ManageFarmsScreen extends ConsumerWidget {
  const ManageFarmsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmsAsync = ref.watch(farmListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dhibiti Shamba', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.green.shade50, Colors.green.shade100],
          ),
        ),
        child: farmsAsync.when(
          data: (farms) {
            if (farms.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.agriculture_outlined, size: 80, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('Hakuna shamba bado', style: TextStyle(fontSize: 18)),
                    SizedBox(height: 8),
                    Text('Bonyeza "+" kuongeza shamba', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: farms.length,
              itemBuilder: (ctx, index) {
                final farm = farms[index];
                return _buildFarmCard(context, ref, farm);
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error: $err')),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const EditFarmScreen()),
          ).then((_) => ref.invalidate(farmListProvider));
        },
        child: const Icon(Icons.add),
        backgroundColor: Colors.green,
      ),
    );
  }

  Widget _buildFarmCard(BuildContext context, WidgetRef ref, Farm farm) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: const EdgeInsets.only(bottom: 16),
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
                  child: Icon(_getCropIcon(farm.cropType), color: Colors.green.shade800),
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
                      Text('Eneo: ${farm.areaHectares} hekta', style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'edit') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => EditFarmScreen(farm: farm)),
                      ).then((_) => ref.invalidate(farmListProvider));
                    } else if (value == 'delete') {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Futa Shamba'),
                          content: Text('Je, una uhakika unataka kufuta shamba la ${farm.cropType}?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Ghairi')),
                            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Futa', style: TextStyle(color: Colors.red))),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        final db = ref.read(databaseServiceProvider);
                        await db.deleteFarm(farm.id);
                        ref.invalidate(farmListProvider);
                        ref.invalidate(selectedFarmProvider);
                        ref.invalidate(weatherDataProvider);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Shamba limefutwa'), backgroundColor: Colors.green),
                        );
                      }
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: 'edit', child: Row(
                      children: [Icon(Icons.edit, color: Colors.blue), SizedBox(width: 8), Text('Badilisha')],
                    )),
                    const PopupMenuItem(value: 'delete', child: Row(
                      children: [Icon(Icons.delete, color: Colors.red), SizedBox(width: 8), Text('Futa')],
                    )),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _infoChip(Icons.terrain, farm.soilType)),
                const SizedBox(width: 12),
                Expanded(child: _infoChip(Icons.calendar_today, _formatDate(farm.plantingDate))),
              ],
            ),
          ],
        ),
      ),
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