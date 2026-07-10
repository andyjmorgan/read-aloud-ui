import 'dart:async';
import 'dart:convert';

/// Minimal MCP (Model Context Protocol) server over stdio: JSON-RPC 2.0,
/// newline-delimited. Implements initialize / tools/list / tools/call with a
/// single `read_aloud` tool. Transport streams are injected for testability.
class McpServer {
  McpServer({
    required Stream<List<int>> stdinStream,
    required this.writeLine,
    required this.onReadAloud,
  }) : _stdin = stdinStream;

  static const protocolVersion = '2025-06-18';
  static const serverName = 'read-aloud-ui';
  static const serverVersion = '1.0.0';

  final Stream<List<int>> _stdin;
  final void Function(String line) writeLine;
  final Future<Map<String, Object?>> Function(Map<String, Object?> args) onReadAloud;

  static const toolDefinition = {
    'name': 'read_aloud',
    'description': 'Synthesize the given paragraphs to speech and play/store them locally. '
        'Returns immediately with a job id; audio starts playing as chunks render.',
    'inputSchema': {
      'type': 'object',
      'properties': {
        'name': {'type': 'string', 'description': 'Short recording name'},
        'paragraphs': {
          'type': 'array',
          'items': {'type': 'string'},
          'description': 'Ordered short paragraphs to speak',
        },
        'voice': {'type': 'string', 'description': 'Optional Kokoro voice id (default from config)'},
        'speed': {'type': 'number', 'description': 'Optional speech speed (~0.5-2.0)'},
      },
      'required': ['name', 'paragraphs'],
    },
  };

  /// Serves until stdin closes.
  Future<void> serve() async {
    await for (final line in _stdin
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      if (line.trim().isEmpty) continue;
      Object? id;
      try {
        final msg = (jsonDecode(line) as Map).cast<String, Object?>();
        id = msg['id'];
        final method = msg['method'] as String?;
        if (method == null) continue; // response — not expected, ignore
        final params = ((msg['params'] as Map?) ?? {}).cast<String, Object?>();
        final isNotification = !msg.containsKey('id');
        final result = await _dispatch(method, params);
        if (!isNotification) {
          if (result == null) {
            _reply(id, error: {'code': -32601, 'message': 'method not found: $method'});
          } else {
            _reply(id, result: result);
          }
        }
      } on FormatException {
        _reply(null, error: {'code': -32700, 'message': 'parse error'});
      } on Exception catch (e) {
        _reply(id, error: {'code': -32603, 'message': e.toString()});
      }
    }
  }

  Future<Map<String, Object?>?> _dispatch(String method, Map<String, Object?> params) async {
    switch (method) {
      case 'initialize':
        return {
          'protocolVersion':
              (params['protocolVersion'] as String?) ?? protocolVersion,
          'capabilities': {
            'tools': <String, Object?>{},
          },
          'serverInfo': {'name': serverName, 'version': serverVersion},
        };
      case 'notifications/initialized':
      case 'initialized':
        return {};
      case 'ping':
        return {};
      case 'tools/list':
        return {
          'tools': [toolDefinition],
        };
      case 'tools/call':
        final name = params['name'] as String?;
        if (name != 'read_aloud') {
          return {
            'content': [
              {'type': 'text', 'text': 'unknown tool: $name'},
            ],
            'isError': true,
          };
        }
        final args = ((params['arguments'] as Map?) ?? {}).cast<String, Object?>();
        final validationError = _validate(args);
        if (validationError != null) {
          return {
            'content': [
              {'type': 'text', 'text': validationError},
            ],
            'isError': true,
          };
        }
        final outcome = await onReadAloud(args);
        return {
          'content': [
            {'type': 'text', 'text': jsonEncode(outcome)},
          ],
          'isError': outcome['ok'] != true,
        };
      default:
        return null;
    }
  }

  String? _validate(Map<String, Object?> args) {
    if (args['name'] is! String || (args['name'] as String).trim().isEmpty) {
      return 'name is required and must be a non-empty string';
    }
    final paragraphs = args['paragraphs'];
    if (paragraphs is! List || paragraphs.isEmpty || paragraphs.any((p) => p is! String || p.trim().isEmpty)) {
      return 'paragraphs is required and must be a non-empty array of non-empty strings';
    }
    return null;
  }

  void _reply(Object? id, {Map<String, Object?>? result, Map<String, Object?>? error}) {
    writeLine(jsonEncode({
      'jsonrpc': '2.0',
      'id': id,
      'result': ?result,
      'error': ?error,
    }));
  }
}
