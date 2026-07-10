import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:read_aloud_ui/src/core/api/models.dart';
import 'package:read_aloud_ui/src/core/api/recordings_client.dart';

import '../support/fake_server.dart';

void main() {
  late FakeRecordingsServer server;
  late RecordingsClient client;

  setUp(() async {
    server = await FakeRecordingsServer.start();
    client = RecordingsClient(baseUrl: server.baseUrl, apiKey: FakeRecordingsServer.validKey);
  });

  tearDown(() async {
    client.close();
    await server.close();
  });

  test('ensureCollection creates then reuses', () async {
    final id1 = await client.ensureCollection('_read-aloud');
    final id2 = await client.ensureCollection('_read-aloud');
    expect(id1, id2);
    expect(server.collections, hasLength(1));
  });

  test('createRecording posts paragraphs, voice and speed', () async {
    final col = await client.ensureCollection('c');
    final rec = await client.createRecording(
      collectionId: col,
      name: 'n',
      paragraphs: ['a', 'b'],
      voice: 'af_bella',
    );
    expect(rec.status, RecordingStatus.pending);
    final created = server.recordings.values.single.createBody!;
    expect(created['collectionId'], col);
    expect(created['paragraphs'], ['a', 'b']);
    expect(created['voice'], 'af_bella');
  });

  test('getRecording maps chunks and playableUpTo', () async {
    final rec = server.addRecording();
    rec.emitChunk(0, '${server.baseUrl}/media/c0.wav', 0);
    rec.emitProgress(0.4, 'Generating audio — segment 1 of 2');
    final dto = await client.getRecording(rec.id);
    expect(dto.status, RecordingStatus.generating);
    expect(dto.progress, 0.4);
    expect(dto.statusDetail, contains('segment 1'));
    expect(dto.chunks.single.index, 0);
    expect(dto.playableUpTo, 0);
  });

  test('wrong api key is rejected', () async {
    final bad = RecordingsClient(baseUrl: server.baseUrl, apiKey: 'nope');
    await expectLater(
      bad.ensureCollection('x'),
      throwsA(isA<RecordingsApiException>().having((e) => e.statusCode, 'status', 401)),
    );
    bad.close();
  });

  test('deleteRecording tolerates 404', () async {
    await client.deleteRecording('missing');
  });

  test('openEvents yields typed events and completes on ready', () async {
    final rec = server.addRecording();
    final future = client.openEvents(rec.id).toList();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    rec.emitChunk(1, 'u1', -1); // out of order: 1 before 0
    rec.emitChunk(0, 'u0', 1);
    rec.emitProgress(0.9, 'stitching');
    rec.emitReady('${server.baseUrl}/media/final.mp3');
    final events = await future;
    expect(events.whereType<ChunkReadyEvent>().map((e) => e.index), [1, 0]);
    expect(events.whereType<ChunkReadyEvent>().last.playableUpTo, 1);
    expect(events.whereType<ProgressEvent>().single.statusDetail, 'stitching');
    expect(events.last, isA<ReadyEvent>());
  });

  test('openEvents completes on failed', () async {
    final rec = server.addRecording();
    final future = client.openEvents(rec.id).toList();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    rec.emitFailed('boom');
    final events = await future;
    expect((events.last as FailedEvent).error, 'boom');
  });

  test('downloadToFile writes bytes with auth scoping', () async {
    final tmp = await Directory.systemTemp.createTemp('ra-dl');
    addTearDown(() => tmp.delete(recursive: true));
    final dest = '${tmp.path}/nested/out.mp3';
    await client.downloadToFile('${server.baseUrl}/media/final.mp3', dest);
    expect(await File(dest).readAsString(), 'AUDIO:/media/final.mp3');
    // same-origin URL gets the key; foreign URL would not
    expect(client.headersFor('${server.baseUrl}/media/x'), containsPair('X-Api-Key', FakeRecordingsServer.validKey));
    expect(client.headersFor('https://elsewhere/media/x'), isEmpty);
  });
}
