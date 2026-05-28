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
  bool _showOfflineBanner = true;
  bool _lastOfflineStatus = false;

  @override
  Widget build(BuildContext context) {
    final connectivityState = ref.watch(connectivityProvider);

    return connectivityState.when(
      data: (result) {
        final isOffline = result == ConnectivityResult.none;

        // When transitioning from online to offline, show the banner again.
        if (isOffline != _lastOfflineStatus) {
          if (isOffline && mounted) {
            setState(() {
              _showOfflineBanner = true;
            });
          }
          _lastOfflineStatus = isOffline;
        }

        return Stack(
          children: [
            widget.child,
            if (isOffline && _showOfflineBanner)
              Positioned(
                top: 10,
                left: 10,
                child: SafeArea(
                  child: Material(
                    elevation: 2,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade800,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.wifi_off,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: () {
                              setState(() {
                                _showOfflineBanner = false;
                              });
                            },
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
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
}