import 'dart:convert';
import 'dart:io';

/// Application configuration, persisted as JSON (0600) in the XDG config dir.
class AppConfig {
  AppConfig({
    required this.serverBaseUrl,
    required this.apiKey,
    this.voice = 'af_heart',
    this.speed = 1.0,
    this.autoPlay = true,
    this.notifyOnReady = true,
    required this.libraryDir,
    this.scratchChannelName = '_read-aloud',
  });

  factory AppConfig.fromJson(Map<String, Object?> json, {required String defaultLibraryDir}) {
    return AppConfig(
      serverBaseUrl: (json['serverBaseUrl'] as String?) ?? '',
      apiKey: (json['apiKey'] as String?) ?? '',
      voice: (json['voice'] as String?) ?? 'af_heart',
      speed: (json['speed'] as num?)?.toDouble() ?? 1.0,
      autoPlay: (json['autoPlay'] as bool?) ?? true,
      notifyOnReady: (json['notifyOnReady'] as bool?) ?? true,
      libraryDir: (json['libraryDir'] as String?) ?? defaultLibraryDir,
      scratchChannelName: (json['scratchChannelName'] as String?) ?? '_read-aloud',
    );
  }

  String serverBaseUrl;
  String apiKey;
  String voice;
  double speed;
  bool autoPlay;
  bool notifyOnReady;
  String libraryDir;
  String scratchChannelName;

  bool get isConfigured => serverBaseUrl.isNotEmpty && apiKey.isNotEmpty;

  Map<String, Object?> toJson() => {
        'serverBaseUrl': serverBaseUrl,
        'apiKey': apiKey,
        'voice': voice,
        'speed': speed,
        'autoPlay': autoPlay,
        'notifyOnReady': notifyOnReady,
        'libraryDir': libraryDir,
        'scratchChannelName': scratchChannelName,
      };
}

/// Loads/saves [AppConfig]. Paths are injectable for tests.
class ConfigStore {
  ConfigStore({String? configPath, String? dataDir})
      : configPath = configPath ?? _defaultConfigPath(),
        dataDir = dataDir ?? _defaultDataDir();

  final String configPath;
  final String dataDir;

  static String _homeDir() =>
      Platform.environment['HOME'] ?? Directory.systemTemp.path;

  static String _defaultConfigPath() {
    final base = Platform.environment['XDG_CONFIG_HOME'] ?? '${_homeDir()}/.config';
    return '$base/read-aloud/config.json';
  }

  static String _defaultDataDir() {
    final base = Platform.environment['XDG_DATA_HOME'] ?? '${_homeDir()}/.local/share';
    return '$base/read-aloud';
  }

  String get defaultLibraryDir => '$dataDir/library';
  String get dbPath => '$dataDir/read-aloud.db';

  Future<AppConfig> load() async {
    final file = File(configPath);
    if (!await file.exists()) {
      return AppConfig(serverBaseUrl: '', apiKey: '', libraryDir: defaultLibraryDir);
    }
    final raw = jsonDecode(await file.readAsString()) as Map<String, Object?>;
    return AppConfig.fromJson(raw, defaultLibraryDir: defaultLibraryDir);
  }

  Future<void> save(AppConfig config) async {
    final file = File(configPath);
    await file.parent.create(recursive: true);
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(config.toJson()));
    if (!Platform.isWindows) {
      await Process.run('chmod', ['600', configPath]);
    }
  }
}
