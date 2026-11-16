/// Typed application failures used across features.
sealed class AppException implements Exception {
  const AppException(this.message, {this.cause, this.code});

  final String message;
  final Object? cause;
  final String? code;

  @override
  String toString() => 'AppException($code): $message';
}

final class NetworkException extends AppException {
  const NetworkException(super.message, {super.cause, super.code});
}

final class AuthException extends AppException {
  const AuthException(super.message, {super.cause, super.code});
}

final class StorageException extends AppException {
  const StorageException(super.message, {super.cause, super.code});
}

final class SyncException extends AppException {
  const SyncException(super.message, {super.cause, super.code});
}

final class ValidationException extends AppException {
  const ValidationException(super.message, {super.cause, super.code});
}

final class UnexpectedException extends AppException {
  const UnexpectedException(super.message, {super.cause, super.code});
}
