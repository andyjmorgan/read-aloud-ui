import 'package:flutter/material.dart';

import '../../core/db/database.dart';
import '../../playback/playback_engine.dart';
import '../theme/donkeywork_theme.dart';

class JobTile extends StatelessWidget {
  const JobTile({super.key, required this.job, required this.engine, required this.onDelete});

  final Job job;
  final PlaybackEngine engine;
  final VoidCallback onDelete;

  bool get _active =>
      job.status == JobStatus.submitting ||
      job.status == JobStatus.generating ||
      job.status == JobStatus.downloading;

  @override
  Widget build(BuildContext context) {
    final dw = context.dw;
    final transcript = decodeTranscript(job.transcriptJson);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _StatusBadge(status: job.status),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    job.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: dw.textPrimary, fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),
                if (job.status == JobStatus.done && job.filePath != null)
                  IconButton(
                    tooltip: 'Play',
                    icon: Icon(Icons.play_circle_outline, color: dw.accent),
                    onPressed: () => engine.playFile(job.id, job.filePath!),
                  ),
                if (!_active)
                  IconButton(
                    tooltip: 'Delete',
                    icon: Icon(Icons.delete_outline, color: dw.textTertiary),
                    onPressed: onDelete,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              transcript.join(' '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: dw.textSecondary, fontSize: 13),
            ),
            if (_active) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: job.progress <= 0 ? null : job.progress, minHeight: 6),
              ),
              if (job.statusDetail != null) ...[
                const SizedBox(height: 6),
                Text(job.statusDetail!, style: TextStyle(color: dw.textTertiary, fontSize: 12)),
              ],
            ],
            if (job.status == JobStatus.failed && job.error != null) ...[
              const SizedBox(height: 8),
              Text(job.error!, style: TextStyle(color: dw.error, fontSize: 12)),
            ],
            if (job.status == JobStatus.done) ...[
              const SizedBox(height: 6),
              Text(
                _meta(),
                style: TextStyle(color: dw.textTertiary, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _meta() {
    final parts = <String>[];
    if (job.durationSeconds != null) {
      final d = Duration(seconds: job.durationSeconds!.round());
      parts.add('${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}');
    }
    if (job.sizeBytes != null) {
      parts.add('${(job.sizeBytes! / (1024 * 1024)).toStringAsFixed(1)} MB');
    }
    final at = job.completedAt;
    if (at != null) {
      parts.add('${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}');
    }
    return parts.join(' · ');
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final JobStatus status;

  @override
  Widget build(BuildContext context) {
    final dw = context.dw;
    final (color, label) = switch (status) {
      JobStatus.queued => (dw.textTertiary, 'Queued'),
      JobStatus.submitting => (dw.warning, 'Submitting'),
      JobStatus.generating => (dw.accent, 'Generating'),
      JobStatus.downloading => (dw.accent, 'Downloading'),
      JobStatus.done => (dw.success, 'Ready'),
      JobStatus.failed => (dw.error, 'Failed'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
