import 'package:equatable/equatable.dart';
import 'package:read_beat/core/errors/result.dart';
import 'package:read_beat/features/auth/domain/models/social_auth_provider.dart';

final class AuthUser extends Equatable {
  const AuthUser({
    required this.id,
    required this.email,
    this.name,
    this.emailVerified = false,
  });

  final String id;
  final String email;
  final String? name;
  final bool emailVerified;

  @override
  List<Object?> get props => [id, email, name, emailVerified];
}

abstract interface class AuthRepository {
  /// Emits the current session user (or null) and subsequent auth changes.
  Stream<AuthUser?> watchSession();

  Future<Result<AuthUser?>> currentUser();

  /// Opens the provider OAuth flow (Google / Apple / Facebook).
  Future<Result<AuthUser>> signInWithProvider(SocialAuthProvider provider);

  Future<Result<void>> signOut();

  /// Blocks the Appwrite account and clears the local session.
  Future<Result<void>> deleteAccount();
}
