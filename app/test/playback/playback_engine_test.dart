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
  Future<void> append(String uri, {Map<String, String> headers = const {}}) async {
    log.add('append:$uri');
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

  test('live path: chunk 0 opens+plays, later chunks append', () async {
    final states = <PlaybackState>[];
    engine.state.listen(states.add);

    signals.add(const ChunkAvailable(jobId: 1, index: 0, url: 'http://s/c0.wav', headers: {'X-Api-Key': 'k'}));
    await pump();
    signals.add(const ChunkAvailable(jobId: 1, index: 1, url: 'http://s/c1.wav', headers: {}));
    signals.add(const ChunkAvailable(jobId: 1, index: 2, url: 'http://s/c2.wav', headers: {}));
    await pump();

    expect(sink.log, ['open:http://s/c0.wav:auth', 'play', 'append:http://s/c1.wav', 'append:http://s/c2.wav']);
    expect(states.any((s) => s.live && s.jobId == 1), isTrue);
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
    expect(sink.log.where((l) => l.startsWith('open:')), hasLength(1));
  });

  test('final file for the live job does not restart playback', () async {
    signals.add(const ChunkAvailable(jobId: 1, index: 0, url: 'c0', headers: {}));
    await pump();
    signals.add(const FinalFileReady(jobId: 1, path: '/lib/f.mp3', playedLive: true));
    await pump();
    expect(sink.log.where((l) => l.startsWith('open:')), hasLength(1));

    // now that the stream is done, completion ends the session
    sink.completed.add(null);
    await pump();
    final last = await engine.state.first.timeout(const Duration(seconds: 1), onTimeout: () => const PlaybackState());
    expect(last.jobId, isNull);
  });

  test('final file without live playback auto-plays when idle', () async {
    signals.add(const FinalFileReady(jobId: 3, path: '/lib/3.mp3', playedLive: false));
    await pump();
    expect(sink.log, ['open:/lib/3.mp3', 'play']);
  });

  test('completion mid-live-stream does not end the session (waiting on next chunk)', () async {
    final states = <PlaybackState>[];
    engine.state.listen(states.add);
    signals.add(const ChunkAvailable(jobId: 1, index: 0, url: 'c0', headers: {}));
    await pump();
    sink.completed.add(null); // playlist drained but generation continues
    await pump();
    signals.add(const ChunkAvailable(jobId: 1, index: 1, url: 'c1', headers: {}));
    await pump();
    expect(sink.log.last, 'append:c1');
    expect(states.last.jobId, 1, reason: 'session still active');
  });

  test('failure mid-stream: session ends once queue drains', () async {
    signals.add(const ChunkAvailable(jobId: 1, index: 0, url: 'c0', headers: {}));
    await pump();
    signals.add(const JobFailed(jobId: 1, error: 'x'));
    await pump();
    final states = <PlaybackState>[];
    engine.state.listen(states.add);
    sink.completed.add(null);
    await pump();
    expect(states.last.jobId, isNull);
  });

  test('manual playFile takes over and stop clears', () async {
    await engine.playFile(9, '/lib/9.mp3');
    expect(sink.log, ['open:/lib/9.mp3', 'play']);
    await engine.pause();
    await engine.resume();
    await engine.stopPlayback();
    expect(sink.log.sublist(2), ['pause', 'play', 'stop']);
  });

  test('device selection passes through', () async {
    await engine.setDevice('pulse/hdmi');
    expect(sink.device, 'pulse/hdmi');
    final devices = await engine.listDevices();
    expect(devices.map((d) => d.id), ['auto', 'pulse/hdmi']);
  });
}
