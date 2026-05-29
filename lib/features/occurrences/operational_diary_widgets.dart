import 'dart:io';

import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../domain/models/forensic_case_metadata.dart';
import '../../domain/models/occurrence.dart';
import '../../shared/widgets/empty_state.dart';

class OccurrenceMonthGroup {
  const OccurrenceMonthGroup({required this.label, required this.occurrences});

  final String label;
  final List<FieldOccurrence> occurrences;
}

List<OccurrenceMonthGroup> groupOccurrencesByMonth(
  List<FieldOccurrence> occurrences,
) {
  final sorted = [...occurrences]
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  final groups = <String, List<FieldOccurrence>>{};
  for (final occurrence in sorted) {
    final label = monthYearLabel(occurrence.createdAt);
    groups.putIfAbsent(label, () => []).add(occurrence);
  }
  return groups.entries
      .map(
        (entry) =>
            OccurrenceMonthGroup(label: entry.key, occurrences: entry.value),
      )
      .toList(growable: false);
}

String monthYearLabel(DateTime value) {
  final local = value.toLocal();
  return '${_months[local.month - 1]} ${local.year}'.toUpperCase();
}

String compactDateTime(DateTime value) {
  final local = value.toLocal();
  return '${_two(local.day)}/${_two(local.month)}/${local.year} '
      '${_two(local.hour)}:${_two(local.minute)}';
}

class OperationalDiarySection extends StatelessWidget {
  const OperationalDiarySection({
    required this.group,
    required this.onOpen,
    required this.onDelete,
    super.key,
  });

  final OccurrenceMonthGroup group;
  final ValueChanged<FieldOccurrence> onOpen;
  final ValueChanged<FieldOccurrence> onDelete;

  @override
  Widget build(BuildContext context) {
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
            child: _MonthHeader(label: group.label),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.separated(
            itemCount: group.occurrences.length,
            separatorBuilder: (_, _) => const SizedBox(height: 2),
            itemBuilder: (context, index) {
              final occurrence = group.occurrences[index];
              return OperationalDiaryCard(
                occurrence: occurrence,
                onTap: () => onOpen(occurrence),
                onDelete: () => onDelete(occurrence),
              );
            },
          ),
        ),
      ],
    );
  }
}

class OperationalDiaryCard extends StatelessWidget {
  const OperationalDiaryCard({
    required this.occurrence,
    required this.onTap,
    required this.onDelete,
    super.key,
  });

