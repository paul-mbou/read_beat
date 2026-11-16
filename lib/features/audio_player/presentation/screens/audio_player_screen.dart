import 'package:flutter/material.dart';
import 'package:flutter_gutter/flutter_gutter.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:read_beat/app/icons.dart';
import 'package:read_beat/core/extensions/extensions.dart';
import 'package:read_beat/features/library/presentation/providers/desk_home_providers.dart';
import 'package:read_beat/features/library/presentation/widgets/desk_home_widgets.dart';

class AudioPlayerScreen extends ConsumerWidget {
  const AudioPlayerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(audioPlayerServiceProvider);
    final item = service.currentItem;

    if (item == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Nothing playing')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Now playing')),
      body: SafeArea(
        child: Padding(
          padding: context.pagePaddingComfortable,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CoverThumb(
                item: item.toShelfItem(),
                width: double.infinity,
                height: 220,
              ),
              const GutterLarge(),
              Text(item.title, style: context.textTheme.displayMedium),
              if (item.author != null) ...[
                const GutterTiny(),
                Text(item.author!, style: context.textTheme.bodyLarge),
              ],
              const GutterLarge(),
              StreamBuilder<Duration>(
                stream: service.positionStream,
                builder: (context, snap) {
                  final pos = snap.data ?? Duration.zero;
                  return StreamBuilder<Duration?>(
                    stream: service.durationStream,
                    builder: (context, durSnap) {
                      final dur = durSnap.data ?? Duration.zero;
                      final maxMs = dur.inMilliseconds <= 0
                          ? 1.0
                          : dur.inMilliseconds.toDouble();
                      final value = pos.inMilliseconds.toDouble().clamp(
                        0.0,
                        maxMs,
                      );
                      return Column(
                        children: [
                          Slider(
                            value: value,
                            max: maxMs,
                            onChanged: (v) =>
                                service.seek(Duration(milliseconds: v.round())),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _fmt(pos),
                                style: context.textTheme.bodySmall,
                              ),
                              Text(
                                _fmt(dur),
                                style: context.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
              if (service.nextInQueue != null) ...[
                const GutterSmall(),
                Text(
                  'Up next · ${service.nextInQueue!.title}',
                  style: context.textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const Gutter(),
              StreamBuilder<PlayerState>(
                stream: service.playerStateStream,
                builder: (context, snap) {
                  final playing = snap.data?.playing ?? false;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        iconSize: 36,
                        onPressed: () => service.seek(
                          service.player.position - const Duration(seconds: 15),
                        ),
                        icon: const AppIcon(AppIcons.replay, size: 28),
                      ),
                      const Gutter(),
                      IconButton.filled(
                        iconSize: 42,
                        onPressed: () async {
                          if (playing) {
                            await service.pause();
                          } else {
                            await service.resume();
                          }
                        },
                        icon: AppIcon(
                          playing ? AppIcons.pause : AppIcons.play,
                          active: true,
                          size: 32,
                        ),
                      ),
                      const Gutter(),
                      IconButton(
                        iconSize: 36,
                        onPressed: () => service.seek(
                          service.player.position + const Duration(seconds: 30),
                        ),
                        icon: const AppIcon(AppIcons.forward, size: 28),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}
