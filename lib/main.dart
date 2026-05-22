import 'package:flutter/material.dart';

import 'app/sicro_campo_app.dart';
import 'core/data/app_settings_repository.dart';
import 'core/data/app_settings_storage.dart';
import 'core/data/occurrence_repository.dart';
import 'core/data/occurrence_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = OccurrenceRepository(storage: FileOccurrenceStorage());
  final settingsRepository = AppSettingsRepository(
    storage: FileAppSettingsStorage(),
  );
  await repository.load();
  await settingsRepository.load();
  runApp(
    SicroCampoApp(
      repository: repository,
      settingsRepository: settingsRepository,
    ),
  );
}
