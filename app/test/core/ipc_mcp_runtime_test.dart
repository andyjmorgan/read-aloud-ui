import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;

import 'package:flutter_test/flutter_test.dart';
import 'package:read_aloud_ui/src/core/config.dart';
import 'package:read_aloud_ui/src/core/db/database.dart';
import 'package:read_aloud_ui/src/core/ipc/singleton.dart';
import 'package:read_aloud_ui/src/core/mcp/mcp_server.dart';
import 'package:read_aloud_ui/src/core/runtime.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('ra-ipc');
  });

  tearDown(() async => tmp.delete(recursive: true));

  String sock(String name) => '${tmp.path}/$name.sock';

  group('SingletonIpc', () {
    test('request returns null when nobody listens', () async {
      expect(await SingletonIpc.request(sock('none'), {'cmd': 'ping'}), isNull);
      expect(await SingletonIpc.isInstanceRunning(sock('none')), isFalse);
    });

    test('serve + request round-trip', () async {
      final ipc = SingletonIpc(socketPath: sock('a'));
      await ipc.serve((msg) async => {'ok': true, 'echo': msg['cmd']});
      addTearDown(ipc.close);
      final reply = await SingletonIpc.request(ipc.socketPath, {'cmd': 'ping'});
      expect(reply, {'ok': true, 'echo': 'ping'});
      expect(await SingletonIpc.isInstanceRunning(ipc.socketPath), isTrue);
    });

    test('second serve on live socket throws; stale socket is stolen', () async {
      final ipc1 = SingletonIpc(socketPath: sock('b'));
      await ipc1.serve((msg) async => {'ok': true});
      final ipc2 = SingletonIpc(socketPath: sock('b'));
      await expectLater(ipc2.serve((msg) async => {'ok': true}), throwsStateError);
      await ipc1.close();
      // socket file gone after close → a new instance can bind
      final ipc3 = SingletonIpc(socketPath: sock('b'));
      await ipc3.serve((msg) async => {'ok': true, 'gen': 3});
      addTearDown(ipc3.close);
      final reply = await SingletonIpc.request(ipc3.socketPath, {'cmd': 'ping'});
      expect(reply?['gen'], 3);
    });

    test('handler exception maps to ok:false', () async {
      final ipc = SingletonIpc(socketPath: sock('c'));
      await ipc.serve((msg) async => throw Exception('nope'));
      addTearDown(ipc.close);
      final reply = await SingletonIpc.request(ipc.socketPath, {'cmd': 'speak'});
      expect(reply?['ok'], isFalse);
      expect(reply?['error'], contains('nope'));
    });
  });

  group('McpServer', () {
    late StreamController<List<int>> stdin;
    late List<Map<String, Object?>> replies;
    late McpServer mcp;
    late Future<void> serving;
    Map<String, Object?>? lastToolArgs;

    setUp(() {
      stdin = StreamController<List<int>>();
      replies = [];
      lastToolArgs = null;
      mcp = McpServer(
        stdinStream: stdin.stream,
        writeLine: (l) => replies.add((jsonDecode(l) as Map).cast<String, Object?>()),
        onReadAloud: (args) async {
          lastToolArgs = args;
          return {'ok': true, 'jobId': 42, 'status': 'queued'};
        },
      );
      serving = mcp.serve();
    });

    Future<void> send(Map<String, Object?> msg) async {
      stdin.add(utf8.encode('${jsonEncode(msg)}\n'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    Future<void> finish() async {
      await stdin.close();
      await serving;
    }

    test('initialize handshake + tools/list + tools/call', () async {
      await send({'jsonrpc': '2.0', 'id': 1, 'method': 'initialize', 'params': {'protocolVersion': '2025-06-18'}});
      await send({'jsonrpc': '2.0', 'method': 'notifications/initialized'});
      await send({'jsonrpc': '2.0', 'id': 2, 'method': 'tools/list'});
      await send({
        'jsonrpc': '2.0',
        'id': 3,
        'method': 'tools/call',
        'params': {
          'name': 'read_aloud',
          'arguments': {'name': 'test', 'paragraphs': ['hello world'], 'voice': 'af_bella'},
        },
      });
      await finish();

      expect(replies, hasLength(3), reason: 'notification gets no reply');
      final init = replies[0]['result']! as Map;
      expect((init['serverInfo'] as Map)['name'], 'read-aloud-ui');
      final tools = ((replies[1]['result']! as Map)['tools'] as List);
      expect((tools.single as Map)['name'], 'read_aloud');
      final call = replies[2]['result']! as Map;
      expect(call['isError'], isFalse);
      expect(jsonDecode(((call['content'] as List).single as Map)['text'] as String), containsPair('jobId', 42));
      expect(lastToolArgs?['voice'], 'af_bella');
    });

    test('unknown method → -32601, parse error → -32700', () async {
      await send({'jsonrpc': '2.0', 'id': 9, 'method': 'bogus/method'});
      stdin.add(utf8.encode('this is not json\n'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await finish();
      expect((replies[0]['error']! as Map)['code'], -32601);
      expect((replies[1]['error']! as Map)['code'], -32700);
    });

    test('validation failures are tool errors, not protocol errors', () async {
      await send({
        'jsonrpc': '2.0',
        'id': 4,
        'method': 'tools/call',
        'params': {'name': 'read_aloud', 'arguments': {'name': '', 'paragraphs': []}},
      });
      await send({
        'jsonrpc': '2.0',
        'id': 5,
        'method': 'tools/call',
        'params': {'name': 'wrong_tool', 'arguments': {}},
      });
      await finish();
      expect((replies[0]['result']! as Map)['isError'], isTrue);
      expect((replies[1]['result']! as Map)['isError'], isTrue);
      expect(lastToolArgs, isNull);
    });
  });

  group('AppRuntime', () {
    test('IPC speak enqueues a job; list reports it; forwarding MCP bridges', () async {
      final configStore = ConfigStore(configPath: '${tmp.path}/c.json', dataDir: '${tmp.path}/d');
      final runtime = AppRuntime(
        db: AppDatabase.memory(),
        configStore: configStore,
        ipc: SingletonIpc(socketPath: sock('rt')),
      );
      await runtime.ipc.serve(runtime.handleIpcRequest);
      addTearDown(() async {
        await runtime.ipc.close();
        await runtime.db.close();
      });

      // second-instance path: speak over the socket
      final speak = await SingletonIpc.request(sock('rt'), {
        'cmd': 'speak',
        'name': 'from second instance',
        'paragraphs': ['hello'],
      });
      expect(speak?['ok'], isTrue);
      expect(speak?['jobId'], isA<int>());

      final list = await SingletonIpc.request(sock('rt'), {'cmd': 'list'});
      expect(((list?['jobs'] as List?) ?? []).length, 1);

      final unknown = await SingletonIpc.request(sock('rt'), {'cmd': 'wat'});
      expect(unknown?['ok'], isFalse);

      // forwarding MCP server (bridge mode) drives the same socket
      final stdin = StreamController<List<int>>();
      final replies = <Map<String, Object?>>[];
      final bridge = buildForwardingMcpServer(
        socketPath: sock('rt'),
        stdinStream: stdin.stream,
        writeLine: (l) => replies.add((jsonDecode(l) as Map).cast<String, Object?>()),
      );
      final serving = bridge.serve();
      stdin.add(utf8.encode('${jsonEncode({
            'jsonrpc': '2.0',
            'id': 1,
            'method': 'tools/call',
            'params': {
              'name': 'read_aloud',
              'arguments': {'name': 'bridged', 'paragraphs': ['x']},
            },
          })}\n'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await stdin.close();
      await serving;
      final result = replies.single['result']! as Map;
      expect(result['isError'], isFalse);

      final list2 = await SingletonIpc.request(sock('rt'), {'cmd': 'list'});
      expect(((list2?['jobs'] as List?) ?? []).length, 2);
    });

    test('bridge reports unreachable primary as tool error', () async {
      final stdin = StreamController<List<int>>();
      final replies = <Map<String, Object?>>[];
      final bridge = buildForwardingMcpServer(
        socketPath: sock('gone'),
        stdinStream: stdin.stream,
        writeLine: (l) => replies.add((jsonDecode(l) as Map).cast<String, Object?>()),
      );
      final serving = bridge.serve();
      stdin.add(utf8.encode('${jsonEncode({
            'jsonrpc': '2.0',
            'id': 1,
            'method': 'tools/call',
            'params': {
              'name': 'read_aloud',
              'arguments': {'name': 'x', 'paragraphs': ['y']},
            },
          })}\n'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await stdin.close();
      await serving;
      final result = replies.single['result']! as Map;
      expect(result['isError'], isTrue);
      expect(((result['content'] as List).single as Map)['text'], contains('did not respond'));
    });
  });

  group('AppDatabase', () {
    test('insert/update/watch/delete lifecycle', () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      final job = await db.insertJob(name: 'j', paragraphs: ['a'], voice: 'v', speed: 1.5);
      expect(job.status, JobStatus.queued);
      expect(job.voice, 'v');
      expect(job.speed, 1.5);

      expect(await db.pendingJobs(), hasLength(1));
      await db.updateJob(job.id, const JobsCompanion(status: Value(JobStatus.done)));
      expect(await db.pendingJobs(), isEmpty);
      await db.deleteJob(job.id);
      expect(await db.allJobs(), isEmpty);
    });
  });
}
