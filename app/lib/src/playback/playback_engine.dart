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

/// Feeds worker playback signals into the audio sink.
///
/// The engine owns the chunk queue: every item is played with an explicit
/// open+play when the previous one completes. This deliberately avoids the
/// backend player's playlist-append semantics, where appending to an
/// already-ended playlist does not resume playback (chunks arrive slower than
/// they play, so the "playlist ended, then a new item arrived" case is the
/// COMMON case, not an edge case).
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

  /// Chunks waiting to be played (live session only).
  final _queue = <(String, Map<String, String>)>[];

  /// True when the sink finished its current item and the queue was empty —
  /// the next arriving chunk must start playback itself.
  var _stalled = false;

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
          _stalled = false;
          _queue.clear();
          await _playItem(url, headers);
        } else if (jobId == _liveJobId) {
          _queue.add((url, headers));
          if (_stalled) {
            _stalled = false;
            final (nextUrl, nextHeaders) = _queue.removeAt(0);
            await _playItem(nextUrl, nextHeaders);
          }
        }
      case FinalFileReady(:final jobId, :final playedLive, :final path):
        if (jobId == _liveJobId) {
          _liveStreamDone = true;
          if (_stalled && _queue.isEmpty) _endSession();
        } else if (!playedLive && _currentJobId == null && await autoPlayEnabled()) {
          _liveJobId = null;
          _currentJobId = jobId;
          _liveStreamDone = false;
          await _playItem(path, const {});
        }
      case JobFailed(:final jobId):
        if (jobId == _liveJobId) {
          _liveStreamDone = true;
          if (_stalled && _queue.isEmpty) _endSession();
        }
    }
  }

  /// Manual play of a library file (history row tap).
  Future<void> playFile(int jobId, String path) async {
    _liveJobId = null;
    _currentJobId = jobId;
    _liveStreamDone = false;
    _stalled = false;
    _queue.clear();
    await _playItem(path, const {});
  }

  Future<void> pause() => sink.pause();
  Future<void> resume() => sink.play();

  Future<void> stopPlayback() async {
    await sink.stop();
    _queue.clear();
    _endSession();
  }

  Future<void> setDevice(String deviceId) => sink.setDevice(deviceId);
  Future<List<OutputDevice>> listDevices() => sink.listDevices();

  /// Position/duration of the current item (per-chunk during live streaming).
  Stream<Duration> get position => sink.positionStream;
  Stream<Duration> get duration => sink.durationStream;

  Future<void> seek(Duration to) async {
    if (_currentJobId != null) await sink.seek(to);
  }

  Future<void> _playItem(String url, Map<String, String> headers) async {
    await sink.open(url, headers: headers);
    await sink.play();
    _push();
  }

  void _onCompleted() {
    if (_liveJobId != null) {
      if (_queue.isNotEmpty) {
        final (url, headers) = _queue.removeAt(0);
        unawaited(_playItem(url, headers));
      } else if (_liveStreamDone) {
        _endSession();
      } else {
        // generation is slower than playback — wait for the next chunk
        _stalled = true;
      }
      return;
    }
    // library file finished
    _endSession();
  }

  void _endSession() {
    _liveJobId = null;
    _currentJobId = null;
    _liveStreamDone = false;
    _stalled = false;
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
