import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'models.dart';
import 'sse.dart';

/// Route table for the Recordings REST surface — single place to adjust if the
/// backend contract shifts.
class RecordingsRoutes {
  static const collections = '/api/v1/collections';
  static const generate = '/api/v1/recordings/generate';
  static String recording(String id) => '/api/v1/recordings/$id';
  static String events(String id) => '/api/v1/recordings/$id/events';
}

class RecordingsApiException implements Exception {
  RecordingsApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'RecordingsApiException($statusCode): $message';
}

/// Thin typed client over the DonkeyWork-Recordings REST + SSE API.
class RecordingsClient {
  RecordingsClient({
    required this.baseUrl,
    required this.apiKey,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final String baseUrl;
  final String apiKey;
  final http.Client _http;

  Map<String, String> get _headers => {
        'X-Api-Key': apiKey,
        'Content-Type': 'application/json',
      };

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  /// Adds auth only for same-origin URLs (never leak the key to e.g. presigned S3).
  Map<String, String> headersFor(String url) =>
      url.startsWith(baseUrl) ? {'X-Api-Key': apiKey} : const {};

  Future<String> ensureCollection(String name) async {
    final listRes = await _http.get(_uri(RecordingsRoutes.collections), headers: _headers);
    _throwUnlessOk(listRes, 'list collections');
    final body = jsonDecode(listRes.body);
    final items = (body is List ? body : (body['items'] ?? body['collections'] ?? [])) as List;
    for (final raw in items) {
      final item = (raw as Map).cast<String, Object?>();
      if (item['name'] == name) return item['id'] as String;
    }
    final createRes = await _http.post(
      _uri(RecordingsRoutes.collections),
      headers: _headers,
      body: jsonEncode({'name': name, 'description': 'read-aloud scratch (auto-managed)'}),
    );
    _throwUnlessOk(createRes, 'create collection');
    return ((jsonDecode(createRes.body) as Map).cast<String, Object?>())['id'] as String;
  }

  /// Starts generation. Note: the backend derives pacing from the channel /
  /// voice — there is no per-request speed on this endpoint.
  Future<RecordingDto> createRecording({
    required String collectionId,
    required String name,
    required List<String> paragraphs,
    String? voice,
  }) async {
    final res = await _http.post(
      _uri(RecordingsRoutes.generate),
      headers: _headers,
      body: jsonEncode({
        'collectionId': collectionId,
        'name': name,
        'paragraphs': paragraphs,
        'voice': ?voice,
      }),
    );
    _throwUnlessOk(res, 'create recording');
    return RecordingDto.fromJson((jsonDecode(res.body) as Map).cast<String, Object?>());
  }

  Future<RecordingDto> getRecording(String id) async {
    final res = await _http.get(_uri(RecordingsRoutes.recording(id)), headers: _headers);
    _throwUnlessOk(res, 'get recording');
    return RecordingDto.fromJson((jsonDecode(res.body) as Map).cast<String, Object?>());
  }

  Future<void> deleteRecording(String id) async {
    final res = await _http.delete(_uri(RecordingsRoutes.recording(id)), headers: _headers);
    if (res.statusCode == 404) return; // already gone — fine
    _throwUnlessOk(res, 'delete recording');
  }

  /// Opens the SSE stream and maps wire events to typed [GenerationEvent]s.
  Stream<GenerationEvent> openEvents(String id) async* {
    final req = http.Request('GET', _uri(RecordingsRoutes.events(id)))
      ..headers['X-Api-Key'] = apiKey
      ..headers['Accept'] = 'text/event-stream';
    final res = await _http.send(req);
    if (res.statusCode != 200) {
      throw RecordingsApiException('SSE connect failed', statusCode: res.statusCode);
    }
    await for (final e in parseSseStream(res.stream)) {
      final data = e.data.isEmpty
          ? const <String, Object?>{}
          : (jsonDecode(e.data) as Map).cast<String, Object?>();
      switch (e.event) {
        case 'chunk-ready':
          yield ChunkReadyEvent.fromJson(data);
        case 'progress':
          yield ProgressEvent.fromJson(data);
        case 'ready':
          yield ReadyEvent.fromJson(data);
          return;
        case 'failed':
          yield FailedEvent.fromJson(data);
          return;
        default:
        // unknown event — ignore
      }
    }
  }

  Future<void> downloadToFile(String url, String destinationPath) async {
    final req = http.Request('GET', Uri.parse(url))..headers.addAll(headersFor(url));
    final res = await _http.send(req);
    if (res.statusCode != 200) {
      throw RecordingsApiException('download failed for $url', statusCode: res.statusCode);
    }
    final file = File(destinationPath);
    await file.parent.create(recursive: true);
    final sink = file.openWrite();
    try {
      await res.stream.pipe(sink);
    } finally {
      await sink.close();
    }
  }

  void close() => _http.close();

  void _throwUnlessOk(http.Response res, String what) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw RecordingsApiException('$what: ${res.body}', statusCode: res.statusCode);
    }
  }
}
