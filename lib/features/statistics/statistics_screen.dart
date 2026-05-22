import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/theme/app_theme.dart';
import '../../core/data/app_settings_repository.dart';
import '../../core/data/occurrence_repository.dart';
import '../../core/data/operational_statistics_service.dart';
import '../../core/data/statistical_report_pdf_service.dart';
import '../../domain/models/forensic_case_metadata.dart';
import '../../domain/models/occurrence.dart';
import '../../shared/widgets/empty_state.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({
    required this.repository,
    required this.settingsRepository,
    super.key,
  });

  final OccurrenceRepository repository;
  final AppSettingsRepository settingsRepository;

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final OperationalStatisticsService _service =
      const OperationalStatisticsService();
  final StatisticalReportPdfService _reportService =
      StatisticalReportPdfService();
  StatisticsFilter _filter = const StatisticsFilter();
  bool _generatingReport = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.repository,
      builder: (context, _) {
        final snapshot = _service.aggregate(
          widget.repository.occurrences,
          _filter,
        );

        return Scaffold(
          appBar: AppBar(title: const Text('Estatisticas')),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 108),
              children: [
                _StatisticsHeader(snapshot: snapshot),
                const SizedBox(height: 12),
                _FilterPanel(
                  filter: _filter,
                  onPeriodChanged: _setPeriod,
                  onCustomRangeTap: _pickCustomRange,
                  onTypeChanged: _setType,
                  onStatusChanged: _setStatus,
                ),
                const SizedBox(height: 12),
                if (snapshot.isEmpty)
                  const EmptyState(
                    icon: Icons.analytics_outlined,
                    title: 'Sem dados no filtro',
                    message:
                        'Ajuste o periodo, tipo de pericia ou status para visualizar a producao registrada neste aparelho.',
                  )
                else ...[
                  _IndicatorGrid(snapshot: snapshot),
                  const SizedBox(height: 12),
                  _ProductivityPanel(snapshot: snapshot),
                  const SizedBox(height: 12),
                  _DistributionPanel(
                    title: 'Pericias por tipo',
                    icon: Icons.category_outlined,
                    entries: snapshot.byType,
                  ),
                  const SizedBox(height: 12),
                  _DistributionPanel(
                    title: 'Pericias por natureza',
                    icon: Icons.account_tree_outlined,
                    entries: snapshot.byNature,
                  ),
                  const SizedBox(height: 12),
                  _DistributionPanel(
                    title: 'Pericias por mes',
                    icon: Icons.calendar_month_outlined,
                    entries: snapshot.byMonth,
                  ),
                  const SizedBox(height: 12),
                  _DistributionPanel(
                    title: 'Pericias por municipio',
                    icon: Icons.location_city_outlined,
                    entries: snapshot.byMunicipality,
                  ),
                  const SizedBox(height: 12),
                  _DistributionPanel(
                    title: 'Pericias por bairro',
                    icon: Icons.place_outlined,
                    entries: snapshot.byDistrict,
                  ),
                ],
              ],
            ),
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: FilledButton.icon(
                onPressed: snapshot.isEmpty || _generatingReport
                    ? null
                    : () => _generateReport(snapshot),
                icon: _generatingReport
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.picture_as_pdf_outlined),
                label: Text(
                  _generatingReport
                      ? 'Gerando relatorio...'
                      : 'Gerar relatorio estatistico',
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _setPeriod(StatisticsPeriodPreset period) {
    if (period == StatisticsPeriodPreset.custom) {
      if (_filter.customStart == null || _filter.customEnd == null) {
        _pickCustomRange();
        return;
      }
      setState(() => _filter = _filter.copyWith(period: period));
      return;
    }
    setState(
      () => _filter = _filter.copyWith(
        period: period,
        clearCustomStart: true,
        clearCustomEnd: true,
      ),
    );
  }

  void _setType(ForensicCaseType? type) {
    setState(
      () => _filter = _filter.copyWith(type: type, clearType: type == null),
    );
  }

  void _setStatus(OccurrenceStatus? status) {
    setState(
      () => _filter = _filter.copyWith(
        status: status,
        clearStatus: status == null,
      ),
    );
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final first = await showDatePicker(
      context: context,
      initialDate: _filter.customStart ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1, 12, 31),
      helpText: 'Data inicial',
    );
    if (first == null || !mounted) {
      return;
    }
    final last = await showDatePicker(
      context: context,
      initialDate:
          _filter.customEnd == null || _filter.customEnd!.isBefore(first)
          ? first
          : _filter.customEnd!,
      firstDate: first,
      lastDate: DateTime(now.year + 1, 12, 31),
      helpText: 'Data final',
    );
    if (last == null || !mounted) {
      return;
    }
    setState(
      () => _filter = _filter.copyWith(
        period: StatisticsPeriodPreset.custom,
        customStart: first,
        customEnd: last,
      ),
    );
  }

  Future<void> _generateReport(OperationalStatisticsSnapshot snapshot) async {
    setState(() => _generatingReport = true);
    try {
      final result = await _reportService.generate(
        snapshot: snapshot,
        profile: widget.settingsRepository.settings.profile,
      );
      if (!mounted) {
        return;
      }
      await _showReportDialog(result);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Falha ao gerar relatorio estatistico: $error'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _generatingReport = false);
      }
    }
  }

  Future<void> _showReportDialog(StatisticalReportResult result) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Relatorio estatistico gerado'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ReportInfoRow(label: 'Arquivo', value: result.fileName),
                _ReportInfoRow(
                  label: 'Tamanho',
                  value: _formatBytes(result.sizeBytes),
                ),
                _ReportInfoRow(label: 'Local', value: result.file.path),
                _ReportInfoRow(
                  label: 'Pericias',
                  value: '${result.occurrenceCount}',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fechar'),
            ),
            FilledButton.icon(
              onPressed: () => _shareReport(context, result),
              icon: const Icon(Icons.share_outlined),
              label: const Text('Compartilhar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _shareReport(
    BuildContext context,
    StatisticalReportResult result,
  ) async {
    if (!await result.file.exists()) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('O relatorio nao foi encontrado no aparelho.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    await SharePlus.instance.share(
      ShareParams(
        title: 'Compartilhar relatorio estatistico',
        subject: result.fileName,
        text: 'Relatorio estatistico operacional gerado no SICRO Operacional.',
        files: [
          XFile(
            result.file.path,
            mimeType: 'application/pdf',
            name: result.fileName,
          ),
        ],
        fileNameOverrides: [result.fileName],
      ),
    );
  }
}

