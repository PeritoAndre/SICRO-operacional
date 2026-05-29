import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/data/app_settings_repository.dart';
import '../../core/data/duty_shift_repository.dart';
import '../../core/data/official_document_repository.dart';
import '../../core/data/occurrence_repository.dart';
import '../../core/services/backup_notification_service.dart';
import '../../core/services/duty_shift_notification_service.dart';
import '../../domain/models/duty_shift.dart';
import '../../domain/models/official_document.dart';
import '../../domain/models/occurrence.dart';
import '../../features/backup/backup_screen.dart';
import '../../features/duty_shifts/duty_shifts_screen.dart';
import '../../features/duty_report/duty_report_screen.dart';
import '../../features/official_documents/official_documents_screen.dart';
import '../../features/occurrences/occurrence_delete_flow.dart';
import '../../features/occurrences/occurrence_dashboard_screen.dart';
import '../../features/occurrences/occurrence_list_screen.dart';
import '../../features/occurrences/operational_diary_widgets.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/statistics/statistics_screen.dart';
import '../../features/start/start_expertise_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
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
    return ListenableBuilder(
      listenable: Listenable.merge([
        repository,
        officialDocumentRepository,
        settingsRepository,
        dutyShiftRepository,
      ]),
      builder: (context, _) {
        final occurrences = repository.occurrences;
        final officialDocuments = officialDocumentRepository.documents;
        final dutyShifts = dutyShiftRepository.shifts;
        final groups = groupOccurrencesByMonth(occurrences);

        return Scaffold(
          appBar: AppBar(
            title: const _HomeAppTitle(),
            actions: [
              IconButton(
                tooltip: 'Historico',
                onPressed: () => _openHistory(context),
                icon: const Icon(Icons.auto_stories_outlined),
              ),
              IconButton(
                tooltip: 'Configuracoes',
                onPressed: () => _openSettings(context),
                icon: const Icon(Icons.settings_outlined),
              ),
            ],
          ),
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _HomeHeader(
                    settingsRepository: settingsRepository,
                    occurrences: occurrences,
                    officialDocuments: officialDocuments,
                    dutyShifts: dutyShifts,
                    onStart: () => _startExpertise(context),
                    onDutyReport: () => _openDutyReport(context),
                    onStatistics: () => _openStatistics(context),
                    onOfficialDocuments: () => _openOfficialDocuments(context),
                    onDutyShifts: () => _openDutyShifts(context),
                    onBackup: () => _openBackup(context),
                  ),
                ),
                if (groups.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: OperationalDiaryEmpty(),
                  )
                else ...[
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 20, 16, 0),
                      child: _DiaryTitle(),
                    ),
                  ),
                  for (final group in groups)
                    OperationalDiarySection(
                      group: group,
                      onOpen: (occurrence) =>
                          _openDashboard(context, occurrence.id),
                      onDelete: (occurrence) =>
                          _confirmDeleteOccurrence(context, occurrence),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 28)),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _startExpertise(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StartExpertiseScreen(
          repository: repository,
          settingsRepository: settingsRepository,
        ),
      ),
    );
  }

  void _openHistory(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OccurrenceListScreen(
          repository: repository,
          officialDocumentRepository: officialDocumentRepository,
          settingsRepository: settingsRepository,
        ),
      ),
    );
  }

  void _openDutyReport(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DutyReportScreen(
          repository: repository,
          settingsRepository: settingsRepository,
        ),
      ),
    );
  }

  void _openStatistics(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StatisticsScreen(
          repository: repository,
          settingsRepository: settingsRepository,
        ),
      ),
    );
  }

  void _openOfficialDocuments(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OfficialDocumentsScreen(
          repository: officialDocumentRepository,
          occurrenceRepository: repository,
        ),
      ),
    );
  }

  void _openDutyShifts(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DutyShiftsScreen(
          repository: dutyShiftRepository,
          settingsRepository: settingsRepository,
          notificationService: dutyShiftNotificationService,
        ),
      ),
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          settingsRepository: settingsRepository,
          occurrenceRepository: repository,
          officialDocumentRepository: officialDocumentRepository,
          dutyShiftRepository: dutyShiftRepository,
          backupNotificationService: backupNotificationService,
          dutyShiftNotificationService: dutyShiftNotificationService,
        ),
      ),
    );
  }

  void _openBackup(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BackupScreen(
          settingsRepository: settingsRepository,
          occurrenceRepository: repository,
          officialDocumentRepository: officialDocumentRepository,
          dutyShiftRepository: dutyShiftRepository,
          backupNotificationService: backupNotificationService,
          dutyShiftNotificationService: dutyShiftNotificationService,
        ),
      ),
    );
  }

  void _openDashboard(BuildContext context, String occurrenceId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OccurrenceDashboardScreen(
          repository: repository,
          occurrenceId: occurrenceId,
          officialDocumentRepository: officialDocumentRepository,
        ),
      ),
    );
  }

  Future<void> _confirmDeleteOccurrence(
    BuildContext context,
    FieldOccurrence occurrence,
  ) async {
    await confirmAndDeleteOccurrence(
      context: context,
      repository: repository,
      occurrence: occurrence,
    );
  }
}

