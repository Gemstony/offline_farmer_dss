import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offline_farmer_dss/screens/manage_farms_screen.dart';
import 'package:offline_farmer_dss/screens/profile_screen.dart';
import 'package:offline_farmer_dss/screens/weather_screen.dart';
import 'dashboard_screen.dart';
import 'market_screen.dart';
import 'advice_screen.dart';
import 'camera_screen.dart';
import 'add_farm_screen.dart';
import 'login_screen.dart';
import '../widgets/offline_alert.dart';
import '../providers/farm_provider.dart';
import '../providers/weather_provider.dart';
import '../providers/sync_provider.dart';
import '../providers/market_provider.dart';
import '../providers/dashboard_provider.dart';
import '../services/auth_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isSyncing = false;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const WeatherScreen(),
    const MarketScreen(),
    const AdviceScreen(),
    const CameraScreen(),
  ];

  final List<String> _titles = [
    'Nyumbani',
    'Hali ya Hewa',
    'Bei za Masoko',
    'Ushauri wa Kilimo',
    'Kitambulisho cha Wadudu',
  ];

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thibitisha Kutoka'),
        content: const Text('Una uhakika unataka kutoka?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hapana'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Ndiyo'),
          ),
        ],
      ),
    );

    if (shouldLogout != true) {
      return;
    }

    final auth = AuthService();
    await auth.logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final farmsAsync = ref.watch(farmListProvider);
    final selectedFarmId = ref.watch(selectedFarmIdProvider);
    final selectedIndex = ref.watch(bottomNavIndexProvider);

    return OfflineAlert(
      child: Scaffold(
        appBar: AppBar(
          title: Text(_titles[selectedIndex]),
          actions: [
            IconButton(
              icon: _isSyncing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
              onPressed: _isSyncing
                  ? null
                  : () async {
                      setState(() => _isSyncing = true);
                      try {
                        await ref.read(syncNotifierProvider.future);
                        ref.invalidate(weatherDataProvider);
                        ref.invalidate(marketPricesProvider);
                        ref.invalidate(farmListProvider);
                        ref.invalidate(selectedFarmProvider);
                        ref.invalidate(syncNotifierProvider);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Taarifa zimesasishwa!'),
                          ),
                        );
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Imeshindwa kusasisha: $e')),
                        );
                      } finally {
                        if (mounted) setState(() => _isSyncing = false);
                      }
                    },
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _logout,
              tooltip: 'Toka',
            ),
          ],
        ),
        drawer: Drawer(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF2E7D32), Color(0xFF43A047)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.white24,
                        child: Icon(
                          Icons.agriculture,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Shamba Zangu',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Chagua shamba la kufuatilia',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),

                // Profile Menu Item
                ListTile(
                  leading: Icon(
                    Icons.account_circle,
                    color: Colors.green.shade700,
                  ),
                  title: const Text('Wasifu'),
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey,
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProfileScreen()),
                    );
                  },
                ),
                const Divider(),

                Expanded(
                  child: farmsAsync.when(
                    data: (farms) {
                      if (farms.isEmpty) {
                        return const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.agriculture_outlined,
                                size: 70,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'Hakuna shamba bado',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: farms.length,
                        itemBuilder: (ctx, index) {
                          final farm = farms[index];
                          final isSelected = selectedFarmId == farm.id;

                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.green.withOpacity(0.12)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.green
                                    : Colors.grey.shade200,
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              leading: CircleAvatar(
                                backgroundColor: isSelected
                                    ? Colors.green
                                    : Colors.grey.shade200,
                                child: Icon(
                                  Icons.agriculture,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.grey.shade700,
                                ),
                              ),
                              title: Text(
                                farm.cropType.toUpperCase(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text('Eneo: ${farm.areaHectares} ha'),
                              ),
                              trailing: isSelected
                                  ? const Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                    )
                                  : const Icon(
                                      Icons.arrow_forward_ios,
                                      size: 16,
                                      color: Colors.grey,
                                    ),
                              onTap: () {
                                ref
                                    .read(selectedFarmIdProvider.notifier)
                                    .setSelectedFarmId(farm.id);

                                ref.invalidate(selectedFarmProvider);
                                ref.invalidate(weatherDataProvider);
                                ref.invalidate(marketPricesProvider);

                                Navigator.pop(context);
                              },
                            ),
                          );
                        },
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (err, _) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('Error: $err'),
                      ),
                    ),
                  ),
                ),

                // Inside the Column, after Expanded and before the existing Padding
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ListTile(
                    leading: Icon(Icons.settings, color: Colors.green.shade700),
                    title: const Text('Dhibiti Shamba'),
                    trailing: const Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Colors.grey,
                    ),
                    onTap: () {
                      Navigator.pop(context); // close drawer
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ManageFarmsScreen(),
                        ),
                      );
                    },
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text(
                        'Ongeza Shamba Mpya',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      onPressed: () {
                        Navigator.pop(context);

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AddFarmScreen(),
                          ),
                        ).then((_) {
                          ref.invalidate(farmListProvider);
                          ref.invalidate(farmListNotifierProvider);
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        body: _screens[selectedIndex],
        floatingActionButton: (selectedIndex == 4 || selectedIndex == 3)
            ? null // No FAB on camera or advice screens
            : FloatingActionButton.extended(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (ctx) => const AddFarmScreen()),
                  ).then((_) {
                    ref.invalidate(farmListProvider);
                    ref.invalidate(selectedFarmProvider);
                    ref.invalidate(weatherDataProvider);
                  });
                },
                icon: const Icon(Icons.add),
                label: const Text('Shamba'),
                backgroundColor: Colors.green,
              ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: selectedIndex,
          onTap: (index) {
            ref.read(bottomNavIndexProvider.notifier).state = index;
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: const Color(0xFFF1F8E9),
          selectedItemColor: const Color(0xFF2E7D32),
          unselectedItemColor: Colors.grey,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Nyumbani'),
            BottomNavigationBarItem(
              icon: Icon(Icons.cloud_queue),
              label: 'Hewa',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.store), label: 'Masoko'),
            BottomNavigationBarItem(
              icon: Icon(Icons.lightbulb),
              label: 'Ushauri',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.camera_alt),
              label: 'Wadudu',
            ),
          ],
        ),
      ),
    );
  }
}
