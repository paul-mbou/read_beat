import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:read_beat/features/ebook_reader/domain/ebook_reader_service.dart';
import 'package:read_beat/features/library/domain/models/library_item.dart';
import 'package:read_beat/features/library/presentation/providers/desk_home_providers.dart';
import 'package:webview_flutter/webview_flutter.dart';

class EbookReaderScreen extends HookConsumerWidget {
  const EbookReaderScreen({super.key, required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = useState<AsyncValue<EbookOpenResult>>(const AsyncLoading());
    final leaving = useState(false);
    final epubScrollReader = useRef<Future<double?> Function()?>(null);
    // Capture before dispose — ref.read is unsafe in useEffect cleanup.
    final reader = ref.read(ebookReaderServiceProvider);

    useEffect(() {
      var cancelled = false;
      Future<void>(() async {
        final cached =
            ref.read(libraryItemsProvider).asData?.value ??
            const <LibraryItem>[];
        var item = cached.where((e) => e.id == itemId).firstOrNull;
        if (item == null) {
          final fetched = await ref
              .read(libraryRepositoryProvider)
              .getById(itemId);
          item = fetched.valueOrNull;
        }
        if (cancelled) return;
        if (item == null) {
          open.value = AsyncError('Item not found', StackTrace.current);
          return;
        }
        final opened = await reader.open(item);
        if (cancelled) return;
        opened.fold(
          onSuccess: (value) => open.value = AsyncData(value),
          onFailure: (e) =>
              open.value = AsyncError(e.message, StackTrace.current),
        );
      });
      return () {
        cancelled = true;
        unawaited(reader.flushProgress());
      };
    }, [itemId]);

    useOnAppLifecycleStateChange((_, state) {
      if (state == AppLifecycleState.inactive ||
          state == AppLifecycleState.paused ||
          state == AppLifecycleState.detached) {
        unawaited(() async {
          final opened = open.value.asData?.value;
          final readScroll = epubScrollReader.value;
          if (opened != null &&
              opened.kind == MediaFormat.epub &&
              readScroll != null) {
            final percent = await readScroll();
            if (percent != null) {
              await reader.saveProgress(
                item: opened.item,
                position: percent,
                percent: percent,
                chapterOrPage: '${(percent * 100).round()}%',
                immediate: true,
              );
              return;
            }
          }
          await reader.flushProgress();
        }());
      }
    });

    void persistPdf(EbookOpenResult opened, int pageIndex, int? total) {
      final percent = total == null || total <= 0
          ? null
          : ((pageIndex + 1) / total).clamp(0.0, 1.0);
      reader.saveProgress(
        item: opened.item,
        position: pageIndex.toDouble(),
        percent: percent,
        chapterOrPage: total == null
            ? 'Page ${pageIndex + 1}'
            : 'Page ${pageIndex + 1} of $total',
      );
    }

    void persistEpub(EbookOpenResult opened, double scrollPercent) {
      final clamped = scrollPercent.clamp(0.0, 1.0);
      reader.saveProgress(
        item: opened.item,
        position: clamped,
        percent: clamped,
        chapterOrPage: '${(clamped * 100).round()}%',
      );
    }

    Future<void> leaveToHome() async {
      if (leaving.value) return;
      leaving.value = true;
      try {
        final opened = open.value.asData?.value;
        final readScroll = epubScrollReader.value;
        if (opened != null &&
            opened.kind == MediaFormat.epub &&
            readScroll != null) {
          final percent = await readScroll();
          if (percent != null) {
            await reader.saveProgress(
              item: opened.item,
              position: percent,
              percent: percent,
              chapterOrPage: '${(percent * 100).round()}%',
              immediate: true,
            );
          } else {
            await reader.flushProgress();
          }
        } else {
          await reader.flushProgress();
        }
      } finally {
        if (context.mounted) context.pop();
      }
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        unawaited(leaveToHome());
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Back',
            icon: const BackButtonIcon(),
            onPressed: leaving.value ? null : leaveToHome,
          ),
          title: Text(open.value.asData?.value.item.title ?? 'Reader'),
        ),
        body: open.value.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (opened) {
            if (opened.kind == MediaFormat.pdf && opened.pdfPath != null) {
              return _PdfReaderBody(
                path: opened.pdfPath!,
                initialPage: opened.initialPage,
                onPageChanged: (index, total) =>
                    persistPdf(opened, index, total),
              );
            }

            final htmlPath = opened.epubHtmlPath;
            if (htmlPath == null) {
              return const Center(child: Text('EPUB render failed'));
            }

            return _EpubWebView(
              filePath: htmlPath,
              initialScrollPercent: opened.initialScrollPercent,
              onScrollProgress: (percent) => persistEpub(opened, percent),
              onProvideScrollReader: (readerFn) {
                epubScrollReader.value = readerFn;
              },
            );
          },
        ),
      ),
    );
  }
}

