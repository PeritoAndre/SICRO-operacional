import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/data/app_settings_repository.dart';
import '../../core/data/occurrence_repository.dart';
import '../../domain/models/occurrence.dart';
import '../../features/duty_report/duty_report_screen.dart';
import '../../features/occurrences/occurrence_delete_flow.dart';
import '../../features/occurrences/occurrence_dashboard_screen.dart';
import '../../features/occurrences/occurrence_list_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/statistics/statistics_screen.dart';
import '../../features/start/start_expertise_screen.dart';
import '../../shared/widgets/pilot_notice_card.dart';
import '../../shared/widgets/status_chip.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    required this.repository,
    required this.settingsRepository,
    super.key,
  });

  final OccurrenceRepository repository;
  final AppSettingsRepository settingsRepository;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([repository, settingsRepository]),
      builder: (context, _) {
        final occurrences = repository.occurrences;
        final recent = occurrences.take(3).toList();
        final inProgress = occurrences
            .where(
              (occurrence) => occurrence.status == OccurrenceStatus.inProgress,
            )
            .length;
        final exported = occurrences
            .where(
              (occurrence) => occurrence.status == OccurrenceStatus.exported,
            )
            .length;

        return Scaffold(
          appBar: AppBar(
            title: const Text('SICRO Operacional'),
            actions: [
              IconButton(
                tooltip: 'Configuracoes',
                onPressed: () => _openSettings(context),
                icon: const Icon(Icons.settings_outlined),
              ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                _InstitutionalHeader(settingsRepository: settingsRepository),
                const SizedBox(height: 12),
                const PilotNoticeCard(),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () => _startExpertise(context),
                  icon: const Icon(Icons.add_location_alt_outlined),
                  label: const Text('Iniciar pericia'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    textStyle: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => _openDutyReport(context),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Gerar relatorio de plantao'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => _openStatistics(context),
                  icon: const Icon(Icons.analytics_outlined),
                  label: const Text('Estatisticas'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        icon: Icons.assignment_outlined,
                        title: 'Ocorrencias',
                        value: '${occurrences.length}',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MetricCard(
                        icon: Icons.pending_actions_outlined,
                        title: 'Em campo',
                        value: '$inProgress',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MetricCard(
                        icon: Icons.archive_outlined,
                        title: 'Exportadas',
                        value: '$exported',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _SectionHeader(
                  title: 'Recentes',
                  actionLabel: 'Historico',
                  onAction: () => _openHistory(context),
                ),
                const SizedBox(height: 10),
                if (recent.isEmpty)
                  const _EmptyRecentCard()
                else
                  ...recent.map(
                    (occurrence) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _RecentOccurrenceCard(
                        occurrence: occurrence,
                        onTap: () => _openDashboard(context, occurrence.id),
                        onDelete: () =>
                            _confirmDeleteOccurrence(context, occurrence),
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  onPressed: () => _openHistory(context),
                  icon: const Icon(Icons.history_outlined),
                  label: const Text('Ver historico completo'),
                ),
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

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(settingsRepository: settingsRepository),
      ),
    );
  }

  void _openDashboard(BuildContext context, String occurrenceId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OccurrenceDashboardScreen(
          repository: repository,
          occurrenceId: occurrenceId,
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

class _InstitutionalHeader extends StatelessWidget {
  const _InstitutionalHeader({required this.settingsRepository});

  final AppSettingsRepository settingsRepository;

  @override
  Widget build(BuildContext context) {
    final profile = settingsRepository.settings.profile;
    final expertName = profile.name.trim().isEmpty
        ? 'Pericia de campo'
        : profile.name.trim();
    final organization = profile.organization.trim().isEmpty
        ? 'Coleta pericial offline'
        : profile.organization.trim();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.gold),
                ),
                child: const Icon(Icons.shield_outlined, color: AppColors.gold),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SICRO Operacional',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      organization,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            expertName,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Organize o dossie operacional e gere um pacote para estudo no SICRO desktop.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.gold),
            const SizedBox(height: 10),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        TextButton(onPressed: onAction, child: Text(actionLabel)),
      ],
    );
  }
}

class _EmptyRecentCard extends StatelessWidget {
  const _EmptyRecentCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: const [
            Icon(Icons.assignment_outlined, color: AppColors.gold),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Nenhuma pericia iniciada neste aparelho.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentOccurrenceCard extends StatelessWidget {
  const _RecentOccurrenceCard({
    required this.occurrence,
    required this.onTap,
    required this.onDelete,
  });

  final FieldOccurrence occurrence;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final progress = occurrence.operationalProgress;
    final statusColor = switch (occurrence.status) {
      OccurrenceStatus.inProgress => AppColors.gold,
      OccurrenceStatus.completed => AppColors.success,
      OccurrenceStatus.exported => AppColors.active,
      OccurrenceStatus.pendingReview => AppColors.gold,
      OccurrenceStatus.incomplete => AppColors.danger,
      OccurrenceStatus.archived => AppColors.textSecondary,
    };

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      occurrence.caseData.displayTitle,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  StatusChip(
                    label: occurrence.status.label,
                    color: statusColor,
                  ),
                  const SizedBox(width: 2),
                  PopupMenuButton<_RecentOccurrenceAction>(
                    tooltip: 'Opcoes da ocorrencia',
                    icon: const Icon(Icons.more_vert),
                    onSelected: (action) {
                      switch (action) {
                        case _RecentOccurrenceAction.delete:
                          onDelete();
                      }
                    },
                    itemBuilder: (context) {
                      return const [
                        PopupMenuItem(
                          value: _RecentOccurrenceAction.delete,
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline,
                                color: AppColors.danger,
                              ),
                              SizedBox(width: 10),
                              Text('Excluir'),
                            ],
                          ),
                        ),
                      ];
                    },
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                occurrence.metadata.summary,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: progress.percent / 100,
                minHeight: 6,
                borderRadius: BorderRadius.circular(8),
              ),
              const SizedBox(height: 8),
              Text(
                '${progress.percent}% operacional - ${occurrence.caseData.displayLocation}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _RecentOccurrenceAction { delete }
