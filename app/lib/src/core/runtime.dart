import 'dart:async';
import 'dart:io';

import 'config.dart';
import 'db/database.dart';
import 'ipc/singleton.dart';
import 'jobs/job_worker.dart';
import 'mcp/mcp_server.dart';

/// Headless core of the application: database, job worker and the IPC
/// singleton endpoint. The UI layer (and the MCP/CLI entrypoints) sit on top.
class AppRuntime {
  AppRuntime({
    required this.db,
    required this.configStore,
    JobWorker? worker,
    SingletonIpc? ipc,
  })  : worker = worker ?? JobWorker(db: db, configStore: configStore),
        ipc = ipc ?? SingletonIpc();

  final AppDatabase db;
  final ConfigStore configStore;
  final JobWorker worker;
  final SingletonIpc ipc;

  /// Set by the UI layer: invoked when a second launch asks us to surface.
  Future<void> Function()? onShowRequested;

  Future<void>? _workerRun;

  /// Binds the IPC socket and starts the worker loop.
  Future<void> start() async {
    await _sweepChunkCache();
    await ipc.serve(handleIpcRequest);
    _workerRun = worker.run();
  }

  /// Chunk WAVs cached during live playback are session-scoped; clear them at
  /// startup (nothing can be playing yet, so this is the one safe moment).
  Future<void> _sweepChunkCache() async {
    final cache = Directory('${configStore.dataDir}/cache');
    try {
      if (await cache.exists()) await cache.delete(recursive: true);
    } on FileSystemException {
      // best-effort
    }
  }

  Future<void> stop() async {
    worker.stop();
    await ipc.close();
    await _workerRun;
    await db.close();
  }

  /// Handles a request arriving over the IPC socket (from a second instance,
  /// the CLI, or an MCP bridge process).
  Future<Map<String, Object?>> handleIpcRequest(Map<String, Object?> msg) async {
    switch (msg['cmd']) {
      case 'ping':
        return {'ok': true, 'pid': pid};
      case 'show':
        await onShowRequested?.call();
        return {'ok': true};
      case 'speak':
        return handleSpeak(msg);
      case 'list':
        final jobs = await db.allJobs();
        return {
          'ok': true,
          'jobs': [
            for (final j in jobs.take(20))
              {
                'id': j.id,
                'name': j.name,
                'status': j.status.name,
                'progress': j.progress,
                'error': j.error,
                'filePath': j.filePath,
              },
          ],
        };
      default:
        return {'ok': false, 'error': 'unknown cmd: ${msg['cmd']}'};
    }
  }

  /// Shared implementation behind MCP tools/call and IPC speak.
  Future<Map<String, Object?>> handleSpeak(Map<String, Object?> args) async {
    final name = args['name'] as String?;
    final paragraphs = (args['paragraphs'] as List?)?.cast<String>();
    if (name == null || name.trim().isEmpty || paragraphs == null || paragraphs.isEmpty) {
      return {'ok': false, 'error': 'name and non-empty paragraphs are required'};
    }
    final jobId = await worker.enqueue(
      name: name.trim(),
      paragraphs: paragraphs,
      voice: args['voice'] as String?,
      speed: (args['speed'] as num?)?.toDouble(),
    );
    return {'ok': true, 'jobId': jobId, 'status': 'queued'};
  }

  /// Builds an MCP server bound to this runtime (primary-instance mode).
  McpServer buildMcpServer({
    required Stream<List<int>> stdinStream,
    required void Function(String) writeLine,
  }) {
    return McpServer(
      stdinStream: stdinStream,
      writeLine: writeLine,
      onReadAloud: handleSpeak,
    );
  }
}

/// MCP bridge for a secondary invocation: forwards read_aloud calls to the
/// primary instance over the IPC socket and serves MCP on this process' stdio.
McpServer buildForwardingMcpServer({
  required String socketPath,
  required Stream<List<int>> stdinStream,
  required void Function(String) writeLine,
}) {
  return McpServer(
    stdinStream: stdinStream,
    writeLine: writeLine,
    onReadAloud: (args) async {
      final reply = await SingletonIpc.request(socketPath, {'cmd': 'speak', ...args});
      return reply ?? {'ok': false, 'error': 'primary instance did not respond'};
    },
  );
}
