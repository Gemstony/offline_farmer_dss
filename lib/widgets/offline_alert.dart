import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

final connectivityProvider = StreamProvider<ConnectivityResult>((ref) {
  return Connectivity().onConnectivityChanged.map((list) {
    if (list.isEmpty) return ConnectivityResult.none;
    return list.first;
  });
});

class OfflineAlert extends ConsumerStatefulWidget {
  final Widget child;
  const OfflineAlert({super.key, required this.child});

  @override
  ConsumerState<OfflineAlert> createState() => _OfflineAlertState();
}

class _OfflineAlertState extends ConsumerState<OfflineAlert> {
  DateTime? _lastSyncTime;

  @override
  void initState() {
    super.initState();
    _loadLastSyncTime();
  }

  Future<void> _loadLastSyncTime() async {
    // You can store last sync time in shared_preferences or a Hive box.
    // For now, we'll read from a simple value; implement your own persistence.
    // Example using Hive (you need to add a box for settings):
    // final settingsBox = Hive.box('settings');
    // setState(() { _lastSyncTime = settingsBox.get('lastSyncTime'); });
  }

  Future<void> _retryConnection() async {
    // 1. Get the current status from the plugin
    final connectivityResult = await Connectivity().checkConnectivity();

    // 2. Check if that status matches the 'none' enum value
    final isOffline = connectivityResult == ConnectivityResult.none;
    if (isOffline) {
      // Attempt a sync (optional)
      // ref.read(syncNotifierProvider).syncAll();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mtandao umepatikana! Jaribu kusasisha tena.'),
        ),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bado hakuna mtandao. Tafadhali washa data au Wi-Fi.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final connectivityState = ref.watch(connectivityProvider);

    return connectivityState.when(
      data: (result) {
        final isOffline = result == ConnectivityResult.none;
        return Stack(
          children: [
            widget.child,
            if (isOffline)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Material(
                    elevation: 4,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.orange.shade700,
                            Colors.orange.shade900,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.wifi_off,
                            color: Colors.white,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Huna mtandao',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Unatazama taarifa zilizohifadhiwa ndani. Taarifa mpya zitasasishwa mtandao ukishapatikana.',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                                if (_lastSyncTime != null)
                                  Text(
                                    'Mwisho kusasishwa: ${_formatDate(_lastSyncTime!)}',
                                    style: TextStyle(
                                      color: Colors.white60,
                                      fontSize: 11,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _retryConnection,
                            icon: const Icon(
                              Icons.refresh,
                              color: Colors.white,
                              size: 18,
                            ),
                            label: const Text(
                              'Jaribu Tena',
                              style: TextStyle(color: Colors.white),
                            ),
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.white24,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
      loading: () => widget.child,
      error: (_, __) => widget.child,
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
