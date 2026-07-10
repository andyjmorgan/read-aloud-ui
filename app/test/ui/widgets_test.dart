import 'dart:async';
import 'package:drift/drift.dart' as drift;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:read_aloud_ui/src/core/config.dart';
import 'package:read_aloud_ui/src/core/db/database.dart';
import 'package:read_aloud_ui/src/core/jobs/job_worker.dart';
import 'package:read_aloud_ui/src/playback/playback_engine.dart';
import 'package:read_aloud_ui/src/ui/screens/config_screen.dart';
import 'package:read_aloud_ui/src/ui/screens/home_screen.dart';
import 'package:read_aloud_ui/src/ui/theme/donkeywork_theme.dart';
import 'package:read_aloud_ui/src/ui/widgets/job_tile.dart';
import 'package:read_aloud_ui/src/ui/widgets/player_bar.dart';

import '../playback/playback_engine_test.dart' show FakeSink;

Widget _wrap(Widget child, {Brightness brightness = Brightness.dark}) =>
    MaterialApp(theme: donkeyWorkTheme(brightness), home: child);

/// Unmounts the tree and drains drift's stream keep-alive timers so the
/// fake-async `!timersPending` invariant passes at test teardown.
Future<void> _drainTimers(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 15));
}

/// Polls real async (IO, engine chains) until [finder] matches.
Future<void> _waitFor(WidgetTester tester, Finder finder, {int tries = 40}) async {
  for (var i = 0; i < tries; i++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
  }
  fail('timed out waiting for $finder');
}

/// Tall viewport so the whole config form is built (ListView is lazy).
void _tallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

PlaybackEngine _engine(FakeSink sink, StreamController<PlaybackSignal> signals) =>
    PlaybackEngine(sink: sink, signals: signals.stream, autoPlayEnabled: () async => true);

