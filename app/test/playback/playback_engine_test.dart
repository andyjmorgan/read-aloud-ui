import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:read_aloud_ui/src/core/jobs/job_worker.dart';
import 'package:read_aloud_ui/src/playback/audio_sink.dart';
import 'package:read_aloud_ui/src/playback/playback_engine.dart';

class FakeSink implements AudioSink {
  final log = <String>[];
  final playing = StreamController<bool>.broadcast();
  final completed = StreamController<void>.broadcast();
  String? device;

  @override
  Future<void> open(String uri, {Map<String, String> headers = const {}}) async {
    log.add('open:$uri${headers.isNotEmpty ? ':auth' : ''}');
  }

  @override
  Future<void> play() async {
    log.add('play');
    playing.add(true);
  }

  @override
  Future<void> pause() async {
    log.add('pause');
    playing.add(false);
  }

  @override
  Future<void> stop() async {
    log.add('stop');
    playing.add(false);
  }

  @override
  Future<void> setDevice(String deviceId) async {
    device = deviceId;
    log.add('device:$deviceId');
  }

  final position = StreamController<Duration>.broadcast();
  final duration = StreamController<Duration>.broadcast();

  @override
  Future<void> seek(Duration position) async {
    log.add('seek:${position.inSeconds}');
  }

  @override
  Stream<Duration> get positionStream => position.stream;

  @override
  Stream<Duration> get durationStream => duration.stream;

  @override
  Future<List<OutputDevice>> listDevices() async => const [
        OutputDevice.auto,
        OutputDevice(id: 'pulse/hdmi', description: 'HDMI Output'),
      ];

  @override
  Stream<bool> get playingStream => playing.stream;

  @override
  Stream<void> get completedStream => completed.stream;

  @override
  Future<void> dispose() async {
    log.add('dispose');
  }

  List<String> get opens => log.where((l) => l.startsWith('open:')).toList();
}

