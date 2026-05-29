import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/data/occurrence_repository.dart';
import '../../domain/models/occurrence.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/status_chip.dart';

class OccurrenceClosureScreen extends StatelessWidget {
  const OccurrenceClosureScreen({
    required this.repository,
    required this.occurrenceId,
    super.key,
  });

  final OccurrenceRepository repository;
  final String occurrenceId;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: repository,
      builder: (context, _) {
        final occurrence = repository.findById(occurrenceId);
        if (occurrence == null) {
          return const Scaffold(
            body: EmptyState(
              icon: Icons.error_outline,
              title: 'Ocorrencia nao encontrada',
              message: 'Nao foi possivel abrir o encerramento operacional.',
            ),
          );
        }

        final stats = occurrence.stats;
        final warnings = occurrence.closureWarnings;
        return Scaffold(
          appBar: AppBar(title: const Text('Encerramento operacional')),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
              children: [
                _ClosureHeader(occurrence: occurrence),
                const SizedBox(height: 12),
                _ClosureStatsPanel(stats: stats, occurrence: occurrence),
                const SizedBox(height: 12),
                _ClosureWarningsPanel(warnings: warnings),
                const SizedBox(height: 12),
                _ClosureTimelinePanel(events: occurrence.effectiveTimeline),
              ],
            ),
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton.icon(
                    onPressed: () =>
                        _finish(context, status: OccurrenceStatus.completed),
                    icon: const Icon(Icons.flag_outlined),
                    label: const Text('Concluir pericia'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _finish(
                            context,
                            status: OccurrenceStatus.pendingReview,
                          ),
                          icon: const Icon(Icons.rate_review_outlined),
                          label: const Text('Revisao'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _finish(
                            context,
                            status: OccurrenceStatus.incomplete,
                          ),
                          icon: const Icon(Icons.warning_amber_outlined),
                          label: const Text('Incompleta'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _finish(
    BuildContext context, {
    required OccurrenceStatus status,
  }) async {
    await repository.completeOccurrence(occurrenceId, status: status);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Pericia encerrada como ${status.label}.')),
    );
    Navigator.of(context).pop();
  }
}

class _ClosureHeader extends StatelessWidget {
  const _ClosureHeader({required this.occurrence});

  final FieldOccurrence occurrence;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(occurrence.status);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withValues(alpha: 0.75)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.fact_check_outlined, color: statusColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Pericia consolidada',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              StatusChip(label: occurrence.status.label, color: statusColor),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            occurrence.caseData.displayTitle,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            occurrence.metadata.summary,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            occurrence.caseData.displayLocation,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ClosureStatsPanel extends StatelessWidget {
  const _ClosureStatsPanel({required this.stats, required this.occurrence});

  final OccurrenceStats stats;
  final FieldOccurrence occurrence;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            icon: Icons.analytics_outlined,
            title: 'Resumo operacional',
            trailing: _durationLabel(stats.durationSeconds),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetricChip(
                label: 'Inicio ${_shortDateTime(stats.startedAt)}',
                icon: Icons.play_circle_outline,
              ),
              _MetricChip(
                label: 'Fim ${_shortDateTime(stats.finishedAt)}',
                icon: Icons.flag_circle_outlined,
              ),
              _MetricChip(
                label: '${stats.photosCount} fotos',
                icon: Icons.photo_camera_outlined,
              ),
              _MetricChip(
                label: '${stats.victimsCount} vitimas/corpos',
                icon: Icons.personal_injury_outlined,
              ),
              _MetricChip(
                label: '${stats.tracesCount} vestigios',
                icon: Icons.scatter_plot_outlined,
              ),
              _MetricChip(
                label: '${stats.measurementsCount} medicoes',
                icon: Icons.straighten_outlined,
              ),
              _MetricChip(
                label: '${stats.notesCount} observacoes',
                icon: Icons.notes_outlined,
              ),
              _MetricChip(
                label:
                    '${stats.answeredChecklistItemsCount}/${stats.checklistItemsCount} checklist',
                icon: Icons.checklist_outlined,
              ),
              _MetricChip(
                label: '${stats.notApplicableItemsCount} nao aplicaveis',
                icon: Icons.block_outlined,
              ),
              _MetricChip(
                label: stats.bestGpsAccuracyMeters == null
                    ? 'GPS pendente'
                    : '${stats.bestGpsAccuracyMeters!.toStringAsFixed(1)} m GPS',
                icon: Icons.my_location_outlined,
              ),
              _MetricChip(
                label: stats.exported ? 'Exportada' : 'Nao exportada',
                icon: Icons.archive_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClosureWarningsPanel extends StatelessWidget {
  const _ClosureWarningsPanel({required this.warnings});

  final List<OperationalClosureWarning> warnings;

  @override
  Widget build(BuildContext context) {
    final color = warnings.isEmpty ? AppColors.success : AppColors.gold;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.75)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            icon: warnings.isEmpty
                ? Icons.verified_outlined
                : Icons.warning_amber_outlined,
            title: 'Pendencias operacionais',
            trailing: '${warnings.length}',
            color: color,
          ),
          const SizedBox(height: 10),
          if (warnings.isEmpty)
            const Text(
              'Sem alertas principais para o encerramento.',
              style: TextStyle(color: AppColors.textSecondary),
            )
          else ...[
            const Text(
              'Os avisos abaixo nao bloqueiam a conclusao.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            for (final warning in warnings)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      warning.critical
                          ? Icons.error_outline
                          : Icons.info_outline,
                      color: warning.critical
                          ? AppColors.danger
                          : AppColors.gold,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            warning.title,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            warning.description,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ClosureTimelinePanel extends StatelessWidget {
  const _ClosureTimelinePanel({required this.events});

  final List<OccurrenceTimelineEvent> events;

  @override
  Widget build(BuildContext context) {
    final ordered = [...events]
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            icon: Icons.timeline_outlined,
            title: 'Timeline automatica',
            trailing: '${ordered.length}',
          ),
          const SizedBox(height: 10),
          for (final event in ordered.take(8))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(_timelineIcon(event.type), color: AppColors.gold),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.displayTitle,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _shortDateTime(event.occurredAt),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        if (event.description.trim().isNotEmpty)
                          Text(
                            event.description,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.trailing,
    this.color = AppColors.gold,
  });

  final IconData icon;
  final String title;
  final String trailing;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        StatusChip(label: trailing, color: color),
      ],
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.gold, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

IconData _timelineIcon(OccurrenceTimelineEventType type) {
  return switch (type) {
    OccurrenceTimelineEventType.created => Icons.add_circle_outline,
    OccurrenceTimelineEventType.gpsStarted => Icons.gps_fixed_outlined,
    OccurrenceTimelineEventType.gpsCaptured => Icons.my_location_outlined,
    OccurrenceTimelineEventType.firstPhoto => Icons.photo_camera_outlined,
    OccurrenceTimelineEventType.exported => Icons.archive_outlined,
    OccurrenceTimelineEventType.imported => Icons.file_download_outlined,
    OccurrenceTimelineEventType.completed => Icons.flag_circle_outlined,
    OccurrenceTimelineEventType.reopened => Icons.lock_open_outlined,
    OccurrenceTimelineEventType.statusChanged => Icons.swap_horiz_outlined,
    OccurrenceTimelineEventType.archived => Icons.inventory_2_outlined,
  };
}

Color _statusColor(OccurrenceStatus status) {
  return switch (status) {
    OccurrenceStatus.inProgress => AppColors.gold,
    OccurrenceStatus.completed => AppColors.success,
    OccurrenceStatus.exported => AppColors.active,
    OccurrenceStatus.pendingReview => AppColors.gold,
    OccurrenceStatus.incomplete => AppColors.danger,
    OccurrenceStatus.archived => AppColors.textSecondary,
  };
}

String _durationLabel(int seconds) {
  final safe = seconds < 0 ? 0 : seconds;
  final hours = safe ~/ 3600;
  final minutes = (safe % 3600) ~/ 60;
  if (hours > 0) {
    return '${hours}h ${minutes.toString().padLeft(2, '0')}min';
  }
  return '${minutes}min';
}

String _shortDateTime(DateTime? value) {
  if (value == null) {
    return 'nao informado';
  }
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day/$month $hour:$minute';
}
