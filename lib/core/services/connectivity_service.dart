import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Network availability for SyncEngine gating.
abstract interface class ConnectivityGateway {
  Future<bool> get isOnline;
  Stream<bool> get onConnectivityChanged;
}

/// Default [ConnectivityGateway] backed by connectivity_plus.
final class ConnectivityService implements ConnectivityGateway {
  ConnectivityService({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Stream<bool> get onConnectivityChanged =>
      _connectivity.onConnectivityChanged.map(_hasConnection);

  @override
  Future<bool> get isOnline async {
    final results = await _connectivity.checkConnectivity();
    return _hasConnection(results);
  }

  bool _hasConnection(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    return results.any((r) => r != ConnectivityResult.none);
  }
}
