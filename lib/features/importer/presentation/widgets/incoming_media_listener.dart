import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:read_beat/core/extensions/extensions.dart';
import 'package:read_beat/features/importer/domain/media_import_service.dart';
import 'package:read_beat/features/importer/presentation/controllers/import_controller.dart';

/// Listens for files opened/shared into ReadBeat and auto-imports them.
class IncomingMediaListener extends ConsumerStatefulWidget {
  const IncomingMediaListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<IncomingMediaListener> createState() =>
      _IncomingMediaListenerState();
}

class _IncomingMediaListenerState extends ConsumerState<IncomingMediaListener> {
  static const _iosOpenChannel = MethodChannel('read_beat/open_files');

  StreamSubscription<List<SharedMediaFile>>? _sub;
  var _handling = false;
  final _recentPaths = <String>{};

  static final _allowed = {
    for (final e in MediaImportService.allowedExtensions) e.toLowerCase(),
  };

  @override
  void initState() {
    super.initState();
    _sub = ReceiveSharingIntent.instance.getMediaStream().listen(
      _onSharedMedia,
      onError: (Object err) {
        debugPrint('Incoming media stream error: $err');
      },
    );
    // Cold start: share/open while app was closed (Android + iOS share).
    unawaited(
      ReceiveSharingIntent.instance.getInitialMedia().then(_onSharedMedia),
    );
    // iOS “Open in ReadBeat” document handoff.
    _iosOpenChannel.setMethodCallHandler(_onIosOpenMethod);
    unawaited(_loadInitialIosOpens());
  }

  Future<void> _loadInitialIosOpens() async {
    try {
      final raw = await _iosOpenChannel.invokeMethod<List<dynamic>>('getInitial');
      if (raw == null || raw.isEmpty) return;
      await _importSources(_sourcesFromMaps(raw));
    } on MissingPluginException {
      // Android / desktop — channel not registered.
    } catch (e) {
      debugPrint('iOS initial open files failed: $e');
    }
  }

  Future<dynamic> _onIosOpenMethod(MethodCall call) async {
    if (call.method != 'onFiles') return;
    final args = call.arguments;
    if (args is! List) return;
    await _importSources(_sourcesFromMaps(args));
  }

  List<({String path, String name})> _sourcesFromMaps(List<dynamic> raw) {
    final sources = <({String path, String name})>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final path = item['path']?.toString() ?? '';
      if (path.isEmpty) continue;
      final name = item['name']?.toString().isNotEmpty == true
          ? item['name'].toString()
          : p.basename(path);
      final ext = p.extension(path).toLowerCase().replaceFirst('.', '');
      if (!_allowed.contains(ext)) continue;
      sources.add((path: path, name: name));
    }
    return sources;
  }

  Future<void> _onSharedMedia(List<SharedMediaFile> files) async {
    if (!mounted || files.isEmpty) return;

    final sources = <({String path, String name})>[];
    for (final file in files) {
      if (file.type == SharedMediaType.text || file.type == SharedMediaType.url) {
        continue;
      }
      final path = file.path;
      if (path.isEmpty) continue;
      final ext = p.extension(path).toLowerCase().replaceFirst('.', '');
      if (!_allowed.contains(ext)) continue;
      sources.add((path: path, name: p.basename(path)));
    }

    if (sources.isEmpty) {
      await ReceiveSharingIntent.instance.reset();
      return;
    }

    await _importSources(sources);
    await ReceiveSharingIntent.instance.reset();
  }

  Future<void> _importSources(List<({String path, String name})> sources) async {
    if (!mounted || sources.isEmpty || _handling) return;

    final unique = sources.where((s) => !_recentPaths.contains(s.path)).toList();
    if (unique.isEmpty) return;
    for (final s in unique) {
      _recentPaths.add(s.path);
    }

    _handling = true;
    try {
      final result = await ref
          .read(importStatusProvider.notifier)
          .importExternalFiles(unique);
      if (!mounted) return;
      result.fold(
        onSuccess: (items) {
          if (items.isEmpty) {
            context.showSnackBar(
              'No compatible files to import (EPUB, PDF, MP3, M4A)',
            );
            return;
          }
          HapticFeedback.lightImpact();
          context.showSnackBar(
            items.length == 1
                ? 'Imported “${items.first.title}”'
                : 'Imported ${items.length} files',
          );
        },
        onFailure: (e) => context.showSnackBar(e.message, isError: true),
      );
    } finally {
      _handling = false;
      Future<void>.delayed(const Duration(seconds: 5), () {
        for (final s in unique) {
          _recentPaths.remove(s.path);
        }
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _iosOpenChannel.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
