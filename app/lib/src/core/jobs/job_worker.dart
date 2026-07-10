import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';

import '../api/models.dart';
import '../api/recordings_client.dart';
import '../config.dart';
import '../db/database.dart';

/// Playback-facing signals emitted while a job progresses.
sealed class PlaybackSignal {
  const PlaybackSignal();
}

/// A contiguous chunk is ready to play (emitted strictly in index order).
class ChunkAvailable extends PlaybackSignal {
  const ChunkAvailable({required this.jobId, required this.index, required this.url, required this.headers});

  final int jobId;
  final int index;
  final String url;
  final Map<String, String> headers;
}

/// The final mp3 has been downloaded into the local library.
class FinalFileReady extends PlaybackSignal {
  const FinalFileReady({required this.jobId, required this.path, required this.playedLive});

  final int jobId;
  final String path;

  /// True when chunks were already streamed to the player for this job.
  final bool playedLive;
}

class JobFailed extends PlaybackSignal {
  const JobFailed({required this.jobId, required this.error});

  final int jobId;
  final String error;
}

/// FIFO worker: takes queued jobs from the DB, submits them to the Recordings
/// backend, consumes SSE (poll fallback), downloads the final artifact and
/// deletes the server copy. Local DB is the source of truth throughout.
class JobWorker {
  JobWorker({
    required this.db,
    required this.configStore,
    RecordingsClient Function(AppConfig config)? clientFactory,
    this.pollInterval = const Duration(seconds: 2),
  }) : _clientFactory = clientFactory ??
            ((c) => RecordingsClient(baseUrl: c.serverBaseUrl, apiKey: c.apiKey));

  final AppDatabase db;
  final ConfigStore configStore;
  final Duration pollInterval;
  final RecordingsClient Function(AppConfig) _clientFactory;

  final _signals = StreamController<PlaybackSignal>.broadcast();
  Stream<PlaybackSignal> get signals => _signals.stream;

  var _running = false;
  var _stopped = false;
  Completer<void>? _wake;

  /// Enqueue a new job; wakes the loop. Returns the job id.
  Future<int> enqueue({
    required String name,
    required List<String> paragraphs,
    String? voice,
    double? speed,
  }) async {
    final job = await db.insertJob(name: name, paragraphs: paragraphs, voice: voice, speed: speed);
    _wake?.complete();
    _wake = null;
    return job.id;
  }

  /// Runs until [stop] is called. Safe to call once.
  Future<void> run() async {
    if (_running) return;
    _running = true;
    while (!_stopped) {
      final pending = await db.pendingJobs();
      if (pending.isEmpty) {
        final wake = _wake = Completer<void>();
        await Future.any([wake.future, Future<void>.delayed(const Duration(seconds: 5))]);
        continue;
      }
      for (final job in pending) {
        if (_stopped) break;
        await _process(job);
      }
    }
  }

  void stop() {
    _stopped = true;
    _wake?.complete();
    _wake = null;
    _signals.close();
  }

  Future<void> _process(Job job) async {
    final config = await configStore.load();
    if (!config.isConfigured) {
      await _fail(job.id, 'Not configured: set server URL and API key.');
      return;
    }
    final client = _clientFactory(config);
    try {
      await db.updateJob(job.id, const JobsCompanion(status: Value(JobStatus.submitting)));
      final collectionId = await client.ensureCollection(config.scratchChannelName);
      final recording = await client.createRecording(
        collectionId: collectionId,
        name: job.name,
        paragraphs: decodeTranscript(job.transcriptJson),
        voice: job.voice ?? config.voice,
      );
      await db.updateJob(
        job.id,
        JobsCompanion(status: const Value(JobStatus.generating), recordingId: Value(recording.id)),
      );

      final outcome = await _consumeEvents(client, job.id, recording.id);
      if (outcome.error != null) {
        await _fail(job.id, outcome.error!);
        return;
      }

      await db.updateJob(job.id, const JobsCompanion(status: Value(JobStatus.downloading)));
      final dest = _libraryPathFor(config, job);
      await client.downloadToFile(outcome.finalUrl!, dest);
      final size = await File(dest).length();

      // Server copy is scratch — delete it; local library is the source of truth.
      try {
        await client.deleteRecording(recording.id);
      } on Exception {
        // best-effort: an orphaned scratch recording is acceptable
      }

      await db.updateJob(
        job.id,
        JobsCompanion(
          status: const Value(JobStatus.done),
          progress: const Value(1),
          filePath: Value(dest),
          sizeBytes: Value(size),
          durationSeconds: Value(outcome.durationSeconds),
          completedAt: Value(DateTime.now()),
        ),
      );
      _emit(FinalFileReady(jobId: job.id, path: dest, playedLive: outcome.chunksEmitted > 0));
    } on Exception catch (e) {
      await _fail(job.id, e.toString());
    } finally {
      client.close();
    }
  }

