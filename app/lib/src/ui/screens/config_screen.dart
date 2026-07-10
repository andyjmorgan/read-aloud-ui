import 'package:flutter/material.dart';

import '../../core/config.dart';
import '../../playback/audio_sink.dart';
import '../../playback/playback_engine.dart';
import '../theme/donkeywork_theme.dart';

class ConfigScreen extends StatefulWidget {
  const ConfigScreen({super.key, required this.engine, required this.onSaved, this.configStore});

  final PlaybackEngine engine;
  final Future<void> Function() onSaved;
  final ConfigStore? configStore;

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  late final ConfigStore _store = widget.configStore ?? ConfigStore();
  final _formKey = GlobalKey<FormState>();

  final _apiKey = TextEditingController();
  final _voice = TextEditingController();
  final _libraryDir = TextEditingController();
  var _speed = 1.0;
  var _autoPlay = true;
  var _notifyOnReady = true;
  var _obscureKey = true;
  var _audioDevice = 'auto';
  var _devices = const <OutputDevice>[OutputDevice.auto];
  AppConfig? _config;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final config = await _store.load();
    final devices = await widget.engine.listDevices();
    if (!mounted) return;
    setState(() {
      _config = config;
      _apiKey.text = config.apiKey;
      _voice.text = config.voice;
      _libraryDir.text = config.libraryDir;
      _speed = config.speed;
      _autoPlay = config.autoPlay;
      _notifyOnReady = config.notifyOnReady;
      _devices = devices;
      _audioDevice = devices.any((d) => d.id == config.audioDevice) ? config.audioDevice : 'auto';
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final config = _config!;
    config
      ..apiKey = _apiKey.text.trim()
      ..voice = _voice.text.trim().isEmpty ? 'af_heart' : _voice.text.trim()
      ..libraryDir = _libraryDir.text.trim()
      ..speed = _speed
      ..autoPlay = _autoPlay
      ..notifyOnReady = _notifyOnReady
      ..audioDevice = _audioDevice;
    await _store.save(config);
    await widget.engine.setDevice(_audioDevice);
    await widget.onSaved();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved')));
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dw = context.dw;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _config == null
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _section(context, 'Server'),
                  TextFormField(
                    controller: _apiKey,
                    obscureText: _obscureKey,
                    decoration: InputDecoration(
                      labelText: 'API key',
                      suffixIcon: IconButton(
                        icon: Icon(_obscureKey ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: dw.textTertiary),
                        onPressed: () => setState(() => _obscureKey = !_obscureKey),
                      ),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'API key is required' : null,
                  ),
                  const SizedBox(height: 28),
                  _section(context, 'Voice'),
                  TextFormField(
                    controller: _voice,
                    decoration: const InputDecoration(labelText: 'Default voice', hintText: 'af_heart'),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text('Speed', style: TextStyle(color: dw.textSecondary)),
                      Expanded(
                        child: Slider(
                          value: _speed,
                          min: 0.5,
                          max: 2.0,
                          divisions: 15,
                          label: _speed.toStringAsFixed(1),
                          onChanged: (v) => setState(() => _speed = v),
                        ),
                      ),
                      Text('${_speed.toStringAsFixed(1)}×', style: TextStyle(color: dw.textPrimary)),
                    ],
                  ),
                  const SizedBox(height: 28),
                  _section(context, 'Playback'),
                  DropdownButtonFormField<String>(
                    initialValue: _audioDevice,
                    decoration: const InputDecoration(labelText: 'Output device'),
                    dropdownColor: dw.bgElevated,
                    items: [
                      for (final d in _devices)
                        DropdownMenuItem(value: d.id, child: Text(d.description, overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (v) => setState(() => _audioDevice = v ?? 'auto'),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Auto-play as audio streams in', style: TextStyle(color: dw.textPrimary, fontSize: 14)),
                    value: _autoPlay,
                    onChanged: (v) => setState(() => _autoPlay = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Notify when a recording is ready', style: TextStyle(color: dw.textPrimary, fontSize: 14)),
                    value: _notifyOnReady,
                    onChanged: (v) => setState(() => _notifyOnReady = v),
                  ),
                  const SizedBox(height: 28),
                  _section(context, 'Library'),
                  TextFormField(
                    controller: _libraryDir,
                    decoration: const InputDecoration(labelText: 'Library folder'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Library folder is required' : null,
                  ),
                  const SizedBox(height: 36),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: DwGradientButton(onPressed: _save, child: const Text('Save settings')),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _section(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          title.toUpperCase(),
          style: TextStyle(
            color: context.dw.textTertiary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
          ),
        ),
      );

  @override
  void dispose() {
    _apiKey.dispose();
    _voice.dispose();
    _libraryDir.dispose();
    super.dispose();
  }
}
