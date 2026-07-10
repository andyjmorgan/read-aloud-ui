import 'package:flutter/material.dart';

import '../../core/db/database.dart';
import '../../playback/playback_engine.dart';
import '../theme/donkeywork_theme.dart';

class PlayerBar extends StatelessWidget {
  const PlayerBar({super.key, required this.engine, required this.db});

  final PlaybackEngine engine;
  final AppDatabase db;

  @override
  Widget build(BuildContext context) {
    final dw = context.dw;
    return StreamBuilder<PlaybackState>(
      stream: engine.state,
      initialData: const PlaybackState(),
      builder: (context, snapshot) {
        final state = snapshot.data!;
        if (state.jobId == null) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: dw.bgElevated,
            border: Border(top: BorderSide(color: dw.border)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  if (state.live)
                    Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: dw.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text('LIVE',
                          style: TextStyle(
                              color: dw.accent, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                    ),
                  Expanded(
                    child: FutureBuilder<Job?>(
                      future: db.getJob(state.jobId!),
                      builder: (context, jobSnapshot) => Text(
                        jobSnapshot.data?.name ?? '…',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: dw.textPrimary, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: state.playing ? 'Pause' : 'Resume',
                    icon: Icon(state.playing ? Icons.pause_circle : Icons.play_circle, color: dw.accent, size: 34),
                    onPressed: () => state.playing ? engine.pause() : engine.resume(),
                  ),
                  IconButton(
                    tooltip: 'Stop',
                    icon: Icon(Icons.stop_circle_outlined, color: dw.textSecondary, size: 30),
                    onPressed: engine.stopPlayback,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (state.live) _StreamingMarquee(dw: dw) else _SeekBar(engine: engine),
            ],
          ),
        );
      },
    );
  }
}

/// Live mode: total length is unknown while chunks render — show an animated
/// marquee instead of a dishonest seek bar.
class _StreamingMarquee extends StatelessWidget {
  const _StreamingMarquee({required this.dw});

  final DwPalette dw;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: const LinearProgressIndicator(minHeight: 4),
          ),
        ),
        const SizedBox(width: 12),
        Text('Streaming…', style: TextStyle(color: dw.textTertiary, fontSize: 12)),
      ],
    );
  }
}

class _SeekBar extends StatelessWidget {
  const _SeekBar({required this.engine});

  static String _fmt(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  final PlaybackEngine engine;

  @override
  Widget build(BuildContext context) {
    final dw = context.dw;
    return StreamBuilder<Duration>(
      stream: engine.duration,
      initialData: Duration.zero,
      builder: (context, durationSnapshot) {
        final duration = durationSnapshot.data!;
        return StreamBuilder<Duration>(
          stream: engine.position,
          initialData: Duration.zero,
          builder: (context, positionSnapshot) {
            final position = positionSnapshot.data!;
            final max = duration.inMilliseconds.toDouble();
            final value = position.inMilliseconds.clamp(0, duration.inMilliseconds).toDouble();
            return Row(
              children: [
                Text(_fmt(position), style: TextStyle(color: dw.textTertiary, fontSize: 12)),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                    ),
                    child: Slider(
                      value: max > 0 ? value : 0,
                      max: max > 0 ? max : 1,
                      onChanged: max > 0
                          ? (v) => engine.seek(Duration(milliseconds: v.round()))
                          : null,
                    ),
                  ),
                ),
                Text(_fmt(duration), style: TextStyle(color: dw.textTertiary, fontSize: 12)),
              ],
            );
          },
        );
      },
    );
  }
}
