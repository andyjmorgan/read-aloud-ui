import 'dart:async';
import 'dart:convert';

/// A single Server-Sent Event.
class SseEvent {
  const SseEvent({this.event = 'message', required this.data, this.id});

  final String event;
  final String data;
  final String? id;
}

/// Transforms a byte stream (an SSE response body) into [SseEvent]s.
///
/// Implements the parts of the SSE wire format we rely on: `event:`/`data:`/`id:`
/// fields, multi-line data joined with '\n', comment lines (`:` heartbeats)
/// ignored, events dispatched on blank lines.
Stream<SseEvent> parseSseStream(Stream<List<int>> byteStream) {
  final controller = StreamController<SseEvent>();
  var eventName = 'message';
  var dataLines = <String>[];
  String? id;

  void dispatch() {
    if (dataLines.isEmpty) {
      eventName = 'message';
      return;
    }
    controller.add(SseEvent(event: eventName, data: dataLines.join('\n'), id: id));
    eventName = 'message';
    dataLines = <String>[];
  }

  final sub = byteStream
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen((line) {
    if (line.isEmpty) {
      dispatch();
    } else if (line.startsWith(':')) {
      // heartbeat / comment — ignore
    } else {
      final colon = line.indexOf(':');
      final field = colon == -1 ? line : line.substring(0, colon);
      var value = colon == -1 ? '' : line.substring(colon + 1);
      if (value.startsWith(' ')) value = value.substring(1);
      switch (field) {
        case 'event':
          eventName = value;
        case 'data':
          dataLines.add(value);
        case 'id':
          id = value;
        default:
        // retry / unknown fields ignored
      }
    }
  }, onError: controller.addError, onDone: () {
    dispatch();
    controller.close();
  });

  controller.onCancel = sub.cancel;
  return controller.stream;
}
