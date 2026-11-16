import 'package:equatable/equatable.dart';

/// Local + remote favorite flag for a work (tombstone when [isFavorite] is false).
final class FavoriteRecord extends Equatable {
  const FavoriteRecord({
    required this.id,
    required this.userId,
    required this.workId,
    required this.isFavorite,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String workId;
  final bool isFavorite;
  final DateTime updatedAt;

  FavoriteRecord copyWith({
    String? userId,
    bool? isFavorite,
    DateTime? updatedAt,
  }) {
    return FavoriteRecord(
      id: id,
      userId: userId ?? this.userId,
      workId: workId,
      isFavorite: isFavorite ?? this.isFavorite,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'workId': workId,
    'isFavorite': isFavorite,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  factory FavoriteRecord.fromJson(Map<String, dynamic> json) {
    return FavoriteRecord(
      id: json['id'] as String,
      userId: json['userId'] as String,
      workId: json['workId'] as String,
      isFavorite: _asBool(json['isFavorite'], fallback: true),
      updatedAt: DateTime.parse(json['updatedAt'] as String).toUtc(),
    );
  }

  static bool _asBool(Object? value, {required bool fallback}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final v = value.toLowerCase();
      if (v == '1' || v == 'true') return true;
      if (v == '0' || v == 'false') return false;
    }
    return fallback;
  }

  @override
  List<Object?> get props => [id, userId, workId, isFavorite, updatedAt];
}
