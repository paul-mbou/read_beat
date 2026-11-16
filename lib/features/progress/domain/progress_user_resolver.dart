import 'package:read_beat/core/errors/result.dart';
import 'package:read_beat/features/auth/domain/repositories/auth_repository.dart';
import 'package:read_beat/features/progress/domain/progress_user_ids.dart';

/// Resolves which userId owns local progress writes (auth id or guest).
final class ProgressUserResolver {
  ProgressUserResolver(this._auth);

  final AuthRepository _auth;

  Future<String> currentUserId() async {
    final current = await _auth.currentUser();
    if (current is Failure<AuthUser?>) return ProgressUserIds.local;
    return current.valueOrNull?.id ?? ProgressUserIds.local;
  }
}