  final FieldOccurrence occurrence;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final statusColor = statusColorFor(occurrence);
    final pendingCount = occurrence.operationalProgress.pendingItems.length;
    final location = occurrence.caseData.municipality.trim().isEmpty
        ? 'Local nao informado'
        : '${occurrence.caseData.municipality.trim()}/AP';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _OccurrenceThumbnail(occurrence: occurrence),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      diaryTitle(occurrence),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '$location - ${compactDateTime(occurrence.createdAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (occurrence.caseData.bo.trim().isNotEmpty)
                          _DiaryPill(
                            label: 'BO ${occurrence.caseData.bo.trim()}',
                            color: AppColors.textSecondary,
                          ),
                        _DiaryPill(
                          label: occurrence.status.label,
                          color: statusColor,
                        ),
                        if (occurrence.metadata.result !=
                            OccurrenceResult.notInformed)
                          _DiaryPill(
                            label: occurrence.metadata.result.label,
                            color: _resultColor(occurrence),
                          ),
                        if (occurrence.metadata.officialVehicleInvolved)
                          const _DiaryPill(
                            label: 'Carro oficial',
                            color: AppColors.gold,
                          ),
                        _DiaryPill(
                          label: occurrence.bestGpsLocation == null
                              ? 'GPS pendente'
                              : 'GPS OK',
                          color: occurrence.bestGpsLocation == null
                              ? AppColors.gold
                              : AppColors.success,
                        ),
                        _DiaryPill(
                          label: '${occurrence.photos.length} fotos',
                          color: AppColors.textSecondary,
                        ),
                        if (pendingCount > 0)
                          _DiaryPill(
                            label: '$pendingCount pendencias',
                            color: pendingCount > 2
                                ? AppColors.danger
                                : AppColors.gold,
                          ),
                        if (occurrence.durationSeconds > 0)
                          _DiaryPill(
                            label: durationLabel(occurrence.durationSeconds),
                            color: AppColors.textSecondary,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              PopupMenuButton<_DiaryAction>(
                tooltip: 'Opcoes',
                icon: const Icon(
                  Icons.more_horiz,
                  color: AppColors.textSecondary,
                ),
                onSelected: (action) {
                  switch (action) {
                    case _DiaryAction.delete:
                      onDelete();
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: _DiaryAction.delete,
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, color: AppColors.danger),
                        SizedBox(width: 10),
                        Text('Excluir'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OperationalDiaryEmpty extends StatelessWidget {
  const OperationalDiaryEmpty({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.auto_stories_outlined,
      title: 'Diario operacional vazio',
      message:
          'Inicie uma pericia para criar a primeira entrada da sua linha do tempo.',
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(child: Divider(color: AppColors.border, height: 1)),
      ],
    );
  }
}

class _OccurrenceThumbnail extends StatelessWidget {
  const _OccurrenceThumbnail({required this.occurrence});

  final FieldOccurrence occurrence;

  @override
  Widget build(BuildContext context) {
    final path = occurrence.photos.isEmpty
        ? ''
        : occurrence.photos.first.filePath;
    final file = path.isEmpty ? null : File(path);
    final hasFile = file != null && file.existsSync();

    return ClipRRect(
      borderRadius: BorderRadius.circular(7),
      child: Container(
        width: 74,
        height: 96,
        decoration: BoxDecoration(
          color: AppColors.panel,
          border: Border.all(color: AppColors.border),
        ),
        child: hasFile
            ? Image.file(
                file,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    _FallbackThumbnail(occurrence: occurrence),
              )
            : _FallbackThumbnail(occurrence: occurrence),
      ),
    );
  }
}

class _FallbackThumbnail extends StatelessWidget {
  const _FallbackThumbnail({required this.occurrence});

  final FieldOccurrence occurrence;

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(occurrence.metadata.type);
    return Container(
      color: color.withValues(alpha: 0.14),
      child: Center(
        child: Icon(
          _typeIcon(occurrence.metadata.type),
          color: color,
          size: 30,
        ),
      ),
    );
  }
}

class _DiaryPill extends StatelessWidget {
  const _DiaryPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

enum _DiaryAction { delete }

Color statusColorFor(FieldOccurrence occurrence) {
  return switch (occurrence.status) {
    OccurrenceStatus.inProgress => AppColors.gold,
    OccurrenceStatus.completed => AppColors.success,
    OccurrenceStatus.exported => AppColors.success,
    OccurrenceStatus.pendingReview => AppColors.gold,
    OccurrenceStatus.incomplete => AppColors.danger,
    OccurrenceStatus.archived => AppColors.textSecondary,
  };
}

String diaryTitle(FieldOccurrence occurrence) {
  final parts = occurrence.metadata.summary
      .split(' - ')
      .where((part) => part.trim().isNotEmpty)
      .toList();
  final titleParts = parts.length > 1
      ? parts.skip(1).take(2).toList()
      : <String>[occurrence.metadata.type.label];
  return titleParts.join(' ').toUpperCase();
}

String durationLabel(int seconds) {
  final minutes = (seconds / 60).round();
  if (minutes < 60) {
    return '${minutes}min';
  }
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? '${hours}h' : '${hours}h${_two(rest)}';
}

Color _typeColor(ForensicCaseType type) {
  return switch (type) {
    ForensicCaseType.traffic => AppColors.gold,
    ForensicCaseType.violentDeath => AppColors.danger,
    ForensicCaseType.property => AppColors.active,
    ForensicCaseType.environmental => AppColors.success,
    ForensicCaseType.ballistics => AppColors.gold,
    ForensicCaseType.audioImage => AppColors.active,
    ForensicCaseType.papiloscopy => AppColors.gold,
  };
}

IconData _typeIcon(ForensicCaseType type) {
  return switch (type) {
    ForensicCaseType.traffic => Icons.traffic_outlined,
    ForensicCaseType.violentDeath => Icons.biotech_outlined,
    ForensicCaseType.property => Icons.business_outlined,
    ForensicCaseType.environmental => Icons.forest_outlined,
    ForensicCaseType.ballistics => Icons.adjust_outlined,
    ForensicCaseType.audioImage => Icons.perm_media_outlined,
    ForensicCaseType.papiloscopy => Icons.fingerprint,
  };
}

Color _resultColor(FieldOccurrence occurrence) {
  return switch (occurrence.metadata.result) {
    OccurrenceResult.fatalVictim => AppColors.danger,
    OccurrenceResult.multipleVictims => AppColors.danger,
    OccurrenceResult.injuredVictim => AppColors.gold,
    OccurrenceResult.noVictim => AppColors.success,
    OccurrenceResult.notInformed => AppColors.textSecondary,
  };
}

String _two(int value) => value.toString().padLeft(2, '0');

const _months = [
  'Janeiro',
  'Fevereiro',
  'Marco',
  'Abril',
  'Maio',
  'Junho',
  'Julho',
  'Agosto',
  'Setembro',
  'Outubro',
  'Novembro',
  'Dezembro',
];