class _HomeAppTitle extends StatelessWidget {
  const _HomeAppTitle();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/launcher/app_icon.png',
          width: 34,
          height: 34,
          fit: BoxFit.contain,
        ),
        const SizedBox(width: 10),
        const Flexible(child: Text('SICRO Operacional')),
      ],
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.settingsRepository,
    required this.occurrences,
    required this.officialDocuments,
    required this.dutyShifts,
    required this.onStart,
    required this.onDutyReport,
    required this.onStatistics,
    required this.onOfficialDocuments,
    required this.onDutyShifts,
    required this.onBackup,
  });

  final AppSettingsRepository settingsRepository;
  final List<FieldOccurrence> occurrences;
  final List<OfficialDocument> officialDocuments;
  final List<DutyShift> dutyShifts;
  final VoidCallback onStart;
  final VoidCallback onDutyReport;
  final VoidCallback onStatistics;
  final VoidCallback onOfficialDocuments;
  final VoidCallback onDutyShifts;
  final VoidCallback onBackup;

  @override
  Widget build(BuildContext context) {
    final profile = settingsRepository.settings.profile;
    final expertName = profile.name.trim().isEmpty
        ? 'Perito de plantao'
        : profile.name.trim();
    final unit = profile.unit.trim().isNotEmpty
        ? profile.unit.trim()
        : profile.organization.trim().isNotEmpty
        ? profile.organization.trim()
        : 'SICRO Operacional';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            expertName,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            '${_todayLabel()} - $unit - ${occurrences.length} registro(s)',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onStart,
            icon: const Icon(Icons.add_location_alt_outlined),
            label: const Text('Iniciar pericia'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              textStyle: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 10),
          _SecondaryActions(
            onDutyReport: onDutyReport,
            onStatistics: onStatistics,
            onOfficialDocuments: onOfficialDocuments,
            onDutyShifts: onDutyShifts,
            onBackup: onBackup,
          ),
          _DutyShiftSummaryPanel(shifts: dutyShifts, onOpen: onDutyShifts),
          _OfficialDocumentsDuePanel(documents: officialDocuments),
          _BackupReminderPanel(
            settingsRepository: settingsRepository,
            occurrences: occurrences,
            officialDocuments: officialDocuments,
            dutyShifts: dutyShifts,
            onOpen: onBackup,
          ),
        ],
      ),
    );
  }
}

class _SecondaryActions extends StatelessWidget {
  const _SecondaryActions({
    required this.onDutyReport,
    required this.onStatistics,
    required this.onOfficialDocuments,
    required this.onDutyShifts,
    required this.onBackup,
  });

  final VoidCallback onDutyReport;
  final VoidCallback onStatistics;
  final VoidCallback onOfficialDocuments;
  final VoidCallback onDutyShifts;
  final VoidCallback onBackup;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final reportButton = OutlinedButton.icon(
          onPressed: onDutyReport,
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: const Text('Gerar relatorio de plantao'),
        );
        final statisticsButton = OutlinedButton.icon(
          onPressed: onStatistics,
          icon: const Icon(Icons.analytics_outlined),
          label: const Text('Estatisticas'),
        );
        final documentsButton = OutlinedButton.icon(
          onPressed: onOfficialDocuments,
          icon: const Icon(Icons.mark_email_read_outlined),
          label: const Text('Oficios'),
        );
        final shiftsButton = OutlinedButton.icon(
          onPressed: onDutyShifts,
          icon: const Icon(Icons.event_available_outlined),
          label: const Text('Plantoes'),
        );
        final backupButton = OutlinedButton.icon(
          onPressed: onBackup,
          icon: const Icon(Icons.backup_outlined),
          label: const Text('Backup'),
        );

        if (constraints.maxWidth < 720) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              shiftsButton,
              const SizedBox(height: 8),
              reportButton,
              const SizedBox(height: 8),
              statisticsButton,
              const SizedBox(height: 8),
              documentsButton,
              const SizedBox(height: 8),
              backupButton,
            ],
          );
        }

        return Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            SizedBox(width: 180, child: shiftsButton),
            SizedBox(width: 230, child: reportButton),
            SizedBox(width: 180, child: statisticsButton),
            SizedBox(width: 160, child: documentsButton),
            SizedBox(width: 160, child: backupButton),
          ],
        );
      },
    );
  }
}

class _DutyShiftSummaryPanel extends StatelessWidget {
  const _DutyShiftSummaryPanel({required this.shifts, required this.onOpen});

