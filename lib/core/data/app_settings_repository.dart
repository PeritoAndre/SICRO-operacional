import 'package:flutter/foundation.dart';

import '../../domain/models/app_settings.dart';
import 'app_settings_storage.dart';

class AppSettingsRepository extends ChangeNotifier {
  AppSettingsRepository({AppSettingsStorage? storage})
    : _storage = storage ?? MemoryAppSettingsStorage();

  final AppSettingsStorage _storage;
  AppSettings _settings = const AppSettings();
  bool _loaded = false;
  String? _lastError;

  bool get loaded => _loaded;

  String? get lastError => _lastError;

  AppSettings get settings => _settings;

  Future<void> load() async {
    if (_loaded) {
      return;
    }
    try {
      final loadedSettings = await _storage.loadSettings();
      _settings = _migrateSettings(loadedSettings);
      if (!_sameAreas(loadedSettings.activeAreas, _settings.activeAreas)) {
        await _storage.saveSettings(_settings);
      }
      _lastError = null;
    } catch (error) {
      _settings = const AppSettings();
      _lastError = error.toString();
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> completeOnboarding({
    required ExpertProfile profile,
    required List<ForensicArea> activeAreas,
  }) async {
    _settings = _settings.copyWith(
      onboardingCompleted: true,
      profile: profile,
      activeAreas: activeAreas,
    );
    notifyListeners();
    await _persist();
  }

  Future<void> skipOnboarding() async {
    _settings = _settings.copyWith(onboardingCompleted: true);
    notifyListeners();
    await _persist();
  }

  Future<void> updateProfile(ExpertProfile profile) async {
    _settings = _settings.copyWith(profile: profile);
    notifyListeners();
    await _persist();
  }

  Future<void> updateActiveAreas(List<ForensicArea> activeAreas) async {
    _settings = _settings.copyWith(activeAreas: activeAreas);
    notifyListeners();
    await _persist();
  }

  Future<void> updateBackup(BackupSettings backup) async {
    _settings = _settings.copyWith(backup: backup);
    notifyListeners();
    await _persist();
  }

  Future<void> restoreSettings(AppSettings settings) async {
    _settings = _migrateSettings(settings);
    notifyListeners();
    await _persist();
  }

  Future<void> updateSettings({
    required ExpertProfile profile,
    required List<ForensicArea> activeAreas,
    BackupSettings? backup,
  }) async {
    _settings = _settings.copyWith(
      profile: profile,
      activeAreas: activeAreas,
      backup: backup,
    );
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    try {
      await _storage.saveSettings(_settings);
      _lastError = null;
    } catch (error) {
      _lastError = error.toString();
      notifyListeners();
    }
  }
}

AppSettings _migrateSettings(AppSettings settings) {
  final activeAreas = settings.activeAreas;
  final hasLegacyFullSet =
      activeAreas.contains(ForensicArea.traffic) &&
      activeAreas.contains(ForensicArea.violentDeath) &&
      activeAreas.contains(ForensicArea.property);
  if (hasLegacyFullSet) {
    final migrated = [...activeAreas];
    if (!migrated.contains(ForensicArea.environmental)) {
      migrated.add(ForensicArea.environmental);
    }
    if (!migrated.contains(ForensicArea.ballistics)) {
      migrated.add(ForensicArea.ballistics);
    }
    if (!migrated.contains(ForensicArea.audioImage)) {
      migrated.add(ForensicArea.audioImage);
    }
    if (!migrated.contains(ForensicArea.papiloscopy)) {
      migrated.add(ForensicArea.papiloscopy);
    }
    return settings.copyWith(activeAreas: migrated);
  }
  return settings;
}

bool _sameAreas(List<ForensicArea> left, List<ForensicArea> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}
