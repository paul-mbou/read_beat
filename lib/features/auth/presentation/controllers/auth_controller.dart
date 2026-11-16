import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:read_beat/app/di.dart';
import 'package:read_beat/core/errors/result.dart';
import 'package:read_beat/features/auth/domain/models/social_auth_provider.dart';
import 'package:read_beat/features/auth/domain/repositories/auth_repository.dart';

/// Live session stream from [AuthRepository].
final authSessionProvider = StreamProvider<AuthUser?>((ref) {
  return ref.watch(authRepositoryProvider).watchSession();
});

/// Convenience: current user when session is ready.
final currentAuthUserProvider = Provider<AuthUser?>((ref) {
  return ref.watch(authSessionProvider).asData?.value;
});

/// Imperative auth actions for screens.
final authControllerProvider = Provider<AuthController>((ref) {
  return AuthController(ref.watch(authRepositoryProvider));
});

final class AuthController {
  AuthController(this._repository);

  final AuthRepository _repository;

  Future<Result<AuthUser>> signInWithProvider(SocialAuthProvider provider) {
    return _repository.signInWithProvider(provider);
  }

  Future<Result<void>> signOut() => _repository.signOut();

  Future<Result<void>> deleteAccount() => _repository.deleteAccount();
}
