import 'dart:async';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/enums.dart' as enums;
import 'package:appwrite/models.dart' as models;
import 'package:read_beat/core/errors/app_exception.dart';
import 'package:read_beat/core/errors/result.dart';
import 'package:read_beat/core/logger/app_logger.dart';
import 'package:read_beat/features/auth/domain/models/social_auth_provider.dart';
import 'package:read_beat/features/auth/domain/repositories/auth_repository.dart';

/// Appwrite auth via Google / Apple / Facebook OAuth only.
final class AppwriteAuthRepository implements AuthRepository {
  AppwriteAuthRepository(this._account, {AppLogger? logger})
    : _logger = logger ?? AppLogger();

  final Account _account;
  final AppLogger _logger;

  final _sessionController = StreamController<AuthUser?>.broadcast();
  bool _started = false;
  AuthUser? _latest;

  @override
  Stream<AuthUser?> watchSession() async* {
    if (!_started) {
      _started = true;
      final initial = await currentUser();
      _latest = initial.valueOrNull;
    }
    yield _latest;
    yield* _sessionController.stream;
  }

  Future<void> _emit(AuthUser? user) async {
    _latest = user;
    if (!_sessionController.isClosed) {
      _sessionController.add(user);
    }
  }

  @override
  Future<Result<AuthUser?>> currentUser() async {
    try {
      final user = await _account.get();
      return Success(_map(user));
    } on AppwriteException catch (e) {
      if (e.code == 401) return const Success(null);
      _logger.warning('currentUser failed', e);
      return Failure(
        AuthException(e.message ?? 'Auth error', cause: e, code: '${e.code}'),
      );
    } catch (e, st) {
      _logger.error('currentUser unexpected', e, st);
      return Failure(AuthException('Unable to load session', cause: e));
    }
  }

  @override
  Future<Result<AuthUser>> signInWithProvider(
    SocialAuthProvider provider,
  ) async {
    try {
      await _account.createOAuth2Session(provider: _mapProvider(provider));
      final user = await _account.get();
      final mapped = _map(user);
      await _emit(mapped);
      return Success(mapped);
    } on AppwriteException catch (e) {
      return Failure(
        AuthException(
          e.message ?? 'Social sign-in failed',
          cause: e,
          code: '${e.code}',
        ),
      );
    } catch (e) {
      final message = e.toString().toLowerCase();
      if (message.contains('cancel') || message.contains('cancell')) {
        return const Failure(AuthException('Sign-in cancelled'));
      }
      return Failure(AuthException('Social sign-in failed', cause: e));
    }
  }

  @override
  Future<Result<void>> signOut() async {
    try {
      await _account.deleteSession(sessionId: 'current');
      await _emit(null);
      return const Success(null);
    } on AppwriteException catch (e) {
      if (e.code == 401) {
        await _emit(null);
        return const Success(null);
      }
      return Failure(
        AuthException(
          e.message ?? 'Sign out failed',
          cause: e,
          code: '${e.code}',
        ),
      );
    } catch (e) {
      return Failure(AuthException('Sign out failed', cause: e));
    }
  }

  @override
  Future<Result<void>> deleteAccount() async {
    try {
      await _account.updateStatus();
      try {
        await _account.deleteSessions();
      } catch (_) {
        await _account.deleteSession(sessionId: 'current');
      }
      await _emit(null);
      return const Success(null);
    } on AppwriteException catch (e) {
      return Failure(
        AuthException(
          e.message ?? 'Delete account failed',
          cause: e,
          code: '${e.code}',
        ),
      );
    } catch (e) {
      return Failure(AuthException('Delete account failed', cause: e));
    }
  }

  enums.OAuthProvider _mapProvider(SocialAuthProvider provider) {
    return switch (provider) {
      SocialAuthProvider.google => enums.OAuthProvider.google,
      SocialAuthProvider.apple => enums.OAuthProvider.apple,
      SocialAuthProvider.facebook => enums.OAuthProvider.facebook,
    };
  }

  AuthUser _map(models.User user) => AuthUser(
    id: user.$id,
    email: user.email,
    name: user.name.isEmpty ? null : user.name,
    emailVerified: user.emailVerification,
  );

  void dispose() {
    _sessionController.close();
  }
}
