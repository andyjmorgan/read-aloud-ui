import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:read_aloud_ui/src/core/api/sse.dart';

Stream<List<int>> _bytes(String s) => Stream.value(utf8.encode(s));

void main() {
  group('parseSseStream', () {
    test('parses named events with json data', () async {
      final events = await parseSseStream(_bytes(
        'event: chunk-ready\ndata: {"index":0}\n\nevent: ready\ndata: {"url":"x"}\n\n',
      )).toList();
      expect(events, hasLength(2));
      expect(events[0].event, 'chunk-ready');
      expect(events[0].data, '{"index":0}');
      expect(events[1].event, 'ready');
    });

    test('defaults event name to message', () async {
      final events = await parseSseStream(_bytes('data: hello\n\n')).toList();
      expect(events.single.event, 'message');
      expect(events.single.data, 'hello');
    });

    test('joins multi-line data', () async {
      final events = await parseSseStream(_bytes('data: a\ndata: b\n\n')).toList();
      expect(events.single.data, 'a\nb');
    });

    test('ignores heartbeat comments and unknown fields', () async {
      final events = await parseSseStream(_bytes(
        ': keep-alive\nretry: 500\nevent: progress\ndata: {}\n\n',
      )).toList();
      expect(events.single.event, 'progress');
    });

    test('carries the id field', () async {
      final events = await parseSseStream(_bytes('id: 7\ndata: x\n\n')).toList();
      expect(events.single.id, '7');
    });

    test('dispatches trailing event on stream end without blank line', () async {
      final events = await parseSseStream(_bytes('event: ready\ndata: {"url":"u"}\n')).toList();
      expect(events.single.event, 'ready');
    });

    test('handles chunked byte delivery across event boundaries', () async {
      final full = utf8.encode('event: progress\ndata: {"progress":0.5}\n\nevent: ready\ndata: {"url":"u"}\n\n');
      final events = await parseSseStream(
        Stream.fromIterable([full.sublist(0, 13), full.sublist(13, 29), full.sublist(29)]),
      ).toList();
      expect(events, hasLength(2));
      expect(events[0].event, 'progress');
      expect(events[1].event, 'ready');
    });

    test('blank-line runs do not produce empty events', () async {
      final events = await parseSseStream(_bytes('\n\n\ndata: x\n\n\n\n')).toList();
      expect(events, hasLength(1));
    });
  });
}
