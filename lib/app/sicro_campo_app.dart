import 'dart:io';

import 'package:flutter/material.dart';

import '../core/data/app_settings_repository.dart';
import '../core/data/app_backup_restore_service.dart';
import '../core/data/duty_shift_repository.dart';
import '../core/data/official_document_repository.dart';
import '../core/data/occurrence_repository.dart';
import '../core/data/sicroapp_import_service.dart';
import '../core/services/backup_notification_service.dart';
import '../core/services/duty_shift_notification_service.dart';
import '../core/services/external_package_channel.dart';
import '../core/services/operational_session_tracker.dart';
import '../features/backup/backup_restore_review_screen.dart';
import '../features/home/home_screen.dart';
import '../features/imports/sicro_package_received_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import 'app_info.dart';
import 'theme/app_theme.dart';

class SicroCampoApp extends StatelessWidget {
  const SicroCampoApp({
    required this.repository,
    required this.officialDocumentRepository,
    required this.settingsRepository,
    required this.dutyShiftRepository,
    this.dutyShiftNotificationService,
    this.backupNotificationService,
    super.key,
  });

  final OccurrenceRepository repository;
  final OfficialDocumentRepository officialDocumentRepository;
  final AppSettingsRepository settingsRepository;
  final DutyShiftRepository dutyShiftRepository;
  final DutyShiftNotificationService? dutyShiftNotificationService;
  final BackupNotificationService? backupNotificationService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppInfo.name,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: AppEntryScreen(
        repository: repository,
        officialDocumentRepository: officialDocumentRepository,
        settingsRepository: settingsRepository,
        dutyShiftRepository: dutyShiftRepository,
        dutyShiftNotificationService: dutyShiftNotificationService,
        backupNotificationService: backupNotificationService,
      ),
    );
  }
}

class AppEntryScreen extends StatefulWidget {
  const AppEntryScreen({
    required this.repository,
    required this.officialDocumentRepository,
    required this.settingsRepository,
    required this.dutyShiftRepository,
    this.dutyShiftNotificationService,
    this.backupNotificationService,
    super.key,
  });

  final OccurrenceRepository repository;
  final OfficialDocumentRepository officialDocumentRepository;
  final AppSettingsRepository settingsRepository;
  final DutyShiftRepository dutyShiftRepository;
  final DutyShiftNotificationService? dutyShiftNotificationService;
  final BackupNotificationService? backupNotificationService;

  @override
  State<AppEntryScreen> createState() => _AppEntryScreenState();
}

class _AppEntryScreenState extends State<AppEntryScreen> {
  late final OperationalSessionTracker _sessionTracker;
  late final ExternalPackageChannel _packageChannel;
  late final SicroAppImportService _importService;
  late final AppBackupRestoreService _backupRestoreService;
  bool _handlingPackage = false;

  @override
  void initState() {
    super.initState();
    _sessionTracker = OperationalSessionTracker(repository: widget.repository)
      ..start();
    _packageChannel = ExternalPackageChannel()
      ..listen(onPackage: _handleIncomingPackage);
    _importService = SicroAppImportService();
    _backupRestoreService = AppBackupRestoreService();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialPackage();
    });
  }

  @override
  void dispose() {
    _sessionTracker.dispose();
    super.dispose();
  }

  Future<void> _loadInitialPackage() async {
    final package = await _packageChannel.getInitialPackage();
    if (package != null) {
      await _handleIncomingPackage(package);
    }
  }

  Future<void> _handleIncomingPackage(ExternalPackageFile package) async {
    if (_handlingPackage) {
      return;
    }
    _handlingPackage = true;
    try {
      final backupValidation = await _backupRestoreService.validate(
        File(package.filePath),
        fileName: package.originalName.isEmpty
            ? package.fileName
            : package.originalName,
      );
      if (backupValidation.summary?.format == 'sicro_operacional_backup') {
        if (!mounted) {
          return;
        }
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => BackupRestoreReviewScreen(
              validation: backupValidation,
              settingsRepository: widget.settingsRepository,
              occurrenceRepository: widget.repository,
              officialDocumentRepository: widget.officialDocumentRepository,
              dutyShiftRepository: widget.dutyShiftRepository,
              restoreService: _backupRestoreService,
              backupNotificationService: widget.backupNotificationService,
              dutyShiftNotificationService: widget.dutyShiftNotificationService,
            ),
          ),
        );
        return;
      }

      final result = await _importService.validatePackage(package);
      if (!mounted) {
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SicroPackageReceivedScreen(
            result: result,
            repository: widget.repository,
          ),
        ),
      );
    } finally {
      _handlingPackage = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.settingsRepository,
      builder: (context, _) {
        if (!widget.settingsRepository.settings.onboardingCompleted) {
          return OnboardingScreen(
            settingsRepository: widget.settingsRepository,
          );
        }
        return HomeScreen(
          repository: widget.repository,
          officialDocumentRepository: widget.officialDocumentRepository,
          settingsRepository: widget.settingsRepository,
          dutyShiftRepository: widget.dutyShiftRepository,
          dutyShiftNotificationService: widget.dutyShiftNotificationService,
          backupNotificationService: widget.backupNotificationService,
        );
      },
    );
  }
}
