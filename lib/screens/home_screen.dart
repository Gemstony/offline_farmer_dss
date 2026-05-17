import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'weather_screen.dart';
import 'market_screen.dart';
import 'advice_screen.dart';
import 'camera_screen.dart';
import 'add_farm_screen.dart';
import '../widgets/offline_alert.dart';
import '../widgets/language_switcher.dart';
import '../providers/farm_provider.dart';
import '../providers/weather_provider.dart';
import '../providers/sync_provider.dart';
import '../providers/market_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;

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

  @override
  Widget build(BuildContext context) {
    return OfflineAlert(
      child: Scaffold(
        appBar: AppBar(
          title: Text(_titles[_selectedIndex]),
          actions: [
            IconButton(
              icon: const Icon(Icons.sync),
              onPressed: () async {
                await ref.read(syncNotifierProvider.future);

                ref.invalidate(weatherDataProvider);
                ref.invalidate(marketPricesProvider);
                ref.invalidate(syncNotifierProvider);

                if (!context.mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Market prices and weather updated!')),
                );
              },
            ),
            LanguageSwitcher(), // we'll implement later
          ],
        ),
        body: _screens[_selectedIndex],
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (ctx) => const AddFarmScreen()),
            ).then((_) {
              // Refresh farms after returning
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
