/// Wire models for the DonkeyWork-Recordings REST + SSE surface.
///
/// Contract (fixed, shared with the backend):
///  - SSE events: chunk-ready {index,url,playableUpTo} · progress {progress,statusDetail}
///    · ready {url} · failed {error}
///  - Recording GET carries chunks[] + playableUpTo as the poll fallback.
library;

enum RecordingStatus { pending, generating, ready, failed, unknown }

RecordingStatus recordingStatusFrom(String? raw) {
  switch (raw?.toLowerCase()) {
    case 'pending':
      return RecordingStatus.pending;
    case 'generating':
      return RecordingStatus.generating;
    case 'ready':
      return RecordingStatus.ready;
    case 'failed':
      return RecordingStatus.failed;
    default:
      return RecordingStatus.unknown;
  }
}

class ChunkRef {
  const ChunkRef({required this.index, required this.url});

  factory ChunkRef.fromJson(Map<String, Object?> json) => ChunkRef(
        index: (json['index'] as num).toInt(),
        url: json['url'] as String,
      );

  final int index;
  final String url;
}

class RecordingDto {
  const RecordingDto({
    required this.id,
    required this.status,
    this.progress,
    this.statusDetail,
    this.filePath,
    this.errorMessage,
    this.durationSeconds,
    this.chunks = const [],
    this.playableUpTo = -1,
  });

  factory RecordingDto.fromJson(Map<String, Object?> json) => RecordingDto(
        id: (json['id'] ?? json['recordingId']) as String,
        status: recordingStatusFrom(json['status'] as String?),
        progress: (json['progress'] as num?)?.toDouble(),
        statusDetail: json['statusDetail'] as String?,
        filePath: json['filePath'] as String?,
        errorMessage: json['errorMessage'] as String?,
        durationSeconds: (json['durationSeconds'] as num?)?.toDouble(),
        chunks: ((json['chunks'] as List?) ?? const [])
            .map((c) => ChunkRef.fromJson((c as Map).cast<String, Object?>()))
            .toList(),
        playableUpTo: (json['playableUpTo'] as num?)?.toInt() ?? -1,
      );

  final String id;
  final RecordingStatus status;
  final double? progress;
  final String? statusDetail;
  final String? filePath;
  final String? errorMessage;
  final double? durationSeconds;
  final List<ChunkRef> chunks;
  final int playableUpTo;
}

/// Typed generation events, produced by the SSE consumer or the poll fallback.
sealed class GenerationEvent {
  const GenerationEvent();
}

class ChunkReadyEvent extends GenerationEvent {
  const ChunkReadyEvent({required this.index, required this.url, required this.playableUpTo});

  factory ChunkReadyEvent.fromJson(Map<String, Object?> json) => ChunkReadyEvent(
        index: (json['index'] as num).toInt(),
        url: json['url'] as String,
        playableUpTo: (json['playableUpTo'] as num?)?.toInt() ?? -1,
      );

  final int index;
  final String url;
  final int playableUpTo;
}

class ProgressEvent extends GenerationEvent {
  const ProgressEvent({required this.progress, this.statusDetail});

  factory ProgressEvent.fromJson(Map<String, Object?> json) => ProgressEvent(
        progress: (json['progress'] as num?)?.toDouble() ?? 0,
        statusDetail: json['statusDetail'] as String?,
      );

  final double progress;
  final String? statusDetail;
}

class ReadyEvent extends GenerationEvent {
  const ReadyEvent({required this.url});

  factory ReadyEvent.fromJson(Map<String, Object?> json) =>
      ReadyEvent(url: json['url'] as String);

  final String url;
}

class FailedEvent extends GenerationEvent {
  const FailedEvent({required this.error});

  factory FailedEvent.fromJson(Map<String, Object?> json) =>
      FailedEvent(error: (json['error'] as String?) ?? 'unknown error');

  final String error;
}