class _StatisticsHeader extends StatelessWidget {
  const _StatisticsHeader({required this.snapshot});

  final OperationalStatisticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.gold),
            ),
            child: const Icon(Icons.analytics_outlined, color: AppColors.gold),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Inteligencia operacional local',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Resumo calculado automaticamente a partir das pericias salvas neste aparelho.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 10),
                Text(
                  'Atualizado em ${_dateTimeLabel(snapshot.generatedAt)}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
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

class _FilterPanel extends StatelessWidget {
  const _FilterPanel({
    required this.filter,
    required this.onPeriodChanged,
    required this.onCustomRangeTap,
    required this.onTypeChanged,
    required this.onStatusChanged,
  });

  final StatisticsFilter filter;
  final ValueChanged<StatisticsPeriodPreset> onPeriodChanged;
  final VoidCallback onCustomRangeTap;
  final ValueChanged<ForensicCaseType?> onTypeChanged;
  final ValueChanged<OccurrenceStatus?> onStatusChanged;

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
          _PanelTitle(icon: Icons.tune_outlined, title: 'Filtros'),
          const SizedBox(height: 12),
          _FilterLabel('Periodo'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final period in StatisticsPeriodPreset.values)
                ChoiceChip(
                  label: Text(period.label),
                  selected: filter.period == period,
                  onSelected: (_) => onPeriodChanged(period),
                ),
            ],
          ),
          if (filter.period == StatisticsPeriodPreset.custom) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onCustomRangeTap,
              icon: const Icon(Icons.date_range_outlined),
              label: Text(
                filter.customStart == null || filter.customEnd == null
                    ? 'Selecionar intervalo'
                    : '${_dateLabel(filter.customStart!)} a ${_dateLabel(filter.customEnd!)}',
              ),
            ),
          ],
          const SizedBox(height: 14),
          _FilterLabel('Tipo de pericia'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Todos'),
                selected: filter.type == null,
                onSelected: (_) => onTypeChanged(null),
              ),
              for (final type in ForensicCaseType.values)
                ChoiceChip(
                  label: Text(type.label),
                  selected: filter.type == type,
                  onSelected: (_) => onTypeChanged(type),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _FilterLabel('Status'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Todos'),
                selected: filter.status == null,
                onSelected: (_) => onStatusChanged(null),
              ),
              for (final status in _visibleStatuses)
                ChoiceChip(
                  label: Text(status.label),
                  selected: filter.status == status,
                  onSelected: (_) => onStatusChanged(status),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IndicatorGrid extends StatelessWidget {
  const _IndicatorGrid({required this.snapshot});

  final OperationalStatisticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final items = [
      _IndicatorData(
        icon: Icons.assignment_outlined,
        title: 'Total de pericias',
        value: '${snapshot.totalOccurrences}',
      ),
      _IndicatorData(
        icon: Icons.flag_outlined,
        title: 'Concluidas',
        value: '${snapshot.completedOccurrences}',
      ),
      _IndicatorData(
        icon: Icons.archive_outlined,
        title: 'Exportadas',
        value: '${snapshot.exportedOccurrences}',
      ),
      _IndicatorData(
        icon: Icons.timer_outlined,
        title: 'Tempo medio',
        value: _durationLabel(snapshot.averageDurationSeconds),
      ),
      _IndicatorData(
        icon: Icons.photo_camera_outlined,
        title: 'Fotos',
        value: '${snapshot.totalPhotos}',
      ),
      _IndicatorData(
        icon: Icons.scatter_plot_outlined,
        title: 'Vestigios',
        value: '${snapshot.totalTraces}',
      ),
      _IndicatorData(
        icon: Icons.straighten_outlined,
        title: 'Medicoes',
        value: '${snapshot.totalMeasurements}',
      ),
      _IndicatorData(
        icon: Icons.personal_injury_outlined,
        title: 'Vitimas/corpos',
        value: '${snapshot.totalVictims}',
      ),
      _IndicatorData(
        icon: Icons.directions_car_outlined,
        title: 'Veiculos',
        value: '${snapshot.totalVehicles}',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 680 ? 3 : 2;
        final width = (constraints.maxWidth - ((columns - 1) * 10)) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: _IndicatorCard(data: item),
              ),
          ],
        );
      },
    );
  }
}

