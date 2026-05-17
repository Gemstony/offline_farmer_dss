import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

final connectivityProvider = StreamProvider<ConnectivityResult>((ref) {
  return Connectivity().onConnectivityChanged.map((list) {
    if (list.isEmpty) return ConnectivityResult.none;
    return list.first;
  });
});

class OfflineAlert extends ConsumerWidget {
  final Widget child;
  const OfflineAlert({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivity = ref.watch(connectivityProvider);
    return connectivity.when(
      data: (result) {
        if (result == ConnectivityResult.none) {
          return Column(
            children: [
              Container(
                color: Colors.orange,
                padding: EdgeInsets.all(8),
                child: Row(
                  children: [
                    Icon(Icons.wifi_off, color: Colors.white),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Huna mtandao. Taarifa zilizohifadhiwa ndani ndizo zinazoonekana.',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: child),
            ],
          );
        }
        return child;
      },
      loading: () => child,
      error: (_, _) => child,
    );
  }
}
