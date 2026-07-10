import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// In-process fake of the DonkeyWork-Recordings REST + SSE surface.
///
/// Scriptable per test: seed collections, control chunk/progress/terminal
/// events on the SSE stream, toggle SSE availability to exercise the poll
/// fallback, and record every request for assertions.
class FakeRecordingsServer {
  FakeRecordingsServer._(this._server);

  final HttpServer _server;
  String get baseUrl => 'http://127.0.0.1:${_server.port}';

  static const validKey = 'test-key';

  final collections = <Map<String, Object?>>[];
  final recordings = <String, FakeRecording>{};
  final requests = <String>[];

  /// When false the SSE endpoint returns 404 (client must fall back to polls).
  bool sseEnabled = true;

  /// When >0 the SSE stream is severed after N events (tests reconnect/poll).
  int cutSseAfterEvents = 0;

  var _idCounter = 0;

  static Future<FakeRecordingsServer> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final fake = FakeRecordingsServer._(server);
    server.listen(fake._handle);
    return fake;
  }

  Future<void> close() => _server.close(force: true);

  FakeRecording addRecording({String? id}) {
    final rid = id ?? 'rec-${++_idCounter}';
    return recordings[rid] = FakeRecording(rid);
  }

  Future<void> _handle(HttpRequest req) async {
    final path = req.uri.path;
    requests.add('${req.method} $path');

    if (req.headers.value('X-Api-Key') != validKey && !path.startsWith('/media/')) {
      req.response.statusCode = 401;
      await req.response.close();
      return;
    }

    try {
      if (req.method == 'GET' && path == '/api/v1/collections') {
        _json(req, collections);
      } else if (req.method == 'POST' && path == '/api/v1/collections') {
        final body = await _body(req);
        final collection = {'id': 'col-${++_idCounter}', 'name': body['name']};
        collections.add(collection);
        _json(req, collection);
      } else if (req.method == 'POST' && path == '/api/v1/recordings/generate') {
        final body = await _body(req);
        final rec = addRecording();
        rec.createBody = body;
        _json(req, rec.toJson());
      } else if (req.method == 'GET' && RegExp(r'^/api/v1/recordings/[^/]+/events$').hasMatch(path)) {
        await _serveSse(req, path.split('/')[4]);
      } else if (req.method == 'GET' && RegExp(r'^/api/v1/recordings/[^/]+$').hasMatch(path)) {
        final rec = recordings[path.split('/').last];
        if (rec == null) {
          req.response.statusCode = 404;
        } else {
          _json(req, rec.toJson());
          rec.polls++;
          return;
        }
        await req.response.close();
      } else if (req.method == 'DELETE' && RegExp(r'^/api/v1/recordings/[^/]+$').hasMatch(path)) {
        final removed = recordings.remove(path.split('/').last);
        req.response.statusCode = removed == null ? 404 : 204;
        await req.response.close();
      } else if (req.method == 'GET' && path.startsWith('/media/')) {
        // chunk wavs / final mp3s: return deterministic bytes
        req.response.headers.contentType = ContentType('audio', path.endsWith('.mp3') ? 'mpeg' : 'wav');
        req.response.add(utf8.encode('AUDIO:$path'));
        await req.response.close();
      } else {
        req.response.statusCode = 404;
        await req.response.close();
      }
    } on Exception {
      try {
        req.response.statusCode = 500;
        await req.response.close();
      } on Exception {
        // socket already gone
      }
    }
  }

  Future<void> _serveSse(HttpRequest req, String recordingId) async {
    if (!sseEnabled) {
      req.response.statusCode = 404;
      await req.response.close();
      return;
    }
    final rec = recordings[recordingId];
    if (rec == null) {
      req.response.statusCode = 404;
      await req.response.close();
      return;
    }
    req.response.headers.contentType = ContentType('text', 'event-stream');
    req.response.bufferOutput = false;

    // Contract: replay current state on connect, then stream live events.
    for (final c in rec.chunks) {
      req.response.write('event: chunk-ready\ndata: ${jsonEncode({
            'index': c['index'],
            'url': c['url'],
            'playableUpTo': rec.playableUpTo,
          })}\n\n');
    }
    if (rec.status == 'Ready') {
      req.response.write('event: ready\ndata: ${jsonEncode({'url': rec.filePath})}\n\n');
      await req.response.close();
      return;
    }
    if (rec.status == 'Failed') {
      req.response.write('event: failed\ndata: ${jsonEncode({'error': rec.errorMessage})}\n\n');
      await req.response.close();
      return;
    }
    await req.response.flush();

    var sent = 0;
    await for (final e in rec.events.stream) {
      req.response.write('event: ${e.$1}\ndata: ${jsonEncode(e.$2)}\n\n');
      await req.response.flush();
      sent++;
      if (cutSseAfterEvents > 0 && sent >= cutSseAfterEvents) break;
      if (e.$1 == 'ready' || e.$1 == 'failed') break;
    }
    await req.response.close();
  }

  void _json(HttpRequest req, Object payload) {
    req.response.headers.contentType = ContentType.json;
    req.response.write(jsonEncode(payload));
    req.response.close();
  }

  Future<Map<String, Object?>> _body(HttpRequest req) async =>
      (jsonDecode(await utf8.decoder.bind(req).join()) as Map).cast<String, Object?>();
}

class FakeRecording {
  FakeRecording(this.id);

  final String id;
  Map<String, Object?>? createBody;
  String status = 'Pending';
  double progress = 0;
  String? statusDetail;
  String? filePath;
  String? errorMessage;
  final chunks = <Map<String, Object?>>[];
  int playableUpTo = -1;
  int polls = 0;

  /// Live SSE feed; tests push (eventName, payload) tuples.
  final events = StreamController<(String, Map<String, Object?>)>.broadcast();

  void emitChunk(int index, String url, int newPlayableUpTo) {
    chunks.add({'index': index, 'url': url});
    playableUpTo = newPlayableUpTo;
    events.add(('chunk-ready', {'index': index, 'url': url, 'playableUpTo': newPlayableUpTo}));
  }

  void emitProgress(double p, String detail) {
    progress = p;
    statusDetail = detail;
    status = 'Generating';
    events.add(('progress', {'progress': p, 'statusDetail': detail}));
  }

  void emitReady(String url) {
    status = 'Ready';
    filePath = url;
    progress = 1;
    events.add(('ready', {'url': url}));
  }

  void emitFailed(String error) {
    status = 'Failed';
    errorMessage = error;
    events.add(('failed', {'error': error}));
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'status': status,
        'progress': progress,
        'statusDetail': statusDetail,
        'filePath': filePath,
        'errorMessage': errorMessage,
        'chunks': chunks,
        'playableUpTo': playableUpTo,
      };
}