class _IndicatorData {
  const _IndicatorData({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;
}

class _IndicatorCard extends StatelessWidget {
  const _IndicatorCard({required this.data});

  final _IndicatorData data;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(data.icon, color: AppColors.gold),
            const SizedBox(height: 10),
            Text(
              data.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 3),
            Text(
              data.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductivityPanel extends StatelessWidget {
  const _ProductivityPanel({required this.snapshot});

  final OperationalStatisticsSnapshot snapshot;

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
          _PanelTitle(
            icon: Icons.insights_outlined,
            title: 'Produtividade pessoal',
          ),
          const SizedBox(height: 12),
          _InfoRow(
            label: 'Primeira pericia',
            value: _dateTimeLabel(snapshot.firstOccurrenceAt),
          ),
          _InfoRow(
            label: 'Ultima pericia',
            value: _dateTimeLabel(snapshot.lastOccurrenceAt),
          ),
          _InfoRow(
            label: 'Horas em atendimento',
            value: _hoursLabel(snapshot.totalDurationSeconds),
          ),
          _InfoRow(
            label: 'Media de fotos por pericia',
            value: snapshot.averagePhotosPerOccurrence.toStringAsFixed(1),
          ),
          _InfoRow(
            label: 'Media de duracao',
            value: _durationLabel(snapshot.averageDurationSeconds),
          ),
        ],
      ),
    );
  }
}

class _DistributionPanel extends StatelessWidget {
  const _DistributionPanel({
    required this.title,
    required this.icon,
    required this.entries,
  });

  final String title;
  final IconData icon;
  final List<DistributionEntry> entries;

  @override
  Widget build(BuildContext context) {
    final visible = entries.take(6).toList();
    final maxCount = visible.isEmpty
        ? 1
        : visible.map((entry) => entry.count).reduce((a, b) => a > b ? a : b);

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
          _PanelTitle(icon: icon, title: title),
          const SizedBox(height: 12),
          if (visible.isEmpty)
            const Text(
              'Sem dados para este recorte.',
              style: TextStyle(color: AppColors.textSecondary),
            )
          else
            for (final entry in visible)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _DistributionRow(
                  entry: entry,
                  fraction: entry.count / maxCount,
                ),
              ),
        ],
      ),
    );
  }
}

class _DistributionRow extends StatelessWidget {
  const _DistributionRow({required this.entry, required this.fraction});

  final DistributionEntry entry;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                entry.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${entry.count}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 7,
            color: AppColors.card,
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: fraction.clamp(0.05, 1),
              child: Container(color: AppColors.gold),
            ),
          ),
        ),
      ],
    );
  }
}

class _PanelTitle extends StatelessWidget {
  const _PanelTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.gold),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

class _FilterLabel extends StatelessWidget {
  const _FilterLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportInfoRow extends StatelessWidget {
  const _ReportInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

const _visibleStatuses = [
  OccurrenceStatus.inProgress,
  OccurrenceStatus.completed,
  OccurrenceStatus.exported,
  OccurrenceStatus.archived,
];

String _durationLabel(int seconds) {
  if (seconds <= 0) {
    return '0 min';
  }
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  if (hours == 0) {
    return '${minutes < 1 ? 1 : minutes} min';
  }
  if (minutes == 0) {
    return '${hours}h';
  }
  return '${hours}h ${minutes.toString().padLeft(2, '0')}min';
}

String _hoursLabel(int seconds) {
  final hours = seconds / 3600;
  return '${hours.toStringAsFixed(1)} h';
}

String _formatBytes(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }
  final kb = bytes / 1024;
  if (kb < 1024) {
    return '${kb.toStringAsFixed(1)} KB';
  }
  return '${(kb / 1024).toStringAsFixed(1)} MB';
}

String _dateLabel(DateTime date) {
  return '${_two(date.day)}/${_two(date.month)}/${date.year}';
}

String _dateTimeLabel(DateTime? date) {
  if (date == null) {
    return 'Nao informado';
  }
  return '${_dateLabel(date)} ${_two(date.hour)}:${_two(date.minute)}';
}

String _two(int value) => value.toString().padLeft(2, '0');
