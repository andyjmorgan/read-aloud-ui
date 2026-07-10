import 'dart:async';

import '../core/jobs/job_worker.dart';
import 'audio_sink.dart';

/// What the engine is currently doing — consumed by the UI player bar.
class PlaybackState {
  const PlaybackState({this.jobId, this.playing = false, this.live = false});

  /// Job currently loaded (null = idle).
  final int? jobId;
  final bool playing;

  /// True when streaming chunks of an in-flight job (vs a library file).
  final bool live;
}

/// Feeds worker playback signals into the audio sink:
///  - live path: contiguous chunk URLs appended to a gapless playlist
///  - library path: play a downloaded file on demand
/// Only one job plays at a time; live streaming starts only when idle and
/// auto-play is enabled (queried per event so config changes apply instantly).
class PlaybackEngine {
  PlaybackEngine({
    required this.sink,
    required Stream<PlaybackSignal> signals,
    required this.autoPlayEnabled,
  }) {
    _sub = signals.listen(_onSignal);
    _completedSub = sink.completedStream.listen((_) => _onCompleted());
    _playingSub = sink.playingStream.listen((playing) {
      _playing = playing;
      _push();
    });
  }

  final AudioSink sink;
  final Future<bool> Function() autoPlayEnabled;

  final _state = StreamController<PlaybackState>.broadcast();
  Stream<PlaybackState> get state => _state.stream;

  int? _liveJobId;
  int? _currentJobId;
  var _playing = false;
  var _liveStreamDone = false;

  late final StreamSubscription<PlaybackSignal> _sub;
  late final StreamSubscription<void> _completedSub;
  late final StreamSubscription<bool> _playingSub;

  Future<void> _onSignal(PlaybackSignal signal) async {
    switch (signal) {
      case ChunkAvailable(:final jobId, :final index, :final url, :final headers):
        if (_liveJobId == null && _currentJobId == null && index == 0) {
          if (!await autoPlayEnabled()) return;
          _liveJobId = jobId;
          _currentJobId = jobId;
          _liveStreamDone = false;
          await sink.open(url, headers: headers);
          await sink.play();
          _push();
        } else if (jobId == _liveJobId) {
          await sink.append(url, headers: headers);
        }
      case FinalFileReady(:final jobId, :final path, :final playedLive):
        if (jobId == _liveJobId) {
          // chunks already streaming — let them finish; remember stream is complete
          _liveStreamDone = true;
        } else if (!playedLive && _currentJobId == null && await autoPlayEnabled()) {
          _currentJobId = jobId;
          await sink.open(path);
          await sink.play();
          _push();
        }
      case JobFailed(:final jobId):
        if (jobId == _liveJobId) {
          // stop at the last good chunk once the queue drains
          _liveStreamDone = true;
        }
    }
  }

  /// Manual play of a library file (history row tap).
  Future<void> playFile(int jobId, String path) async {
    _liveJobId = null;
    _currentJobId = jobId;
    _liveStreamDone = false;
    await sink.open(path);
    await sink.play();
    _push();
  }

  Future<void> pause() => sink.pause();
  Future<void> resume() => sink.play();

  Future<void> stopPlayback() async {
    await sink.stop();
    _liveJobId = null;
    _currentJobId = null;
    _push();
  }

  Future<void> setDevice(String deviceId) => sink.setDevice(deviceId);
  Future<List<OutputDevice>> listDevices() => sink.listDevices();

  void _onCompleted() {
    // Playlist exhausted. For a live job that is still generating, media_kit
    // just waits for the next append; completion only ends the session when
    // the stream has finished (or a library file ended).
    if (_liveJobId != null && !_liveStreamDone) return;
    _liveJobId = null;
    _currentJobId = null;
    _push();
  }

  void _push() {
    if (_state.isClosed) return;
    _state.add(PlaybackState(
      jobId: _currentJobId,
      playing: _playing,
      live: _liveJobId != null,
    ));
  }

  Future<void> dispose() async {
    await _sub.cancel();
    await _completedSub.cancel();
    await _playingSub.cancel();
    await _state.close();
    await sink.dispose();
  }
}
