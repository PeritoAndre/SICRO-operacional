import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/theme/app_theme.dart';
import '../../core/data/app_settings_repository.dart';
import '../../core/data/duty_report_pdf_service.dart';
import '../../core/data/occurrence_repository.dart';
import '../../domain/models/occurrence.dart';
import '../../shared/utils/share_origin.dart';
import '../../shared/widgets/empty_state.dart';

class DutyReportScreen extends StatefulWidget {
  const DutyReportScreen({
    required this.repository,
    required this.settingsRepository,
    super.key,
  });

  final OccurrenceRepository repository;
  final AppSettingsRepository settingsRepository;

  @override
  State<DutyReportScreen> createState() => _DutyReportScreenState();
}

class _DutyReportScreenState extends State<DutyReportScreen> {
  static const _postDutyGrace = Duration(hours: 2);

  final _service = DutyReportPdfService();
  final _expertName = TextEditingController();
  final _role = TextEditingController();
  final _dutyScale = TextEditingController();
  final _observations = TextEditingController();
  final Set<String> _selectedIds = {};

  late DateTime _startedAt;
  late DateTime _finishedAt;
  DutyReportTemplate _template = DutyReportTemplate.operational;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.settingsRepository.settings.profile;
    final now = DateTime.now();
    _startedAt = DateTime(now.year, now.month, now.day, 7, 30);
    _finishedAt = _startedAt.add(const Duration(hours: 24));
    _expertName.text = profile.name;
    _role.text = profile.role.trim().isEmpty
        ? 'Perito Criminal'
        : profile.role.trim();
    _dutyScale.text = profile.unit;
  }

  @override
  void dispose() {
    _expertName.dispose();
    _role.dispose();
    _dutyScale.dispose();
    _observations.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.repository,
      builder: (context, _) {
        final occurrences = widget.repository.occurrences;
        final visibleOccurrences = _visibleOccurrences(occurrences);
        final graceOccurrences = visibleOccurrences
            .where(_isPostDutyGraceOccurrence)
            .length;
        final selected = _selectedOccurrences(visibleOccurrences);
        return Scaffold(
          appBar: AppBar(title: const Text('Relatorio de plantao')),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                const _ReportIntroCard(),
                const SizedBox(height: 12),
                _ReportTemplateCard(
                  template: _template,
                  onChanged: (template) => setState(() => _template = template),
                ),
                const SizedBox(height: 12),
                _ShiftDataCard(
                  expertName: _expertName,
                  role: _role,
                  dutyScale: _dutyScale,
                  observations: _observations,
                  startedAt: _startedAt,
                  finishedAt: _finishedAt,
                  onPickStart: () => _pickDateTime(start: true),
                  onPickFinish: () => _pickDateTime(start: false),
                ),
                const SizedBox(height: 14),
                _OccurrenceSelectionHeader(
                  selectedCount: selected.length,
                  totalCount: visibleOccurrences.length,
                  onToggleAll: visibleOccurrences.isEmpty
                      ? null
                      : () => _toggleAll(visibleOccurrences),
                ),
                const SizedBox(height: 8),
                _DutyPeriodFilterNote(
                  startedAt: _startedAt,
                  finishedAt: _finishedAt,
                  visibleCount: visibleOccurrences.length,
                  graceCount: graceOccurrences,
                ),
                const SizedBox(height: 10),
                if (occurrences.isEmpty)
                  const EmptyState(
                    icon: Icons.assignment_outlined,
                    title: 'Nenhuma ocorrencia local',
                    message:
                        'Crie ou importe ocorrencias neste aparelho para compor o relatorio de plantao.',
                  )
                else if (visibleOccurrences.isEmpty)
                  const EmptyState(
                    icon: Icons.event_busy_outlined,
                    title: 'Nenhuma ocorrencia no periodo',
                    message:
                        'Ajuste o intervalo do plantao para mostrar as ocorrencias iniciadas nele. A margem de 2h apos o fim ja esta incluida.',
                  )
                else
                  for (final occurrence in visibleOccurrences)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _SelectableOccurrenceCard(
                        occurrence: occurrence,
                        startedAt: _occurrenceStartDate(occurrence),
                        outsideWindow: _isPostDutyGraceOccurrence(occurrence),
                        selected: _selectedIds.contains(occurrence.id),
                        onChanged: (selected) =>
                            _setSelected(occurrence.id, selected),
                      ),
                    ),
              ],
            ),
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: FilledButton.icon(
                onPressed: _generating ? null : () => _generate(selected),
                icon: _generating
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.picture_as_pdf_outlined),
                label: Text(
                  _generating
                      ? 'Gerando relatorio...'
                      : 'Gerar relatorio de plantao',
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

  List<FieldOccurrence> _visibleOccurrences(List<FieldOccurrence> occurrences) {
    final graceEnd = _finishedAt.add(_postDutyGrace);
    final filtered = occurrences.where((occurrence) {
      final startedAt = _occurrenceStartDate(occurrence);
      return !startedAt.isBefore(_startedAt) && !startedAt.isAfter(graceEnd);
    }).toList();
    filtered.sort(
      (a, b) => _occurrenceStartDate(a).compareTo(_occurrenceStartDate(b)),
    );
    return filtered;
  }

  bool _isPostDutyGraceOccurrence(FieldOccurrence occurrence) {
    final startedAt = _occurrenceStartDate(occurrence);
    final graceEnd = _finishedAt.add(_postDutyGrace);
    return startedAt.isAfter(_finishedAt) && !startedAt.isAfter(graceEnd);
  }

  List<FieldOccurrence> _selectedOccurrences(
    List<FieldOccurrence> occurrences,
  ) {
    return occurrences
        .where((occurrence) => _selectedIds.contains(occurrence.id))
        .toList();
  }

  void _setSelected(String occurrenceId, bool selected) {
    setState(() {
      if (selected) {
        _selectedIds.add(occurrenceId);
      } else {
        _selectedIds.remove(occurrenceId);
      }
    });
  }

  void _toggleAll(List<FieldOccurrence> occurrences) {
    final allSelected = occurrences.every(
      (occurrence) => _selectedIds.contains(occurrence.id),
    );
    setState(() {
      if (allSelected) {
        _selectedIds.clear();
      } else {
        _selectedIds
          ..clear()
          ..addAll(occurrences.map((occurrence) => occurrence.id));
      }
    });
  }

  Future<void> _pickDateTime({required bool start}) async {
    final initial = start ? _startedAt : _finishedAt;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) {
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) {
      return;
    }
    final picked = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (start) {
        _startedAt = picked;
        if (!_finishedAt.isAfter(_startedAt)) {
          _finishedAt = _startedAt.add(const Duration(hours: 24));
        }
      } else {
        _finishedAt = picked;
      }
    });
  }

  Future<void> _generate(List<FieldOccurrence> selected) async {
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione ao menos uma ocorrencia do plantao.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }
    if (!_finishedAt.isAfter(_startedAt)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A data final deve ser posterior ao inicio.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _generating = true);
    try {
      final result = await _service.generate(
        DutyReportData(
          expertName: _expertName.text.trim(),
          role: _role.text.trim(),
          dutyScale: _dutyScale.text.trim(),
          startedAt: _startedAt,
          finishedAt: _finishedAt,
          observations: _observations.text.trim(),
          occurrences: selected,
          template: _template,
        ),
      );
      if (!mounted) {
        return;
      }
      await _showResultDialog(result);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Falha ao gerar relatorio: $error'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _generating = false);
      }
    }
  }

  Future<void> _showResultDialog(DutyReportResult result) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Relatorio de plantao gerado'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ReportInfoRow(label: 'Arquivo', value: result.fileName),
                _ReportInfoRow(label: 'Modelo', value: result.template.label),
                _ReportInfoRow(
                  label: 'Tamanho',
                  value: _formatBytes(result.sizeBytes),
                ),
                _ReportInfoRow(label: 'Local', value: result.file.path),
                _ReportInfoRow(
                  label: 'Ocorrencias',
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
    DutyReportResult result,
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

    if (!context.mounted) {
      return;
    }
    final shareOrigin = sharePositionOriginFor(context);
    await SharePlus.instance.share(
      ShareParams(
        title: 'Compartilhar relatorio de plantao',
        subject: result.fileName,
        text: 'Relatorio de plantao gerado no ecossistema SICRO.',
        sharePositionOrigin: shareOrigin,
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

class _ReportIntroCard extends StatelessWidget {
  const _ReportIntroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.gold),
            ),
            child: const Icon(
              Icons.picture_as_pdf_outlined,
              color: AppColors.gold,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Relatorio de plantao',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Selecione o modelo, marque as ocorrencias atendidas e gere o PDF institucional.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportTemplateCard extends StatelessWidget {
  const _ReportTemplateCard({required this.template, required this.onChanged});

  final DutyReportTemplate template;
  final ValueChanged<DutyReportTemplate> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Modelo do relatorio',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          const Text(
            'O modelo operacional aproveita os dados do dossie SICRO. O classico preserva a tabela institucional atual.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          SegmentedButton<DutyReportTemplate>(
            selected: {template},
            showSelectedIcon: false,
            onSelectionChanged: (selection) => onChanged(selection.first),
            segments: const [
              ButtonSegment(
                value: DutyReportTemplate.operational,
                icon: Icon(Icons.auto_awesome_outlined),
                label: Text('Operacional SICRO'),
              ),
              ButtonSegment(
                value: DutyReportTemplate.classic,
                icon: Icon(Icons.table_chart_outlined),
                label: Text('Classico'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShiftDataCard extends StatelessWidget {
  const _ShiftDataCard({
    required this.expertName,
    required this.role,
    required this.dutyScale,
    required this.observations,
    required this.startedAt,
    required this.finishedAt,
    required this.onPickStart,
    required this.onPickFinish,
  });

  final TextEditingController expertName;
  final TextEditingController role;
  final TextEditingController dutyScale;
  final TextEditingController observations;
  final DateTime startedAt;
  final DateTime finishedAt;
  final VoidCallback onPickStart;
  final VoidCallback onPickFinish;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          TextField(
            controller: expertName,
            decoration: const InputDecoration(
              labelText: 'Nome do perito',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: role,
            decoration: const InputDecoration(
              labelText: 'Funcao',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: dutyScale,
            decoration: const InputDecoration(
              labelText: 'Escala de plantao',
              prefixIcon: Icon(Icons.schedule_outlined),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _DateTimeButton(
                  label: 'Inicio',
                  value: _dateTimeLabel(startedAt),
                  onPressed: onPickStart,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DateTimeButton(
                  label: 'Final',
                  value: _dateTimeLabel(finishedAt),
                  onPressed: onPickFinish,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: observations,
            minLines: 2,
            maxLines: 4,
            textInputAction: TextInputAction.newline,
            decoration: const InputDecoration(
              labelText: 'Observacoes',
              prefixIcon: Icon(Icons.notes_outlined),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateTimeButton extends StatelessWidget {
  const _DateTimeButton({
    required this.label,
    required this.value,
    required this.onPressed,
  });

  final String label;
  final String value;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _OccurrenceSelectionHeader extends StatelessWidget {
  const _OccurrenceSelectionHeader({
    required this.selectedCount,
    required this.totalCount,
    required this.onToggleAll,
  });

  final int selectedCount;
  final int totalCount;
  final VoidCallback? onToggleAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Ocorrencias do plantao',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        Text(
          '$selectedCount/$totalCount',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: onToggleAll,
          child: Text(
            selectedCount == totalCount && totalCount > 0
                ? 'Limpar'
                : 'Selecionar todas',
          ),
        ),
      ],
    );
  }
}

class _DutyPeriodFilterNote extends StatelessWidget {
  const _DutyPeriodFilterNote({
    required this.startedAt,
    required this.finishedAt,
    required this.visibleCount,
    required this.graceCount,
  });

  final DateTime startedAt;
  final DateTime finishedAt;
  final int visibleCount;
  final int graceCount;

  @override
  Widget build(BuildContext context) {
    final message = graceCount == 0
        ? 'Mostrando ocorrencias iniciadas entre ${_dateTimeLabel(startedAt)} e ${_dateTimeLabel(finishedAt)}.'
        : 'Mostrando $visibleCount ocorrencia(s); $graceCount fora da janela, iniciada(s) ate 2h apos o fim do plantao.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.filter_alt_outlined,
            color: AppColors.textSecondary,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectableOccurrenceCard extends StatelessWidget {
  const _SelectableOccurrenceCard({
    required this.occurrence,
    required this.startedAt,
    required this.outsideWindow,
    required this.selected,
    required this.onChanged,
  });

  final FieldOccurrence occurrence;
  final DateTime startedAt;
  final bool outsideWindow;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: CheckboxListTile(
        value: selected,
        onChanged: (value) => onChanged(value ?? false),
        controlAffinity: ListTileControlAffinity.leading,
        title: Text(
          occurrence.caseData.displayTitle,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(occurrence.metadata.summary),
              const SizedBox(height: 4),
              Text(occurrence.caseData.displayLocation),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Inicio: ${_dateTimeLabel(startedAt)}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (outsideWindow)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.6),
                        ),
                      ),
                      child: const Text(
                        'Fora da janela (+2h)',
                        style: TextStyle(
                          color: AppColors.gold,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
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
            width: 96,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

DateTime _occurrenceStartDate(FieldOccurrence occurrence) {
  return occurrence.startedAt ??
      occurrence.caseData.calledAt ??
      occurrence.caseData.arrivedAt ??
      occurrence.createdAt;
}

String _dateTimeLabel(DateTime value) {
  final local = value.toLocal();
  return '${_two(local.day)}/${_two(local.month)}/${local.year} '
      '${_two(local.hour)}:${_two(local.minute)}';
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

String _two(int value) => value.toString().padLeft(2, '0');
