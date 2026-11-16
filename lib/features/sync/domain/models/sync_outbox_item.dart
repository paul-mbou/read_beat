import 'package:equatable/equatable.dart';

enum SyncEntityType { progress, mediaCatalog, favorite, playlist }

enum SyncOperationType { upsert, delete }

enum SyncOutboxStatus { pending, inFlight, failed, completed, deadLetter }

/// Local outbox entry for reliable background sync.
final class SyncOutboxItem extends Equatable {
  const SyncOutboxItem({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.payloadJson,
    required this.createdAt,
    required this.updatedAt,
    this.status = SyncOutboxStatus.pending,
    this.attempts = 0,
    this.lastError,
    this.idempotencyKey,
    this.nextAttemptAt,
  });

  final String id;
  final SyncEntityType entityType;
  final String entityId;
  final SyncOperationType operation;
  final String payloadJson;
  final SyncOutboxStatus status;
  final int attempts;
  final String? lastError;
  final String? idempotencyKey;
  final DateTime? nextAttemptAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  List<Object?> get props => [
    id,
    entityType,
    entityId,
    operation,
    payloadJson,
    status,
    attempts,
    lastError,
    idempotencyKey,
    nextAttemptAt,
    createdAt,
    updatedAt,
  ];
}
