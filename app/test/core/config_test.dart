import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:read_aloud_ui/src/core/config.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('ra-config');
  });

  tearDown(() async => tmp.delete(recursive: true));

  ConfigStore store() => ConfigStore(
        configPath: '${tmp.path}/config.json',
        dataDir: '${tmp.path}/data',
      );

  test('load returns defaults when file missing', () async {
    final config = await store().load();
    expect(config.isConfigured, isFalse);
    expect(config.voice, 'af_heart');
    expect(config.speed, 1.0);
    expect(config.autoPlay, isTrue);
    expect(config.scratchChannelName, '_read-aloud');
    expect(config.libraryDir, '${tmp.path}/data/library');
  });

  test('save/load round-trips all fields', () async {
    final s = store();
    final config = AppConfig(
      serverBaseUrl: 'http://server:5000',
      apiKey: 'k',
      voice: 'af_bella',
      speed: 1.3,
      autoPlay: false,
      notifyOnReady: false,
      libraryDir: '/x/lib',
      scratchChannelName: '_scratch',
    );
    await s.save(config);
    final loaded = await s.load();
    expect(loaded.serverBaseUrl, 'http://server:5000');
    expect(loaded.apiKey, 'k');
    expect(loaded.voice, 'af_bella');
    expect(loaded.speed, 1.3);
    expect(loaded.autoPlay, isFalse);
    expect(loaded.notifyOnReady, isFalse);
    expect(loaded.libraryDir, '/x/lib');
    expect(loaded.scratchChannelName, '_scratch');
    expect(loaded.isConfigured, isTrue);
  });

  test('config file is chmod 600 on unix', () async {
    final s = store();
    await s.save(AppConfig(serverBaseUrl: 'u', apiKey: 'k', libraryDir: 'l'));
    if (!Platform.isWindows) {
      final mode = (await Process.run('stat', ['-c', '%a', s.configPath])).stdout.toString().trim();
      expect(mode, '600');
    }
  });

  test('load tolerates partial json', () async {
    final s = store();
    await File(s.configPath).create(recursive: true);
    await File(s.configPath).writeAsString(jsonEncode({'serverBaseUrl': 'http://s'}));
    final config = await s.load();
    expect(config.serverBaseUrl, 'http://s');
    expect(config.apiKey, '');
    expect(config.speed, 1.0);
  });

  test('dbPath lives under dataDir', () {
    expect(store().dbPath, '${tmp.path}/data/read-aloud.db');
  });
}
