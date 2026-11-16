import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Releases the splash route once the entrance composition has finished.
final splashGateProvider =
    NotifierProvider<SplashGate, bool>(SplashGate.new);

class SplashGate extends Notifier<bool> {
  @override
  bool build() => false;

  void markReady() => state = true;
}
