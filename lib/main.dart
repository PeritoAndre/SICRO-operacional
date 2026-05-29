import 'package:flutter/material.dart';

import 'app/sicro_campo_app.dart';
import 'core/data/app_settings_repository.dart';
import 'core/data/app_settings_storage.dart';
import 'core/data/duty_shift_repository.dart';
import 'core/data/duty_shift_storage.dart';
import 'core/data/official_document_repository.dart';
import 'core/data/official_document_storage.dart';
import 'core/data/occurrence_repository.dart';
import 'core/data/occurrence_storage.dart';
import 'core/services/backup_notification_service.dart';
import 'core/services/duty_shift_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = OccurrenceRepository(storage: FileOccurrenceStorage());
  final officialDocumentRepository = OfficialDocumentRepository(
    storage: FileOfficialDocumentStorage(),
  );
  final settingsRepository = AppSettingsRepository(
    storage: FileAppSettingsStorage(),
  );
  final dutyShiftRepository = DutyShiftRepository(
    storage: FileDutyShiftStorage(),
  );
  final dutyShiftNotificationService = DutyShiftNotificationService();
  final backupNotificationService = BackupNotificationService();
  await repository.load();
  await officialDocumentRepository.load();
  await settingsRepository.load();
  await dutyShiftRepository.load();
  await dutyShiftNotificationService.initialize();
  await backupNotificationService.initialize();
  await dutyShiftNotificationService.rescheduleAll(dutyShiftRepository.shifts);
  await backupNotificationService.reschedule(
    settingsRepository.settings.backup,
  );
  runApp(
    SicroCampoApp(
      repository: repository,
      officialDocumentRepository: officialDocumentRepository,
      settingsRepository: settingsRepository,
      dutyShiftRepository: dutyShiftRepository,
      dutyShiftNotificationService: dutyShiftNotificationService,
      backupNotificationService: backupNotificationService,
    ),
  );
}