class _PdfReaderBody extends StatefulWidget {
  const _PdfReaderBody({
    required this.path,
    required this.initialPage,
    required this.onPageChanged,
  });

  final String path;
  final int initialPage;
  final void Function(int pageIndex, int? pageCount) onPageChanged;

  @override
  State<_PdfReaderBody> createState() => _PdfReaderBodyState();
}

class _PdfReaderBodyState extends State<_PdfReaderBody> {
  int? _pageCount;

  @override
  Widget build(BuildContext context) {
    return PdfViewer.file(
      widget.path,
      initialPageNumber: (widget.initialPage + 1).clamp(1, 99999),
      params: PdfViewerParams(
        onDocumentChanged: (doc) {
          setState(() => _pageCount = doc?.pages.length);
        },
        onPageChanged: (pageNumber) {
          final index = (pageNumber ?? 1) - 1;
          widget.onPageChanged(index, _pageCount);
        },
      ),
    );
  }
}

class _EpubWebView extends StatefulWidget {
  const _EpubWebView({
    required this.filePath,
    required this.initialScrollPercent,
    required this.onScrollProgress,
    required this.onProvideScrollReader,
  });

  final String filePath;
  final double initialScrollPercent;
  final ValueChanged<double> onScrollProgress;
  final void Function(Future<double?> Function() readScroll)
  onProvideScrollReader;

  @override
  State<_EpubWebView> createState() => _EpubWebViewState();
}

class _EpubWebViewState extends State<_EpubWebView> {
  late final WebViewController _controller;
  var _ignoreScrollReports = true;

  Future<double?> _readScrollPercent() async {
    try {
      final raw = await _controller.runJavaScriptReturningResult('''
        (function() {
          var h = document.documentElement.scrollHeight - window.innerHeight;
          return h <= 0 ? 0 : (window.scrollY / h);
        })();
      ''');
      if (raw is num) return raw.toDouble().clamp(0.0, 1.0);
      if (raw is String) return double.tryParse(raw)?.clamp(0.0, 1.0);
      return double.tryParse('$raw')?.clamp(0.0, 1.0);
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    final target = widget.initialScrollPercent.clamp(0.0, 1.0);
    widget.onProvideScrollReader(_readScrollPercent);
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) async {
            await _controller.runJavaScript('''
              (function() {
                var target = $target;
                var restored = false;
                function report() {
                  var h = document.documentElement.scrollHeight - window.innerHeight;
                  var p = h <= 0 ? 0 : (window.scrollY / h);
                  ProgressChannel.postMessage(String(p));
                }
                function restore() {
                  var h = document.documentElement.scrollHeight - window.innerHeight;
                  if (h <= 0) {
                    setTimeout(restore, 60);
                    return;
                  }
                  if (!restored && target > 0) {
                    window.scrollTo(0, target * h);
                  }
                  restored = true;
                  window.addEventListener('scroll', report, { passive: true });
                  ProgressChannel.postMessage('restored');
                }
                restore();
              })();
            ''');
          },
        ),
      )
      ..addJavaScriptChannel(
        'ProgressChannel',
        onMessageReceived: (msg) {
          if (msg.message == 'restored') {
            Future<void>.delayed(const Duration(milliseconds: 250), () {
              if (mounted) _ignoreScrollReports = false;
            });
            return;
          }
          if (_ignoreScrollReports) return;
          final p = double.tryParse(msg.message);
          if (p != null) widget.onScrollProgress(p.clamp(0.0, 1.0));
        },
      )
      ..loadFile(widget.filePath);
  }

  @override
  Widget build(BuildContext context) {
    if (!File(widget.filePath).existsSync()) {
      return const Center(child: Text('Missing EPUB preview'));
    }
    return WebViewWidget(controller: _controller);
  }
}
