import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:read_beat/app/app.dart';
import 'package:read_beat/app/di.dart';
import 'package:read_beat/core/constants/app_constants.dart';
import 'package:read_beat/core/database/app_database.dart';
import 'package:read_beat/core/errors/app_exception.dart';
import 'package:read_beat/core/errors/result.dart';
import 'package:read_beat/features/auth/domain/models/social_auth_provider.dart';
import 'package:read_beat/features/auth/domain/repositories/auth_repository.dart';

void main() {
  testWidgets('ReadBeat boots to splash', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          authRepositoryProvider.overrideWithValue(const _FakeAuth()),
        ],
        child: const ReadBeatApp(),
      ),
    );
    await tester.pump();
    expect(find.text(AppConstants.appName), findsWidgets);
  });
}

final class _FakeAuth implements AuthRepository {
  const _FakeAuth();

  @override
  Future<Result<AuthUser?>> currentUser() async => const Success(null);

  @override
  Stream<AuthUser?> watchSession() => Stream.value(null);

  @override
  Future<Result<AuthUser>> signInWithProvider(
    SocialAuthProvider provider,
  ) async => const Failure(AuthException('n/a'));

  @override
  Future<Result<void>> signOut() async => const Success(null);

  @override
  Future<Result<void>> deleteAccount() async => const Success(null);
}