void main() {
  late FakeSink sink;
  late StreamController<PlaybackSignal> signals;
  late PlaybackEngine engine;
  var autoPlay = true;

  setUp(() {
    sink = FakeSink();
    signals = StreamController<PlaybackSignal>.broadcast();
    autoPlay = true;
    engine = PlaybackEngine(
      sink: sink,
      signals: signals.stream,
      autoPlayEnabled: () async => autoPlay,
    );
  });

  tearDown(() async {
    if (!signals.isClosed) await signals.close();
    await engine.dispose();
  });

  Future<void> pump() => Future<void>.delayed(const Duration(milliseconds: 20));

  test('live path: chunk 0 plays immediately, queued chunks play on completion', () async {
    signals.add(const ChunkAvailable(jobId: 1, index: 0, url: 'c0', headers: {}));
    await pump();
    signals.add(const ChunkAvailable(jobId: 1, index: 1, url: 'c1', headers: {}));
    signals.add(const ChunkAvailable(jobId: 1, index: 2, url: 'c2', headers: {}));
    await pump();
    expect(sink.opens, ['open:c0'], reason: 'later chunks queue while c0 plays');

    sink.completed.add(null);
    await pump();
    expect(sink.opens, ['open:c0', 'open:c1']);

    sink.completed.add(null);
    await pump();
    expect(sink.opens, ['open:c0', 'open:c1', 'open:c2']);
  });

  test('THE STALL CASE: playlist drains before next chunk arrives, playback resumes', () async {
    final states = <PlaybackState>[];
    engine.state.listen(states.add);

    signals.add(const ChunkAvailable(jobId: 1, index: 0, url: 'c0', headers: {}));
    await pump();
    // chunk 0 finishes with NOTHING queued (generation slower than playback)
    sink.completed.add(null);
    await pump();
    expect(states.last.jobId, 1, reason: 'session survives the stall');

    // next chunk lands later — playback must resume by itself
    signals.add(const ChunkAvailable(jobId: 1, index: 1, url: 'c1', headers: {}));
    await pump();
    expect(sink.opens, ['open:c0', 'open:c1']);

    // stream completes; final chunk finishes; session ends
    signals.add(const FinalFileReady(jobId: 1, path: '/lib/f.mp3', playedLive: true));
    await pump();
    sink.completed.add(null);
    await pump();
    expect(states.last.jobId, isNull);
  });

  test('final-ready during a stall ends the session', () async {
    final states = <PlaybackState>[];
    engine.state.listen(states.add);
    signals.add(const ChunkAvailable(jobId: 1, index: 0, url: 'c0', headers: {}));
    await pump();
    sink.completed.add(null); // stalled
    await pump();
    signals.add(const FinalFileReady(jobId: 1, path: '/f.mp3', playedLive: true));
    await pump();
    expect(states.last.jobId, isNull, reason: 'nothing left to play');
  });

  test('autoplay off: live chunks are ignored', () async {
    autoPlay = false;
    signals.add(const ChunkAvailable(jobId: 1, index: 0, url: 'u', headers: {}));
    await pump();
    expect(sink.log, isEmpty);
  });

  test('second job does not hijack an active live session', () async {
    signals.add(const ChunkAvailable(jobId: 1, index: 0, url: 'a0', headers: {}));
    await pump();
    signals.add(const ChunkAvailable(jobId: 2, index: 0, url: 'b0', headers: {}));
    await pump();
    expect(sink.opens, ['open:a0']);
  });

  test('failure mid-stream: session ends once queue drains', () async {
    final states = <PlaybackState>[];
    engine.state.listen(states.add);
    signals.add(const ChunkAvailable(jobId: 1, index: 0, url: 'c0', headers: {}));
    await pump();
    signals.add(const JobFailed(jobId: 1, error: 'x'));
    await pump();
    sink.completed.add(null);
    await pump();
    expect(states.last.jobId, isNull);
  });

  test('final file without live playback auto-plays when idle, ends on completion', () async {
    final states = <PlaybackState>[];
    engine.state.listen(states.add);
    signals.add(const FinalFileReady(jobId: 3, path: '/lib/3.mp3', playedLive: false));
    await pump();
    expect(sink.opens, ['open:/lib/3.mp3']);
    expect(states.last.live, isFalse);
    sink.completed.add(null);
    await pump();
    expect(states.last.jobId, isNull);
  });

  test('manual playFile takes over live session and stop clears queue', () async {
    signals.add(const ChunkAvailable(jobId: 1, index: 0, url: 'c0', headers: {}));
    await pump();
    signals.add(const ChunkAvailable(jobId: 1, index: 1, url: 'c1', headers: {}));
    await pump();

    await engine.playFile(9, '/lib/9.mp3');
    expect(sink.opens.last, 'open:/lib/9.mp3');

    await engine.pause();
    await engine.resume();
    await engine.stopPlayback();
    expect(sink.log.sublist(sink.log.length - 3), ['pause', 'play', 'stop']);

    // queued live chunk must NOT resurface after stop
    sink.completed.add(null);
    await pump();
    expect(sink.opens.last, 'open:/lib/9.mp3');
  });

  test('seek passes through only while a job is loaded', () async {
    await engine.seek(const Duration(seconds: 5));
    expect(sink.log, isEmpty, reason: 'idle: seek ignored');
    await engine.playFile(1, '/f.mp3');
    await engine.seek(const Duration(seconds: 5));
    expect(sink.log, contains('seek:5'));
  });

  test('device selection passes through', () async {
    await engine.setDevice('pulse/hdmi');
    expect(sink.device, 'pulse/hdmi');
    final devices = await engine.listDevices();
    expect(devices.map((d) => d.id), ['auto', 'pulse/hdmi']);
  });

  test('auth headers are forwarded to the sink', () async {
    signals.add(const ChunkAvailable(jobId: 1, index: 0, url: 'http://s/c0', headers: {'X-Api-Key': 'k'}));
    await pump();
    expect(sink.opens, ['open:http://s/c0:auth']);
  });
}
