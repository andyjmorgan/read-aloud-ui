import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:read_aloud_ui/src/core/config.dart';
import 'package:read_aloud_ui/src/core/db/database.dart';
import 'package:read_aloud_ui/src/core/jobs/job_worker.dart';

import '../support/fake_server.dart';

void main() {
  late FakeRecordingsServer server;
  late AppDatabase db;
  late Directory tmp;
  late ConfigStore configStore;
  late JobWorker worker;

  setUp(() async {
    server = await FakeRecordingsServer.start();
    db = AppDatabase.memory();
    tmp = await Directory.systemTemp.createTemp('ra-worker');
    configStore = ConfigStore(configPath: '${tmp.path}/config.json', dataDir: '${tmp.path}/data');
    await configStore.save(AppConfig(
      serverBaseUrl: server.baseUrl,
      apiKey: FakeRecordingsServer.validKey,
      libraryDir: '${tmp.path}/library',
    ));
    worker = JobWorker(
      db: db,
      configStore: configStore,
      pollInterval: const Duration(milliseconds: 50),
    );
  });

  tearDown(() async {
    worker.stop();
    await server.close();
    await db.close();
    await tmp.delete(recursive: true);
  });

  /// Drives one job to a terminal state, scripting the fake recording once it
  /// appears. Returns collected playback signals.
  Future<List<PlaybackSignal>> runJob(
    Future<void> Function(FakeRecording rec) script, {
    String name = 'job',
  }) async {
    final signals = <PlaybackSignal>[];
    final sub = worker.signals.listen(signals.add);
    final done = Completer<void>();
    late StreamSubscription<List<Job>> watch;
    watch = db.watchJobs().listen((jobs) {
      if (jobs.isNotEmpty &&
          (jobs.first.status == JobStatus.done || jobs.first.status == JobStatus.failed)) {
        if (!done.isCompleted) done.complete();
      }
    });

    unawaited(worker.run());
    await worker.enqueue(name: name, paragraphs: ['p1', 'p2']);

    // wait for the recording to be created server-side, then script it
    while (server.recordings.isEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    await script(server.recordings.values.first);

    await done.future.timeout(const Duration(seconds: 10));
    await watch.cancel();
    await sub.cancel();
    return signals;
  }

  test('happy path: SSE chunks stream in order, file downloads, server copy deleted', () async {
    final signals = await runJob((rec) async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      rec.emitProgress(0.2, 'segment 1 of 3');
      rec.emitChunk(0, '${server.baseUrl}/media/c0.wav', 0);
      // out-of-order completion: 2 lands before 1; gate must hold it back
      rec.emitChunk(2, '${server.baseUrl}/media/c2.wav', 0);
      rec.emitChunk(1, '${server.baseUrl}/media/c1.wav', 2);
      rec.emitReady('${server.baseUrl}/media/final.mp3');
    });

    final chunks = signals.whereType<ChunkAvailable>().toList();
    expect(chunks.map((c) => c.index), [0, 1, 2], reason: 'strictly contiguous order');
    // chunks are cached locally before playback (server sweeps them post-Ready)
    expect(chunks.first.url, startsWith('${tmp.path}/data/cache/'));
    expect(await File(chunks.first.url).readAsString(), 'AUDIO:/media/c0.wav');
    expect(chunks.first.headers, isEmpty);

    final ready = signals.whereType<FinalFileReady>().single;
    expect(ready.playedLive, isTrue);
    expect(await File(ready.path).exists(), isTrue);

    final job = (await db.allJobs()).single;
    expect(job.status, JobStatus.done);
    expect(job.progress, 1);
    expect(job.filePath, ready.path);
    expect(job.sizeBytes, greaterThan(0));
    expect(job.completedAt, isNotNull);
    expect(server.recordings, isEmpty, reason: 'server scratch copy deleted');
  });

  test('failed generation marks job failed with error', () async {
    final signals = await runJob((rec) async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      rec.emitProgress(0.5, 'halfway');
      rec.emitFailed('kokoro exploded');
    });
    expect(signals.whereType<JobFailed>().single.error, 'kokoro exploded');
    final job = (await db.allJobs()).single;
    expect(job.status, JobStatus.failed);
    expect(job.error, 'kokoro exploded');
  });

  test('SSE unavailable: falls back to polling and still completes', () async {
    server.sseEnabled = false;
    final signals = await runJob((rec) async {
      rec.chunks.add({'index': 0, 'url': '${server.baseUrl}/media/c0.wav'});
      rec.playableUpTo = 0;
      rec.progress = 0.5;
      rec.statusDetail = 'polling path';
      rec.status = 'Generating';
      await Future<void>.delayed(const Duration(milliseconds: 200));
      rec.status = 'Ready';
      rec.filePath = '${server.baseUrl}/media/final.mp3';
      rec.progress = 1;
    });
    expect(signals.whereType<ChunkAvailable>().single.index, 0);
    expect(signals.whereType<FinalFileReady>(), hasLength(1));
    final job = (await db.allJobs()).single;
    expect(job.status, JobStatus.done);
    expect(server.recordings.values, isEmpty);
  });

  test('SSE severed mid-stream: poll fallback finishes the job without duplicate chunks', () async {
    server.cutSseAfterEvents = 2;
    final signals = await runJob((rec) async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      rec.emitChunk(0, '${server.baseUrl}/media/c0.wav', 0);
      rec.emitChunk(1, '${server.baseUrl}/media/c1.wav', 1); // stream cut after this
      await Future<void>.delayed(const Duration(milliseconds: 200));
      rec.chunks.add({'index': 2, 'url': '${server.baseUrl}/media/c2.wav'});
      rec.playableUpTo = 2;
      await Future<void>.delayed(const Duration(milliseconds: 200));
      rec.status = 'Ready';
      rec.filePath = '${server.baseUrl}/media/final.mp3';
    });
    final indices = signals.whereType<ChunkAvailable>().map((c) => c.index).toList();
    expect(indices, [0, 1, 2], reason: 'no duplicates after fallback');
    expect((await db.allJobs()).single.status, JobStatus.done);
  });

  test('unconfigured store fails jobs cleanly', () async {
    await configStore.save(AppConfig(serverBaseUrl: '', apiKey: '', libraryDir: 'x'));
    unawaited(worker.run());
    final id = await worker.enqueue(name: 'n', paragraphs: ['p']);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final job = (await db.getJob(id))!;
    expect(job.status, JobStatus.failed);
    expect(job.error, contains('Not configured'));
  });

  test('FIFO: two jobs processed in order', () async {
    unawaited(worker.run());
    await worker.enqueue(name: 'first', paragraphs: ['a']);
    await worker.enqueue(name: 'second', paragraphs: ['b']);

    while (server.recordings.isEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    final firstRec = server.recordings.values.first;
    expect(firstRec.createBody!['name'], 'first');
    await Future<void>.delayed(const Duration(milliseconds: 100));
    firstRec.emitReady('${server.baseUrl}/media/f1.mp3');

    while (server.recordings.values.where((r) => r.createBody?['name'] == 'second').isEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    final secondRec = server.recordings.values.firstWhere((r) => r.createBody?['name'] == 'second');
    await Future<void>.delayed(const Duration(milliseconds: 100));
    secondRec.emitReady('${server.baseUrl}/media/f2.mp3');

    while ((await db.pendingJobs()).isNotEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    final jobs = await db.allJobs();
    expect(jobs.every((j) => j.status == JobStatus.done), isTrue);
  });

  test('transcript is stored locally before submission', () async {
    final id = await worker.enqueue(name: 'keep', paragraphs: ['alpha', 'beta']);
    final job = (await db.getJob(id))!;
    expect(decodeTranscript(job.transcriptJson), ['alpha', 'beta']);
    expect(job.status, JobStatus.queued);
  });
}
