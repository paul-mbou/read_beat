import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:read_beat/app/di.dart';
import 'package:read_beat/core/services/secure_storage_service.dart';

enum OnboardingPhase { unknown, needed, done }

final onboardingPhaseProvider =
    NotifierProvider<OnboardingController, OnboardingPhase>(
      OnboardingController.new,
    );

final class OnboardingController extends Notifier<OnboardingPhase> {
  @override
  OnboardingPhase build() {
    Future<void>.microtask(_hydrate);
    return OnboardingPhase.unknown;
  }

  Future<void> _hydrate() async {
    final raw = await ref
        .read(secureStorageProvider)
        .read(SecureStorageService.onboardingCompletedKey);
    if (!ref.mounted) return;
    state = raw == '1' ? OnboardingPhase.done : OnboardingPhase.needed;
  }

  Future<void> complete() async {
    state = OnboardingPhase.done;
    await ref
        .read(secureStorageProvider)
        .write(SecureStorageService.onboardingCompletedKey, '1');
  }
}
