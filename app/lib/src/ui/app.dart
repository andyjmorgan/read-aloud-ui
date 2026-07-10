import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:tray_manager/tray_manager.dart';
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

class _ReadAloudAppState extends State<ReadAloudApp> with TrayListener, WindowListener {
  StreamSubscription<PlaybackSignal>? _notifySub;

  @override
  void initState() {
    super.initState();
    trayManager.addListener(this);
    windowManager.addListener(this);
    _initTray();
    _notifySub = widget.runtime.worker.signals.listen(_maybeNotify);
  }

  Future<void> _initTray() async {
    try {
      await trayManager.setIcon(
        Platform.isWindows ? 'assets/tray/tray_icon.ico' : 'assets/tray/tray_icon.png',
      );
      await trayManager.setToolTip('Read Aloud');
      await trayManager.setContextMenu(Menu(items: [
        MenuItem(key: 'show', label: 'Show window'),
        MenuItem(key: 'pause', label: 'Pause playback'),
        MenuItem.separator(),
        MenuItem(key: 'quit', label: 'Quit'),
      ]));
    } on Exception {
      // tray is best-effort (e.g. no appindicator on some DEs)
    }
  }

  Future<void> _maybeNotify(PlaybackSignal signal) async {
    final config = await widget.runtime.configStore.load();
    if (!config.notifyOnReady) return;
    switch (signal) {
      case FinalFileReady(:final jobId, :final playedLive):
        if (playedLive) return; // already heard it live
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
  void onTrayIconMouseDown() => windowManager.show();

  @override
  void onTrayMenuItemClick(MenuItem item) {
    switch (item.key) {
      case 'show':
        windowManager.show();
      case 'pause':
        widget.engine.pause();
      case 'quit':
        _quit();
    }
  }

  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();

  @override
  void onWindowClose() async {
    // close-to-tray: keep serving MCP/IPC in the background
    await windowManager.hide();
  }

  Future<void> _quit() async {
    await widget.engine.dispose();
    await widget.runtime.stop();
    await trayManager.destroy();
    await windowManager.destroy();
  }

  @override
  void dispose() {
    _notifySub?.cancel();
    trayManager.removeListener(this);
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
