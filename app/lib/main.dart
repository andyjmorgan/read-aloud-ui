import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'src/core/config.dart';
import 'src/core/db/database.dart';
import 'src/core/ipc/singleton.dart';
import 'src/core/runtime.dart';
import 'src/playback/audio_sink.dart';
import 'src/playback/playback_engine.dart';
import 'src/ui/app.dart';

/// Entrypoints:
///   read_aloud_ui                — GUI app (primary instance; also serves IPC)
///   read_aloud_ui --mcp          — MCP server on stdio. Primary: full app.
///                                  Secondary: headless bridge → running instance.
///   read_aloud_ui speak|list …   — CLI against the running instance.
Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    stdout.writeln(usage);
    exit(0);
  }
  if (args.isNotEmpty && !args.first.startsWith('--')) {
    exit(await runCli(args));
  }

  final mcpMode = args.contains('--mcp');
  final socketPath = SingletonIpc.defaultSocketPath();

  if (mcpMode && await SingletonIpc.isInstanceRunning(socketPath)) {
    // Secondary invocation: no GUI, bridge MCP stdio → primary over the socket.
    final bridge = buildForwardingMcpServer(
      socketPath: socketPath,
      stdinStream: stdin,
      writeLine: stdout.writeln,
    );
    await bridge.serve();
    exit(0);
  }

  if (!mcpMode && await SingletonIpc.isInstanceRunning(socketPath)) {
    stderr.writeln('read-aloud is already running (socket: $socketPath).');
    exit(1);
  }

  // Primary instance: full app (GUI + IPC + worker), optionally MCP on stdio.
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await windowManager.ensureInitialized();
  await localNotifier.setup(appName: 'Read Aloud');

  final configStore = ConfigStore();
  await Directory(configStore.dataDir).create(recursive: true);
  final runtime = AppRuntime(
    db: AppDatabase.file(configStore.dbPath),
    configStore: configStore,
    ipc: SingletonIpc(socketPath: socketPath),
  );
  await runtime.start();

  final engine = PlaybackEngine(
    sink: MediaKitSink(),
    signals: runtime.worker.signals,
    autoPlayEnabled: () async => (await configStore.load()).autoPlay,
  );
  final config = await configStore.load();
  await engine.setDevice(config.audioDevice);

  if (mcpMode) {
    // Serve MCP on stdio alongside the GUI; exit when the client disconnects.
    unawaited(runtime
        .buildMcpServer(stdinStream: stdin, writeLine: stdout.writeln)
        .serve()
        .then((_) async {
      await engine.dispose();
      await runtime.stop();
      exit(0);
    }));
  }

  const options = WindowOptions(
    size: Size(720, 640),
    minimumSize: Size(640, 480),
    center: true,
    title: 'Read Aloud',
  );
  unawaited(windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.show();
    await windowManager.focus();
  }));

  runApp(ReadAloudApp(runtime: runtime, engine: engine));
}

const usage = '''
read-aloud-ui — stream text to speech via DonkeyWork-Recordings

USAGE
  read_aloud_ui                       launch the app
  read_aloud_ui --mcp                 serve MCP on stdio (bridges if app already runs)
  read_aloud_ui speak --name <n> [--voice v] [--speed s] <paragraph> [...]
                                      or pipe text: echo "..." | read_aloud_ui speak --name n --stdin
  read_aloud_ui list                  show recent jobs (requires running app)
''';

/// CLI mirroring the MCP surface over the IPC socket. Returns exit code.
Future<int> runCli(List<String> args, {String? socketPath}) async {
  final socket = socketPath ?? SingletonIpc.defaultSocketPath();
  final command = args.first;

  switch (command) {
    case 'speak':
      String? name;
      String? voice;
      double? speed;
      var useStdin = false;
      final paragraphs = <String>[];
      for (var i = 1; i < args.length; i++) {
        switch (args[i]) {
          case '--name':
            name = args[++i];
          case '--voice':
            voice = args[++i];
          case '--speed':
            speed = double.tryParse(args[++i]);
          case '--stdin':
            useStdin = true;
          default:
            paragraphs.add(args[i]);
        }
      }
      if (useStdin) {
        final text = await stdin.transform(utf8.decoder).join();
        paragraphs.addAll(
          text.split(RegExp(r'\n\s*\n')).map((p) => p.trim()).where((p) => p.isNotEmpty),
        );
      }
      if (name == null || paragraphs.isEmpty) {
        stderr.writeln('speak requires --name and at least one paragraph (args or --stdin).');
        return 2;
      }
      final reply = await SingletonIpc.request(socket, {
        'cmd': 'speak',
        'name': name,
        'paragraphs': paragraphs,
        'voice': ?voice,
        'speed': ?speed,
      });
      if (reply == null) {
        stderr.writeln('read-aloud is not running — start the app first.');
        return 3;
      }
      stdout.writeln(jsonEncode(reply));
      return reply['ok'] == true ? 0 : 1;

    case 'list':
      final reply = await SingletonIpc.request(socket, {'cmd': 'list'});
      if (reply == null) {
        stderr.writeln('read-aloud is not running — start the app first.');
        return 3;
      }
      for (final job in (reply['jobs'] as List? ?? [])) {
        final j = (job as Map).cast<String, Object?>();
        stdout.writeln('#${j['id']}  [${j['status']}]  ${j['name']}'
            '${j['error'] != null ? '  error: ${j['error']}' : ''}');
      }
      return 0;

    default:
      stderr.writeln('unknown command: $command\n$usage');
      return 2;
  }
}
