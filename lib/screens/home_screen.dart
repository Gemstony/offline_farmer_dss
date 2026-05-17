import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'weather_screen.dart';
import 'market_screen.dart';
import 'advice_screen.dart';
import 'camera_screen.dart';
import 'add_farm_screen.dart';
import 'login_screen.dart'; // added
import '../widgets/offline_alert.dart';
import '../widgets/language_switcher.dart';
import '../providers/farm_provider.dart';
import '../providers/weather_provider.dart';
import '../providers/sync_provider.dart';
import '../providers/market_provider.dart';
import '../services/auth_service.dart'; // added

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;
  bool _isSyncing = false;

  final List<Widget> _screens = [
    WeatherScreen(),
    MarketScreen(),
    AdviceScreen(),
    CameraScreen(),
  ];

  final List<String> _titles = [
    'Hali ya Hewa',
    'Bei za Masoko',
    'Ushauri wa Kilimo',
    'Kitambulisho cha Wadudu',
  ];

  Future<void> _logout() async {
    final auth = AuthService();
    await auth.logout();
    if (mounted) {
      // Navigate to login screen and clear all previous routes
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return OfflineAlert(
      child: Scaffold(
        appBar: AppBar(
          title: Text(_titles[_selectedIndex]),
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
                        ref.invalidate(syncNotifierProvider);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Market prices and weather updated!'),
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
            const LanguageSwitcher(),
          ],
        ),
        body: _screens[_selectedIndex],
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (ctx) => const AddFarmScreen()),
            ).then((_) {
              ref.invalidate(farmListProvider);
              ref.invalidate(weatherDataProvider);
            });
          },
          icon: const Icon(Icons.add),
          label: const Text('Shamba'),
          backgroundColor: Colors.green,
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: const Color(0xFFF1F8E9),
          selectedItemColor: const Color(0xFF2E7D32),
          unselectedItemColor: Colors.grey,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.cloud), label: 'Hewa'),
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
