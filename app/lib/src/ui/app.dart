import 'dart:async';

import 'package:flutter/material.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:window_manager/window_manager.dart';

import '../core/jobs/job_worker.dart';
import '../core/runtime.dart';
import '../playback/playback_engine.dart';
import 'screens/home_screen.dart';
import 'theme/donkeywork_theme.dart';

class ReadAloudApp extends StatefulWidget {
  const ReadAloudApp({super.key, required this.runtime, required this.engine});

  final AppRuntime runtime;
  final PlaybackEngine engine;

  @override
  State<ReadAloudApp> createState() => _ReadAloudAppState();
}

class _ReadAloudAppState extends State<ReadAloudApp> with WindowListener {
  StreamSubscription<PlaybackSignal>? _notifySub;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _notifySub = widget.runtime.worker.signals.listen(_maybeNotify);
    // A second plain launch (e.g. dock click) asks us to surface the window.
    widget.runtime.onShowRequested = () async {
      await windowManager.show();
      await windowManager.focus();
    };
  }

  Future<void> _maybeNotify(PlaybackSignal signal) async {
    final config = await widget.runtime.configStore.load();
    if (!config.notifyOnReady) return;
    switch (signal) {
      case FinalFileReady(:final jobId):
        // suppress only when the audio really streamed live (worker's
        // playedLive flag counts emitted chunks, not played ones)
        if (widget.engine.didPlayLive(jobId)) return;
        final job = await widget.runtime.db.getJob(jobId);
        LocalNotification(title: 'Recording ready', body: job?.name ?? 'Recording #$jobId').show();
      case JobFailed(:final jobId, :final error):
        final job = await widget.runtime.db.getJob(jobId);
        LocalNotification(title: 'Read-aloud failed: ${job?.name ?? jobId}', body: error).show();
      case ChunkAvailable():
        break;
    }
  }

  @override
  void onWindowClose() async {
    // close-to-background: keep serving MCP/IPC; relaunching re-opens the window
    await windowManager.hide();
  }

  @override
  void dispose() {
    _notifySub?.cancel();
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Read Aloud',
      debugShowCheckedModeBanner: false,
      theme: donkeyWorkTheme(Brightness.light),
      darkTheme: donkeyWorkTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: HomeScreen(
        db: widget.runtime.db,
        engine: widget.engine,
        onConfigChanged: () async {
          final config = await widget.runtime.configStore.load();
          await widget.engine.setDevice(config.audioDevice);
        },
      ),
    );
  }
}
