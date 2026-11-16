import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:read_beat/app/di.dart';

final recapConsentProvider = NotifierProvider<RecapConsentController, bool>(
  RecapConsentController.new,
);

final class RecapConsentController extends Notifier<bool> {
  @override
  bool build() {
    Future<void>.microtask(_hydrate);
    return false;
  }

  Future<void> _hydrate() async {
    final granted = await ref.read(recapServiceProvider).isConsentGranted;
    if (!ref.mounted) return;
    state = granted;
  }

  Future<void> setConsent(bool granted) async {
    state = granted;
    await ref.read(recapServiceProvider).setConsent(granted);
  }
}