  /// Consumes SSE; on stream failure before a terminal event, falls back to
  /// polling. Emits ChunkAvailable strictly in contiguous index order.
  ///
  /// Chunks are downloaded into a local cache before being emitted: the server
  /// sweeps chunk blobs minutes after the recording settles, which would 404
  /// mid-listen on long texts if the player streamed them remotely.
  Future<_Outcome> _consumeEvents(RecordingsClient client, int jobId, String recordingId) async {
    final buffered = <int, String>{};
    var nextToEmit = 0;
    var watermark = -1;
    var emitted = 0;
    final cacheDir = '${configStore.dataDir}/cache/$jobId';

    Future<void> drain() async {
      while (nextToEmit <= watermark && buffered.containsKey(nextToEmit)) {
        final url = buffered.remove(nextToEmit)!;
        final localPath = '$cacheDir/${nextToEmit.toString().padLeft(5, '0')}.wav';
        await client.downloadToFile(url, localPath);
        _emit(ChunkAvailable(jobId: jobId, index: nextToEmit, url: localPath, headers: const {}));
        emitted++;
        nextToEmit++;
      }
    }

    try {
      await for (final event in client.openEvents(recordingId)) {
        switch (event) {
          case ChunkReadyEvent(:final index, :final url, :final playableUpTo):
            buffered[index] = url;
            if (playableUpTo > watermark) watermark = playableUpTo;
            await drain();
          case ProgressEvent(:final progress, :final statusDetail):
            await db.updateJob(
              jobId,
              JobsCompanion(progress: Value(progress), statusDetail: Value(statusDetail)),
            );
          case ReadyEvent(:final url):
            return _Outcome(finalUrl: url, chunksEmitted: emitted);
          case FailedEvent(:final error):
            return _Outcome(error: error, chunksEmitted: emitted);
        }
      }
      // Stream closed without a terminal event — degrade to polling.
    } on Exception {
      // SSE unavailable — degrade to polling.
    }

    while (true) {
      final rec = await client.getRecording(recordingId);
      for (final chunk in rec.chunks) {
        buffered.putIfAbsent(chunk.index, () => chunk.url);
      }
      if (rec.playableUpTo > watermark) watermark = rec.playableUpTo;
      await drain();
      await db.updateJob(
        jobId,
        JobsCompanion(
          progress: Value(rec.progress ?? 0),
          statusDetail: Value(rec.statusDetail),
        ),
      );
      if (rec.status == RecordingStatus.ready) {
        if (rec.filePath == null) {
          return _Outcome(error: 'recording Ready but no file path', chunksEmitted: emitted);
        }
        return _Outcome(
          finalUrl: rec.filePath,
          chunksEmitted: emitted,
          durationSeconds: rec.durationSeconds,
        );
      }
      if (rec.status == RecordingStatus.failed) {
        return _Outcome(error: rec.errorMessage ?? 'generation failed', chunksEmitted: emitted);
      }
      await Future<void>.delayed(pollInterval);
    }
  }

  String _libraryPathFor(AppConfig config, Job job) {
    final safe = job.name.replaceAll(RegExp(r'[^A-Za-z0-9._ -]'), '_').trim();
    return '${config.libraryDir}/${job.id.toString().padLeft(5, '0')}-$safe.mp3';
  }

  Future<void> _fail(int id, String error) async {
    await db.updateJob(
      id,
      JobsCompanion(
        status: const Value(JobStatus.failed),
        error: Value(error),
        completedAt: Value(DateTime.now()),
      ),
    );
    _emit(JobFailed(jobId: id, error: error));
  }

  void _emit(PlaybackSignal signal) {
    if (!_signals.isClosed) _signals.add(signal);
  }
}

class _Outcome {
  _Outcome({this.finalUrl, this.error, required this.chunksEmitted, this.durationSeconds});

  final String? finalUrl;
  final String? error;
  final int chunksEmitted;
  final double? durationSeconds;
}
