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
      _settings = await _storage.loadSettings();
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

  Future<void> updateSettings({
    required ExpertProfile profile,
    required List<ForensicArea> activeAreas,
  }) async {
    _settings = _settings.copyWith(profile: profile, activeAreas: activeAreas);
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
