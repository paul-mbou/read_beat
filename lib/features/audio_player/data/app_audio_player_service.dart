import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:read_beat/core/constants/app_constants.dart';
import 'package:read_beat/core/errors/app_exception.dart';
import 'package:read_beat/core/errors/result.dart';
import 'package:read_beat/core/logger/app_logger.dart';
import 'package:read_beat/core/services/device_id_service.dart';
import 'package:read_beat/features/library/domain/models/library_item.dart';
import 'package:read_beat/features/library/domain/repositories/library_repository.dart';
import 'package:read_beat/features/progress/domain/models/media_progress.dart';
import 'package:read_beat/features/progress/domain/progress_user_resolver.dart';
import 'package:read_beat/features/progress/domain/repositories/progress_repository.dart';
import 'package:uuid/uuid.dart';

/// Local-first audio player with periodic progress persistence.
final class AppAudioPlayerService {
  AppAudioPlayerService({
    required ProgressRepository progressRepository,
    required LibraryRepository libraryRepository,
    required DeviceIdService deviceIdService,
    required ProgressUserResolver progressUserResolver,
    AppLogger? logger,
    Uuid? uuid,
  }) : _progress = progressRepository,
       _library = libraryRepository,
       _deviceId = deviceIdService,
       _progressUser = progressUserResolver,
       _logger = logger ?? AppLogger(),
       _uuid = uuid ?? const Uuid(),
       _player = AudioPlayer();

  final ProgressRepository _progress;
  final LibraryRepository _library;
  final DeviceIdService _deviceId;
  final ProgressUserResolver _progressUser;
  final AppLogger _logger;
  final Uuid _uuid;
  final AudioPlayer _player;

  LibraryItem? _current;
  Timer? _persistTimer;
  bool _configured = false;
  List<LibraryItem> _queue = const [];
  int _queueIndex = 0;
  StreamSubscription<ProcessingState>? _completionSub;

  final _itemController = StreamController<LibraryItem?>.broadcast();

  Stream<LibraryItem?> get currentItemStream async* {
    yield _current;
    yield* _itemController.stream;
  }
  LibraryItem? get currentItem => _current;
  AudioPlayer get player => _player;
  List<LibraryItem> get queue => List.unmodifiable(_queue);
  int get queueIndex => _queueIndex;
  LibraryItem? get nextInQueue =>
      _queueIndex + 1 < _queue.length ? _queue[_queueIndex + 1] : null;

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<Duration> get positionStream => _player.positionStream;

  Future<void> _ensureSession() async {
    if (_configured) return;
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    _configured = true;
  }

  Future<Result<void>> playQueue(
    List<LibraryItem> items, {
    int startIndex = 0,
  }) async {
    final audio = items.where((e) => e.isAudio).toList();
    if (audio.isEmpty) {
      return const Failure(ValidationException('This queue has no audio yet'));
    }
    _queue = audio;
    _queueIndex = startIndex.clamp(0, audio.length - 1);
    return playItem(audio[_queueIndex], continueQueue: true);
  }

  Future<Result<void>> playItem(
    LibraryItem item, {
    bool continueQueue = false,
  }) async {
    try {
      await _ensureSession();
      _listenCompletion();
      if (!continueQueue) {
        _queue = [item];
        _queueIndex = 0;
      }
      if (!File(item.filePath).existsSync()) {
        return const Failure(StorageException('Audio file missing on disk'));
      }

      if (_current?.id != item.id) {
        await _persistProgress();
        await _player.setFilePath(item.filePath);
        _current = item;
        _itemController.add(item);
        await _library.touchOpened(item.id);

        final userId = await _progressUser.currentUserId();
        final existing = await _progress.getBestLocal(
          preferredUserId: userId,
          mediaId: item.id,
        );
        final pos = existing.valueOrNull?.position;
        if (pos != null && pos > 0) {
          await _player.seek(Duration(milliseconds: (pos * 1000).round()));
        }
      }

      await _player.play();
      _startPersistLoop();
      return const Success(null);
    } catch (e, st) {
      _logger.error('playItem failed', e, st);
      return Failure(UnexpectedException('Could not play audio', cause: e));
    }
  }

  Future<void> pause() async {
    await _player.pause();
    await _persistProgress();
    _persistTimer?.cancel();
  }

  Future<void> resume() async {
    await _player.play();
    _startPersistLoop();
  }

  Future<void> stop() async {
    await _persistProgress();
    _persistTimer?.cancel();
    await _player.stop();
    _current = null;
    _queue = const [];
    _queueIndex = 0;
    _itemController.add(null);
  }

  void _listenCompletion() {
    _completionSub ??= _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        unawaited(_advanceQueue());
      }
    });
  }

  Future<void> _advanceQueue() async {
    if (_queueIndex + 1 >= _queue.length) {
      await _persistProgress();
      return;
    }
    _queueIndex++;
    await playItem(_queue[_queueIndex], continueQueue: true);
  }

  Future<void> seek(Duration position) => _player.seek(position);

  void _startPersistLoop() {
    _persistTimer?.cancel();
    _persistTimer = Timer.periodic(
      AppConstants.audioProgressInterval,
      (_) => _persistProgress(),
    );
  }

  Future<void> _persistProgress() async {
    final item = _current;
    if (item == null) return;
    try {
      final deviceId = await _deviceId.getDeviceId();
      final position = _player.position.inMilliseconds / 1000.0;
      final duration = _player.duration?.inMilliseconds.toDouble();
      final durationSec = duration == null ? null : duration / 1000.0;
      final percent = durationSec == null || durationSec <= 0
          ? null
          : (position / durationSec).clamp(0.0, 1.0);

      final label = durationSec == null
          ? null
          : '${_fmt(Duration(milliseconds: (position * 1000).round()))} / '
              '${_fmt(Duration(milliseconds: (durationSec * 1000).round()))}';

      final userId = await _progressUser.currentUserId();
      final existing = await _progress.getBestLocal(
        preferredUserId: userId,
        mediaId: item.id,
      );
      final id = existing.valueOrNull?.id ?? _uuid.v4();

      await _progress.saveLocal(
        MediaProgress(
          id: id,
          userId: userId,
          mediaId: item.id,
          workId: item.workId,
          mediaType: MediaType.audio,
          position: position,
          duration: durationSec,
          percent: percent,
          chapterOrPage: label,
          title: item.title,
          deviceId: deviceId,
          updatedAt: DateTime.now().toUtc(),
        ),
      );
    } catch (e, st) {
      _logger.warning('audio progress persist failed', e);
      _logger.error('stack', e, st);
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  Future<void> dispose() async {
    await _persistProgress();
    _persistTimer?.cancel();
    await _completionSub?.cancel();
    await _player.dispose();
    await _itemController.close();
  }
}
