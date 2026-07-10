import 'package:media_kit/media_kit.dart';

/// One output device as exposed by the audio backend.
class OutputDevice {
  const OutputDevice({required this.id, required this.description});

  final String id;
  final String description;

  static const auto = OutputDevice(id: 'auto', description: 'System default');
}

/// Minimal seam over the audio backend so engine logic is unit-testable.
abstract interface class AudioSink {
  Future<void> open(String uri, {Map<String, String> headers});
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> setDevice(String deviceId);
  Future<List<OutputDevice>> listDevices();
  Future<void> seek(Duration position);

  /// True while something is actively playing.
  Stream<bool> get playingStream;

  /// Position/duration of the current media item.
  Stream<Duration> get positionStream;
  Stream<Duration> get durationStream;

  /// Fires when the playlist is exhausted.
  Stream<void> get completedStream;

  Future<void> dispose();
}

/// media_kit (libmpv) implementation. Thin by design — logic lives in
/// PlaybackEngine and is tested against a fake sink.
class MediaKitSink implements AudioSink {
  MediaKitSink() : _player = Player();

  final Player _player;

  @override
  Future<void> open(String uri, {Map<String, String> headers = const {}}) =>
      _player.open(Media(uri, httpHeaders: headers));

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setDevice(String deviceId) => _player.setAudioDevice(
        deviceId == 'auto'
            ? AudioDevice.auto()
            : AudioDevice(deviceId, ''),
      );

  @override
  Future<List<OutputDevice>> listDevices() async {
    final devices = _player.state.audioDevices;
    return [
      OutputDevice.auto,
      ...devices
          .where((d) => d.name != 'auto')
          .map((d) => OutputDevice(id: d.name, description: d.description.isEmpty ? d.name : d.description)),
    ];
  }

  @override
  Stream<bool> get playingStream => _player.stream.playing;

  // Seed with current state: subscribers often attach after mpv has already
  // emitted the media's duration (broadcast streams do not replay).
  @override
  Stream<Duration> get positionStream async* {
    yield _player.state.position;
    yield* _player.stream.position;
  }

  @override
  Stream<Duration> get durationStream async* {
    yield _player.state.duration;
    yield* _player.stream.duration;
  }

  @override
  Stream<void> get completedStream =>
      _player.stream.completed.where((c) => c).map((_) {});

  @override
  Future<void> dispose() => _player.dispose();
}