  final List<DutyShift> shifts;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    DutyShift? current;
    DutyShift? next;
    for (final shift in shifts) {
      final status = shift.statusAt(now);
      if (status == DutyShiftStatus.inProgress) {
        current = shift;
        break;
      }
      if (status == DutyShiftStatus.upcoming) {
        next ??= shift;
      }
    }

    final shift = current ?? next;
    if (shift == null) {
      return const SizedBox.shrink();
    }

    final isCurrent = current != null;
    final color = isCurrent ? AppColors.success : AppColors.gold;
    final title = isCurrent ? 'Plantao em andamento' : 'Proximo plantao';
    final subtitle = isCurrent
        ? '${shift.displayTitle} ate ${_timeLabel(shift.endsAt)}'
        : '${shift.displayTitle} - ${_relativeStartLabel(shift.startsAt, now)}';

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.7)),
          ),
          child: Row(
            children: [
              Icon(
                isCurrent
                    ? Icons.notifications_active_outlined
                    : Icons.event_available_outlined,
                color: color,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfficialDocumentsDuePanel extends StatelessWidget {
  const _OfficialDocumentsDuePanel({required this.documents});

  final List<OfficialDocument> documents;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final limit = today.add(const Duration(days: 7));
    final relevant = documents.where((document) {
      if (document.status == OfficialDocumentStatus.answered ||
          document.status == OfficialDocumentStatus.archived) {
        return false;
      }
      final deadline = document.deadlineAt;
      return deadline != null && !deadline.isAfter(limit);
    }).toList()..sort((a, b) => a.deadlineAt!.compareTo(b.deadlineAt!));

    if (relevant.isEmpty) {
      return const SizedBox.shrink();
    }

    final overdue = relevant
        .where((document) => document.deadlineAt!.isBefore(today))
        .length;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: overdue > 0 ? AppColors.danger : AppColors.gold,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  overdue > 0
                      ? Icons.warning_amber_outlined
                      : Icons.event_available_outlined,
                  color: overdue > 0 ? AppColors.danger : AppColors.gold,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    overdue > 0
                        ? '$overdue oficio(s) vencido(s) ou no limite'
                        : '${relevant.length} oficio(s) vencendo em ate 7 dias',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final document in relevant.take(3))
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${document.displayTitle} - prazo ${_dateLabel(document.deadlineAt!)}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BackupReminderPanel extends StatelessWidget {
  const _BackupReminderPanel({
    required this.settingsRepository,
    required this.occurrences,
    required this.officialDocuments,
    required this.dutyShifts,
    required this.onOpen,
  });

  final AppSettingsRepository settingsRepository;
  final List<FieldOccurrence> occurrences;
  final List<OfficialDocument> officialDocuments;
  final List<DutyShift> dutyShifts;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final backup = settingsRepository.settings.backup;
    final now = DateTime.now();
    if (!backup.isStale(now)) {
      return const SizedBox.shrink();
    }

    final photoCount = occurrences.fold<int>(
      0,
      (total, occurrence) => total + occurrence.photos.length,
    );
    final newItems =
        (occurrences.length - backup.lastBackupOccurrenceCount).clamp(0, 9999) +
        (officialDocuments.length - backup.lastBackupOfficialDocumentCount)
            .clamp(0, 9999) +
        (dutyShifts.length - backup.lastBackupDutyShiftCount).clamp(0, 9999) +
        (photoCount - backup.lastBackupPhotoCount).clamp(0, 9999);
    final title = backup.hasBackup
        ? 'Backup recomendado'
        : 'Proteja seus dados com backup';
    final subtitle = backup.hasBackup
        ? 'Ultimo backup ha ${backup.daysSince(now)} dia(s). $newItems novo(s) item(ns) desde entao.'
        : 'Crie um .sicrobackup completo para guardar ocorrencias, oficios, plantoes e fotos.';

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.gold),
          ),
          child: Row(
            children: [
              const Icon(Icons.backup_outlined, color: AppColors.gold),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiaryTitle extends StatelessWidget {
  const _DiaryTitle();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Diario Operacional',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        const Text(
          'Linha do tempo das pericias registradas neste aparelho.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

String _todayLabel() {
  final now = DateTime.now();
  return 'Plantao atual ${_two(now.day)}/${_two(now.month)}/${now.year}';
}

String _dateLabel(DateTime date) {
  return '${_two(date.day)}/${_two(date.month)}/${date.year}';
}

String _timeLabel(DateTime date) {
  return '${_two(date.hour)}:${_two(date.minute)}';
}

String _relativeStartLabel(DateTime start, DateTime now) {
  final difference = start.difference(now);
  if (difference.inMinutes <= 0) {
    return 'inicia agora';
  }
  if (difference.inHours < 24) {
    return 'em ${difference.inHours}h${_two(difference.inMinutes.remainder(60))}';
  }
  final days = difference.inDays;
  return days == 1
      ? 'amanha ${_timeLabel(start)}'
      : 'em $days dias - ${_dateLabel(start)}';
}

String _two(int value) => value.toString().padLeft(2, '0');
