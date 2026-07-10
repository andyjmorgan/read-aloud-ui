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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: dw.bgElevated,
            border: Border(top: BorderSide(color: dw.border)),
          ),
          child: Row(
            children: [
              if (state.live)
                Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: dw.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text('LIVE', style: TextStyle(color: dw.accent, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
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
        );
      },
    );
  }
}
