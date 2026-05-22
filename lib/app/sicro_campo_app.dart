import 'package:flutter/material.dart';

import '../core/data/app_settings_repository.dart';
import '../core/data/occurrence_repository.dart';
import '../core/services/operational_session_tracker.dart';
import '../features/home/home_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import 'app_info.dart';
import 'theme/app_theme.dart';

class SicroCampoApp extends StatelessWidget {
  const SicroCampoApp({
    required this.repository,
    required this.settingsRepository,
    super.key,
  });

  final OccurrenceRepository repository;
  final AppSettingsRepository settingsRepository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppInfo.name,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: AppEntryScreen(
        repository: repository,
        settingsRepository: settingsRepository,
      ),
    );
  }
}

class AppEntryScreen extends StatefulWidget {
  const AppEntryScreen({
    required this.repository,
    required this.settingsRepository,
    super.key,
  });

  final OccurrenceRepository repository;
  final AppSettingsRepository settingsRepository;

  @override
  State<AppEntryScreen> createState() => _AppEntryScreenState();
}

class _AppEntryScreenState extends State<AppEntryScreen> {
  late final OperationalSessionTracker _sessionTracker;

  @override
  void initState() {
    super.initState();
    _sessionTracker = OperationalSessionTracker(repository: widget.repository)
      ..start();
  }

  @override
  void dispose() {
    _sessionTracker.dispose();
    super.dispose();
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
          settingsRepository: widget.settingsRepository,
        );
      },
    );
  }
}
