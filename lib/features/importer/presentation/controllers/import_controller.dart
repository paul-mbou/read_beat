import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:read_beat/core/errors/result.dart';
import 'package:read_beat/features/library/domain/models/library_item.dart';
import 'package:read_beat/features/library/presentation/providers/desk_home_providers.dart';

enum ImportPhase { idle, picking, importing, completed, failed }

/// Live status for the in-app import status strip.
final class ImportStatus {
  const ImportStatus({
    this.phase = ImportPhase.idle,
    this.current = 0,
    this.total = 0,
    this.fileName,
    this.message,
    this.importedCount = 0,
  });

  final ImportPhase phase;
  final int current;
  final int total;
  final String? fileName;
  final String? message;
  final int importedCount;

  bool get isActive =>
      phase == ImportPhase.picking || phase == ImportPhase.importing;

  bool get showsBanner =>
      isActive || phase == ImportPhase.completed || phase == ImportPhase.failed;

  double get progress {
    if (total <= 0) return phase == ImportPhase.picking ? 0.05 : 0;
    return (current / total).clamp(0.0, 1.0);
  }

  String get statusLabel => switch (phase) {
    ImportPhase.picking => 'Opening files…',
    ImportPhase.importing when total > 0 =>
      'Importing $current of $total',
    ImportPhase.importing => 'Importing…',
    ImportPhase.completed => importedCount == 1
        ? 'Imported 1 file'
        : 'Imported $importedCount files',
    ImportPhase.failed => message ?? 'Import failed',
    ImportPhase.idle => '',
  };

  ImportStatus copyWith({
    ImportPhase? phase,
    int? current,
    int? total,
    String? fileName,
    String? message,
    int? importedCount,
    bool clearFileName = false,
    bool clearMessage = false,
  }) {
    return ImportStatus(
      phase: phase ?? this.phase,
      current: current ?? this.current,
      total: total ?? this.total,
      fileName: clearFileName ? null : (fileName ?? this.fileName),
      message: clearMessage ? null : (message ?? this.message),
      importedCount: importedCount ?? this.importedCount,
    );
  }
}

final importStatusProvider =
    NotifierProvider<ImportController, ImportStatus>(ImportController.new);

final class ImportController extends Notifier<ImportStatus> {
  @override
  ImportStatus build() => const ImportStatus();

  Future<Result<List<LibraryItem>>> startImport() async {
    if (state.isActive) {
      return const Success([]);
    }

    state = const ImportStatus(phase: ImportPhase.picking);
    final result = await ref
        .read(mediaImportServiceProvider)
        .importFromPicker(
          onProgress: (index, total, fileName) {
            state = ImportStatus(
              phase: ImportPhase.importing,
              current: index,
              total: total,
              fileName: fileName,
            );
          },
        );

    return _finish(result, cancelledIfEmptyWhilePicking: true);
  }

  /// Imports files opened or shared into ReadBeat from another app.
  Future<Result<List<LibraryItem>>> importExternalFiles(
    List<({String path, String name})> sources,
  ) async {
    if (sources.isEmpty) return const Success([]);
    if (state.isActive) return const Success([]);

    state = ImportStatus(
      phase: ImportPhase.importing,
      current: 0,
      total: sources.length,
      fileName: sources.first.name,
    );

    final result = await ref
        .read(mediaImportServiceProvider)
        .importPaths(
          sources,
          onProgress: (index, total, fileName) {
            state = ImportStatus(
              phase: ImportPhase.importing,
              current: index,
              total: total,
              fileName: fileName,
            );
          },
        );

    return _finish(result);
  }

  Result<List<LibraryItem>> _finish(
    Result<List<LibraryItem>> result, {
    bool cancelledIfEmptyWhilePicking = false,
  }) {
    return result.fold(
      onSuccess: (items) {
        if (items.isEmpty &&
            cancelledIfEmptyWhilePicking &&
            state.phase == ImportPhase.picking) {
          state = const ImportStatus();
          return Success(items);
        }
        state = ImportStatus(
          phase: ImportPhase.completed,
          current: items.length,
          total: items.length,
          importedCount: items.length,
          fileName: items.length == 1 ? items.first.title : null,
          message: items.length == 1
              ? 'Imported “${items.first.title}”'
              : 'Imported ${items.length} files',
        );
        _scheduleClear();
        return Success(items);
      },
      onFailure: (error) {
        state = ImportStatus(
          phase: ImportPhase.failed,
          message: error.message,
        );
        _scheduleClear();
        return Failure(error);
      },
    );
  }

  void dismiss() => state = const ImportStatus();

  void _scheduleClear() {
    Future<void>.delayed(const Duration(seconds: 3), () {
      if (!ref.mounted) return;
      final phase = state.phase;
      if (phase == ImportPhase.completed || phase == ImportPhase.failed) {
        state = const ImportStatus();
      }
    });
  }
}
