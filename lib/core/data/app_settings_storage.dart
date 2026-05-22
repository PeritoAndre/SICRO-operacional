import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../domain/models/app_settings.dart';

abstract class AppSettingsStorage {
  Future<AppSettings> loadSettings();

  Future<void> saveSettings(AppSettings settings);
}

class MemoryAppSettingsStorage implements AppSettingsStorage {
  MemoryAppSettingsStorage([AppSettings? initial])
    : _settings = initial ?? const AppSettings();

  AppSettings _settings;

  @override
  Future<AppSettings> loadSettings() async {
    return _settings;
  }

  @override
  Future<void> saveSettings(AppSettings settings) async {
    _settings = settings;
  }
}

class FileAppSettingsStorage implements AppSettingsStorage {
  FileAppSettingsStorage({Future<Directory> Function()? directoryProvider})
    : _directoryProvider =
          directoryProvider ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _directoryProvider;

  @override
  Future<AppSettings> loadSettings() async {
    final file = await _storageFile();
    if (!await file.exists()) {
      return const AppSettings();
    }
    final raw = await file.readAsString();
    if (raw.trim().isEmpty) {
      return const AppSettings();
    }
    final decoded = jsonDecode(raw);
    return AppSettings.fromJson(_map(decoded));
  }

  @override
  Future<void> saveSettings(AppSettings settings) async {
    final file = await _storageFile();
    final payload = {
      'formato': 'sicrocampo_settings',
      'versao': '0.1',
      'salvo_em': DateTime.now().toIso8601String(),
      ...settings.toJson(),
    };
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(payload), flush: true);
  }

  Future<File> _storageFile() async {
    final base = await _directoryProvider();
    final dir = Directory('${base.path}${Platform.pathSeparator}sicro_campo');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File('${dir.path}${Platform.pathSeparator}settings.json');
  }
}

Map<String, Object?> _map(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  return const {};
}
