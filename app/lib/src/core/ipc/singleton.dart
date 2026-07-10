import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// JSON-lines protocol over a unix domain socket. One request per connection:
///   → {"cmd":"speak","name":...,"paragraphs":[...],"voice":?,"speed":?}
///   ← {"ok":true,"jobId":N} | {"ok":false,"error":"..."}
///   → {"cmd":"ping"}   ← {"ok":true}
class SingletonIpc {
  SingletonIpc({String? socketPath}) : socketPath = socketPath ?? defaultSocketPath();

  final String socketPath;
  ServerSocket? _server;

  static String defaultSocketPath() {
    final runtime = Platform.environment['XDG_RUNTIME_DIR'] ?? Directory.systemTemp.path;
    return '$runtime/read-aloud.sock';
  }

  /// True when another instance is alive on the socket.
  static Future<bool> isInstanceRunning(String socketPath) async {
    final reply = await request(socketPath, {'cmd': 'ping'});
    return reply != null && reply['ok'] == true;
  }

  /// Sends one request and awaits one reply. Returns null when nobody listens.
  static Future<Map<String, Object?>?> request(
    String socketPath,
    Map<String, Object?> message, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    Socket socket;
    try {
      socket = await Socket.connect(
        InternetAddress(socketPath, type: InternetAddressType.unix),
        0,
        timeout: const Duration(seconds: 2),
      );
    } on SocketException {
      return null;
    }
    try {
      socket.add(utf8.encode('${jsonEncode(message)}\n'));
      await socket.flush();
      final line = await socket
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .first
          .timeout(timeout);
      return (jsonDecode(line) as Map).cast<String, Object?>();
    } on Exception {
      return null;
    } finally {
      socket.destroy();
    }
  }

  /// Binds the socket and serves requests via [handler]. Steals a stale socket
  /// file if the previous owner died.
  Future<void> serve(Future<Map<String, Object?>> Function(Map<String, Object?>) handler) async {
    final file = File(socketPath);
    if (await file.exists()) {
      if (await isInstanceRunning(socketPath)) {
        throw StateError('another instance is already serving $socketPath');
      }
      await file.delete();
    }
    _server = await ServerSocket.bind(
      InternetAddress(socketPath, type: InternetAddressType.unix),
      0,
    );
    _server!.listen((socket) {
      socket
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) async {
        Map<String, Object?> reply;
        try {
          final msg = (jsonDecode(line) as Map).cast<String, Object?>();
          reply = await handler(msg);
        } on Exception catch (e) {
          reply = {'ok': false, 'error': e.toString()};
        }
        socket.add(utf8.encode('${jsonEncode(reply)}\n'));
        await socket.flush();
      }, onError: (_) => socket.destroy());
    });
  }

  Future<void> close() async {
    await _server?.close();
    _server = null;
    final file = File(socketPath);
    if (await file.exists()) await file.delete();
  }
}