void main() {
  late AppDatabase db;
  late FakeSink sink;
  late StreamController<PlaybackSignal> signals;
  late PlaybackEngine engine;

  setUp(() {
    db = AppDatabase.memory();
    sink = FakeSink();
    signals = StreamController<PlaybackSignal>.broadcast();
    engine = _engine(sink, signals);
  });

  tearDown(() async {
    await signals.close();
    await engine.dispose();
    await db.close();
  });

  group('HomeScreen', () {
    testWidgets('empty state renders hint', (tester) async {
      await tester.pumpWidget(_wrap(HomeScreen(db: db, engine: engine, onConfigChanged: () async {})));
      await tester.pump();
      expect(find.text('Nothing here yet'), findsOneWidget);
      expect(find.textContaining('read_aloud MCP tool'), findsOneWidget);
      await _drainTimers(tester);
    });

    testWidgets('jobs render as tiles, both themes', (tester) async {
      await db.insertJob(name: 'First article', paragraphs: ['Hello world']);
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(_wrap(
          HomeScreen(db: db, engine: engine, onConfigChanged: () async {}),
          brightness: brightness,
        ));
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('First article'), findsOneWidget);
        expect(find.byType(JobTile), findsOneWidget);
      }
      await _drainTimers(tester);
    });
  });

  group('JobTile', () {
    Future<Job> jobWith(WidgetTester tester, JobStatus status,
        {String? error, String? filePath, double progress = 0.4}) async {
      final job = await db.insertJob(name: 'tile', paragraphs: ['para one', 'para two']);
      await db.updateJob(
          job.id,
          JobsCompanion(
            status: drift.Value(status),
            error: drift.Value(error),
            filePath: drift.Value(filePath),
            progress: drift.Value(progress),
            statusDetail: const drift.Value('segment 1 of 2'),
            durationSeconds: const drift.Value(63),
            sizeBytes: const drift.Value(2 * 1024 * 1024),
            completedAt: drift.Value(status == JobStatus.done ? DateTime(2026, 7, 10, 14, 30) : null),
          ));
      return (await db.getJob(job.id))!;
    }

    testWidgets('generating shows progress + detail', (tester) async {
      final job = await jobWith(tester, JobStatus.generating);
      await tester.pumpWidget(_wrap(Scaffold(
        body: JobTile(job: job, engine: engine, onDelete: () {}),
      )));
      expect(find.text('Generating'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('segment 1 of 2'), findsOneWidget);
      expect(find.byTooltip('Delete'), findsNothing, reason: 'active jobs cannot be deleted');
      await _drainTimers(tester);
    });

    testWidgets('failed shows error and delete', (tester) async {
      final job = await jobWith(tester, JobStatus.failed, error: 'kokoro exploded');
      var deleted = false;
      await tester.pumpWidget(_wrap(Scaffold(
        body: JobTile(job: job, engine: engine, onDelete: () => deleted = true),
      )));
      expect(find.text('Failed'), findsOneWidget);
      expect(find.text('kokoro exploded'), findsOneWidget);
      await tester.tap(find.byTooltip('Delete'));
      expect(deleted, isTrue);
      await _drainTimers(tester);
    });

    testWidgets('done shows meta and play triggers engine', (tester) async {
      final job = await jobWith(tester, JobStatus.done, filePath: '/lib/x.mp3', progress: 1);
      await tester.pumpWidget(_wrap(Scaffold(
        body: JobTile(job: job, engine: engine, onDelete: () {}),
      )));
      expect(find.text('Ready'), findsOneWidget);
      expect(find.textContaining('1:03'), findsOneWidget);
      expect(find.textContaining('2.0 MB'), findsOneWidget);
      expect(find.textContaining('14:30'), findsOneWidget);
      await tester.tap(find.byTooltip('Play'));
      await tester.pump();
      expect(sink.log, contains('open:/lib/x.mp3'));
      await _drainTimers(tester);
    });
  });

  group('PlayerBar', () {
    testWidgets('live badge shows during live streaming', (tester) async {
      final job = await db.insertJob(name: 'now playing', paragraphs: ['x']);
      await tester.pumpWidget(_wrap(Scaffold(body: PlayerBar(engine: engine, db: db))));
      expect(find.byTooltip('Stop'), findsNothing);

      await tester.runAsync(() async {
        signals.add(ChunkAvailable(jobId: job.id, index: 0, url: 'c0', headers: const {}));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await _waitFor(tester, find.text('LIVE'));
      await _waitFor(tester, find.text('now playing'));
      await _drainTimers(tester);
    });

    testWidgets('controls pause/resume/stop a library file', (tester) async {
      final job = await db.insertJob(name: 'library file', paragraphs: ['x']);
      await tester.pumpWidget(_wrap(Scaffold(body: PlayerBar(engine: engine, db: db))));
      await tester.runAsync(() => engine.playFile(job.id, '/lib/f.mp3'));
      await _waitFor(tester, find.byTooltip('Pause'));
      expect(find.text('LIVE'), findsNothing, reason: 'library playback is not live');

      await tester.tap(find.byTooltip('Pause'));
      await _waitFor(tester, find.byTooltip('Resume'));
      expect(sink.log, contains('pause'));

      await tester.tap(find.byTooltip('Resume'));
      await _waitFor(tester, find.byTooltip('Pause'));

      await tester.tap(find.byTooltip('Stop'));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
      expect(sink.log, contains('stop'));
      expect(find.byTooltip('Stop'), findsNothing, reason: 'bar hides when idle');
      await _drainTimers(tester);
    });
  });

  group('ConfigScreen', () {
    late _MemConfigStore store;

    setUp(() => store = _MemConfigStore());

    testWidgets('loads, validates, saves config incl. audio device', (tester) async {
      _tallViewport(tester);
      var savedCallback = false;
      await tester.pumpWidget(_wrap(ConfigScreen(
        engine: engine,
        configStore: store,
        onSaved: () async => savedCallback = true,
      )));
      await _waitFor(tester, find.text('Save settings'));

      // invalid: empty URL blocks save
      await tester.tap(find.text('Save settings'));
      await tester.pump();
      expect(find.text('Enter a valid absolute URL'), findsOneWidget);
      expect(store.saved, isNull);

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Recordings server URL'), 'http://server:5000');
      await tester.enterText(find.widgetWithText(TextFormField, 'API key'), 'secret');

      // pick the HDMI device from the fake sink's list
      await tester.tap(find.text('System default'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('HDMI Output').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save settings'));
      await _waitFor(tester, find.text('Settings saved'));

      expect(savedCallback, isTrue);
      final saved = store.saved!;
      expect(saved.serverBaseUrl, 'http://server:5000');
      expect(saved.apiKey, 'secret');
      expect(saved.audioDevice, 'pulse/hdmi');
      expect(sink.device, 'pulse/hdmi');
      await _drainTimers(tester);
    });

    testWidgets('api key is obscured with toggle', (tester) async {
      _tallViewport(tester);
      store.seed = AppConfig(serverBaseUrl: 'http://s', apiKey: 'k', libraryDir: '/lib');
      await tester.pumpWidget(_wrap(ConfigScreen(engine: engine, configStore: store, onSaved: () async {})));
      await _waitFor(tester, find.byIcon(Icons.visibility_outlined));
      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pump();
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
      await _drainTimers(tester);
    });
  });
}

/// In-memory ConfigStore — widget tests must not touch real file IO
/// (dart:io futures stall under the widget-test fake-async zone).
class _MemConfigStore extends ConfigStore {
  _MemConfigStore() : super(configPath: '/nonexistent/config.json', dataDir: '/nonexistent');

  AppConfig? seed;
  AppConfig? saved;

  @override
  Future<AppConfig> load() async =>
      seed ?? AppConfig(serverBaseUrl: '', apiKey: '', libraryDir: defaultLibraryDir);

  @override
  Future<void> save(AppConfig config) async => saved = config;
}
