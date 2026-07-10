import 'package:flutter/material.dart';

import '../../core/db/database.dart';
import '../../playback/playback_engine.dart';
import '../theme/donkeywork_theme.dart';
import '../widgets/job_tile.dart';
import '../widgets/player_bar.dart';
import 'config_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.db,
    required this.engine,
    required this.onConfigChanged,
  });

  final AppDatabase db;
  final PlaybackEngine engine;
  final Future<void> Function() onConfigChanged;

  @override
  Widget build(BuildContext context) {
    final dw = context.dw;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ShaderMask(
              shaderCallback: (r) => const LinearGradient(
                colors: [DwColors.gradientStart, DwColors.gradientEnd],
              ).createShader(r),
              child: const Icon(Icons.graphic_eq, color: Colors.white),
            ),
            const SizedBox(width: 10),
            const Text('Read Aloud'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ConfigScreen(engine: engine, onSaved: onConfigChanged),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Job>>(
              stream: db.watchJobs(),
              builder: (context, snapshot) {
                final jobs = snapshot.data ?? const <Job>[];
                if (jobs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.record_voice_over_outlined, size: 56, color: dw.textTertiary),
                        const SizedBox(height: 16),
                        Text(
                          'Nothing here yet',
                          style: TextStyle(color: dw.textPrimary, fontSize: 20, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Send text via the read_aloud MCP tool or the CLI\nand it will stream here as audio.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: dw.textSecondary, fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: jobs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => JobTile(
                    job: jobs[i],
                    engine: engine,
                    onDelete: () => db.deleteJob(jobs[i].id),
                  ),
                );
              },
            ),
          ),
          PlayerBar(engine: engine, db: db),
        ],
      ),
    );
  }
}
