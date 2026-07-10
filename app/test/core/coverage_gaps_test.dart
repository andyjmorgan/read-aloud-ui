import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:read_aloud_ui/src/core/api/models.dart';
import 'package:read_aloud_ui/src/core/api/recordings_client.dart';
import 'package:read_aloud_ui/src/core/config.dart';
import 'package:read_aloud_ui/src/core/db/database.dart';
import 'package:read_aloud_ui/src/core/ipc/singleton.dart';
import 'package:read_aloud_ui/src/core/runtime.dart';

import '../support/fake_server.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('ra-gaps');
  });

  tearDown(() async => tmp.delete(recursive: true));

  group('models', () {
    test('recordingStatusFrom maps all statuses case-insensitively', () {
      expect(recordingStatusFrom('Pending'), RecordingStatus.pending);
      expect(recordingStatusFrom('generating'), RecordingStatus.generating);
      expect(recordingStatusFrom('READY'), RecordingStatus.ready);
      expect(recordingStatusFrom('Failed'), RecordingStatus.failed);
      expect(recordingStatusFrom('whatever'), RecordingStatus.unknown);
      expect(recordingStatusFrom(null), RecordingStatus.unknown);
    });
  });

  group('RecordingsApiException', () {
    test('toString carries status and message', () {
      expect(
        RecordingsApiException('nope', statusCode: 418).toString(),
        'RecordingsApiException(418): nope',
      );
    });
  });

  group('AppDatabase.file', () {
    test('persists to disk across instances and table schema is exercised', () async {
      final path = '${tmp.path}/jobs.db';
      final db1 = AppDatabase.file(path);
      final job = await db1.insertJob(name: 'persisted', paragraphs: ['x']);
      await db1.close();

      final db2 = AppDatabase.file(path);
      final reloaded = await db2.getJob(job.id);
      expect(reloaded?.name, 'persisted');
      expect(decodeTranscript(reloaded!.transcriptJson), ['x']);
      expect(reloaded.progress, 0);
      expect(reloaded.createdAt, isNotNull);
      expect(reloaded.completedAt, isNull);
      await db2.close();
    });
  });

  group('ConfigStore defaults', () {
    test('default paths derive from environment', () {
      final store = ConfigStore();
      expect(store.configPath, endsWith('read-aloud/config.json'));
      expect(store.dataDir, endsWith('read-aloud'));
      expect(store.defaultLibraryDir, '${store.dataDir}/library');
      expect(store.dbPath, '${store.dataDir}/read-aloud.db');
    });
  });

  group('SingletonIpc', () {
    test('defaultSocketPath uses runtime dir', () {
      expect(SingletonIpc.defaultSocketPath(), endsWith('read-aloud.sock'));
    });

    test('serve steals a stale (dead) socket file', () async {
      final path = '${tmp.path}/stale.sock';
      // a crashed instance leaves the socket path behind with nobody listening
      File(path).writeAsStringSync('');
      expect(File(path).existsSync(), isTrue);

      final ipc = SingletonIpc(socketPath: path);
      await ipc.serve((msg) async => {'ok': true, 'stolen': true});
      addTearDown(ipc.close);
      final reply = await SingletonIpc.request(path, {'cmd': 'ping'});
      expect(reply?['stolen'], isTrue);
    });

    test('request returns null on malformed reply', () async {
      final path = '${tmp.path}/garbage.sock';
      final server = await ServerSocket.bind(InternetAddress(path, type: InternetAddressType.unix), 0);
      addTearDown(() => server.close());
      server.listen((s) {
        s.write('this is not json\n');
        s.flush();
      });
      final reply = await SingletonIpc.request(path, {'cmd': 'ping'}, timeout: const Duration(seconds: 1));
      expect(reply, isNull);
    });
  });

  group('AppRuntime lifecycle', () {
    test('start binds ipc + worker, ping answers, stop tears down', () async {
      final server = await FakeRecordingsServer.start();
      addTearDown(server.close);
      final configStore = ConfigStore(configPath: '${tmp.path}/c.json', dataDir: '${tmp.path}/d');
      await configStore.save(AppConfig(
        serverBaseUrl: server.baseUrl,
        apiKey: FakeRecordingsServer.validKey,
        libraryDir: '${tmp.path}/lib',
      ));
      final runtime = AppRuntime(
        db: AppDatabase.memory(),
        configStore: configStore,
        ipc: SingletonIpc(socketPath: '${tmp.path}/rt.sock'),
      );
      await runtime.start();

      final ping = await SingletonIpc.request(runtime.ipc.socketPath, {'cmd': 'ping'});
      expect(ping?['ok'], isTrue);
      expect(ping?['pid'], pid);

      // speak flows through the live worker to a terminal state
      final speak = await SingletonIpc.request(runtime.ipc.socketPath, {
        'cmd': 'speak',
        'name': 'lifecycle',
        'paragraphs': ['hello'],
      });
      expect(speak?['ok'], isTrue);
      while (server.recordings.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      server.recordings.values.first.emitReady('${server.baseUrl}/media/f.mp3');
      while ((await runtime.db.pendingJobs()).isNotEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }

      await runtime.stop();
      expect(File(runtime.ipc.socketPath).existsSync(), isFalse);
    });

    test('handleSpeak validates input', () async {
      final runtime = AppRuntime(
        db: AppDatabase.memory(),
        configStore: ConfigStore(configPath: '${tmp.path}/c2.json', dataDir: '${tmp.path}/d2'),
        ipc: SingletonIpc(socketPath: '${tmp.path}/v.sock'),
      );
      addTearDown(() => runtime.db.close());
      expect((await runtime.handleSpeak({'name': '', 'paragraphs': ['x']}))['ok'], isFalse);
      expect((await runtime.handleSpeak({'name': 'x'}))['ok'], isFalse);
      expect((await runtime.handleSpeak({'name': 'x', 'paragraphs': <String>[]}))['ok'], isFalse);
    });

    test('buildMcpServer serves tools/call through the runtime', () async {
      final runtime = AppRuntime(
        db: AppDatabase.memory(),
        configStore: ConfigStore(configPath: '${tmp.path}/c3.json', dataDir: '${tmp.path}/d3'),
        ipc: SingletonIpc(socketPath: '${tmp.path}/m.sock'),
      );
      addTearDown(() => runtime.db.close());
      final stdin = StreamController<List<int>>();
      final replies = <Map<String, Object?>>[];
      final mcp = runtime.buildMcpServer(
        stdinStream: stdin.stream,
        writeLine: (l) => replies.add((jsonDecode(l) as Map).cast<String, Object?>()),
      );
      final serving = mcp.serve();
      stdin.add(utf8.encode('${jsonEncode({
            'jsonrpc': '2.0',
            'id': 1,
            'method': 'tools/call',
            'params': {
              'name': 'read_aloud',
              'arguments': {'name': 'via runtime', 'paragraphs': ['x']},
            },
          })}\n'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await stdin.close();
      await serving;
      expect((replies.single['result']! as Map)['isError'], isFalse);
      expect((await runtime.db.allJobs()).single.name, 'via runtime');
    });
  });
}
