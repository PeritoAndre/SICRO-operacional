import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/data/duty_shift_repository.dart';
import '../../core/services/document_picker_channel.dart';
import '../../core/services/duty_shift_notification_service.dart';
import '../../core/services/duty_shift_schedule_import_service.dart';

class DutyShiftScheduleImportScreen extends StatefulWidget {
  const DutyShiftScheduleImportScreen({
    required this.repository,
    required this.initialExpertName,
    this.notificationService,
    super.key,
  });

  final DutyShiftRepository repository;
  final DutyShiftNotificationService? notificationService;
  final String initialExpertName;

  @override
  State<DutyShiftScheduleImportScreen> createState() =>
      _DutyShiftScheduleImportScreenState();
}

class _DutyShiftScheduleImportScreenState
    extends State<DutyShiftScheduleImportScreen> {
  final _service = DutyShiftScheduleImportService();
  final _documentPicker = DocumentPickerChannel();
  late final TextEditingController _nameController;
  DutyShiftScheduleImportResult? _result;
  String? _fileName;
  String? _error;
  bool _loading = false;
  bool _importing = false;
  final Set<String> _selectedKeys = {};

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: _firstUsefulName(widget.initialExpertName),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final candidates = result?.candidates ?? const <DutyShiftImportCandidate>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Importar escala PDF')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            const _ImportIntro(),
            const SizedBox(height: 14),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nome na escala',
                hintText: 'Ex.: Andre',
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _loading ? null : _pickPdf,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file_outlined),
              label: Text(
                _loading
                    ? 'Lendo escala...'
                    : _fileName == null
                    ? 'Selecionar PDF da escala'
                    : 'Trocar PDF: $_fileName',
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              _ImportMessage(
                icon: Icons.warning_amber_outlined,
                color: AppColors.danger,
                text: _error!,
              ),
            ],
            if (result != null) ...[
              const SizedBox(height: 14),
              _ImportSummary(
                result: result,
                selectedCount: _selectedKeys.length,
              ),
              for (final warning in result.warnings)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _ImportMessage(
                    icon: Icons.info_outline,
                    color: AppColors.gold,
                    text: warning,
                  ),
                ),
              const SizedBox(height: 12),
              if (candidates.isEmpty)
                const _NoCandidatesCard()
              else
                for (final candidate in candidates)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _CandidateCard(
                      candidate: candidate,
                      alreadyExists: _alreadyExists(candidate),
                      selected: _selectedKeys.contains(candidate.key),
                      onChanged: _alreadyExists(candidate)
                          ? null
                          : (value) {
                              setState(() {
                                if (value == true) {
                                  _selectedKeys.add(candidate.key);
                                } else {
                                  _selectedKeys.remove(candidate.key);
                                }
                              });
                            },
                    ),
                  ),
              if (candidates.isNotEmpty) ...[
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _selectedKeys.isEmpty || _importing
                      ? null
                      : _importSelected,
                  icon: _importing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.event_available_outlined),
                  label: Text(
                    _importing
                        ? 'Importando...'
                        : 'Importar ${_selectedKeys.length} plantao(oes)',
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickPdf() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Informe o nome que deve ser procurado.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
      _selectedKeys.clear();
    });
    try {
      final file = await _documentPicker.pickPdf();
      if (file == null) {
        return;
      }
      if (!file.ok) {
        throw DutyShiftScheduleImportException(
          file.nativeError ?? 'Nao foi possivel selecionar o PDF.',
        );
      }
      final bytes = await _bytesFrom(file);
      final parsed = _service.parsePdf(
        bytes: bytes,
        expertName: name,
        sourceFileName: file.originalName,
      );
      final selectable = parsed.candidates.where((candidate) {
        return !_alreadyExists(candidate);
      });
      setState(() {
        _fileName = file.originalName;
        _result = parsed;
        _selectedKeys
          ..clear()
          ..addAll(selectable.map((candidate) => candidate.key));
      });
    } on DutyShiftScheduleImportException catch (error) {
      setState(() => _error = error.message);
    } catch (error) {
      setState(() => _error = 'Nao foi possivel ler a escala: $error');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<Uint8List> _bytesFrom(PickedDocumentFile file) async {
    final path = file.filePath;
    if (path.isEmpty) {
      throw const DutyShiftScheduleImportException(
        'O arquivo selecionado nao pode ser acessado.',
      );
    }
    return File(path).readAsBytes();
  }

  Future<void> _importSelected() async {
    final result = _result;
    if (result == null) {
      return;
    }
    setState(() => _importing = true);
    var index = 0;
    var imported = 0;
    try {
      for (final candidate in result.candidates) {
        if (!_selectedKeys.contains(candidate.key) ||
            _alreadyExists(candidate)) {
          continue;
        }
        await widget.repository.saveShift(candidate.toDutyShift(index: index));
        index++;
        imported++;
      }
      await widget.notificationService?.requestPermission();
      await widget.notificationService?.rescheduleAll(widget.repository.shifts);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$imported plantao(oes) importado(s).')),
      );
      Navigator.of(context).pop();
    } finally {
      if (mounted) {
        setState(() => _importing = false);
      }
    }
  }

  bool _alreadyExists(DutyShiftImportCandidate candidate) {
    return widget.repository.shifts.any((shift) {
      return shift.startsAt.year == candidate.startsAt.year &&
          shift.startsAt.month == candidate.startsAt.month &&
          shift.startsAt.day == candidate.startsAt.day &&
          shift.title.trim().toLowerCase() ==
              candidate.columnLabel.trim().toLowerCase();
    });
  }
}

class _ImportIntro extends StatelessWidget {
  const _ImportIntro();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.picture_as_pdf_outlined, color: AppColors.gold),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Selecione o PDF da escala mensal. O SICRO procura seu nome, identifica a coluna do plantao e mostra uma revisao antes de importar.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImportSummary extends StatelessWidget {
  const _ImportSummary({required this.result, required this.selectedCount});

  final DutyShiftScheduleImportResult result;
  final int selectedCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.fact_check_outlined, color: AppColors.success),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${result.candidates.length} encontrado(s) em ${_monthLabel(result.month)}/${result.year} - $selectedCount selecionado(s)',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({
    required this.candidate,
    required this.alreadyExists,
    required this.selected,
    required this.onChanged,
  });

  final DutyShiftImportCandidate candidate;
  final bool alreadyExists;
  final bool selected;
  final ValueChanged<bool?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final color = alreadyExists ? AppColors.textSecondary : AppColors.gold;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: alreadyExists
              ? AppColors.border
              : selected
              ? AppColors.gold
              : AppColors.border,
        ),
      ),
      child: CheckboxListTile(
        value: alreadyExists ? false : selected,
        onChanged: onChanged,
        controlAffinity: ListTileControlAffinity.leading,
        activeColor: AppColors.gold,
        title: Text(
          '${candidate.columnLabel} - ${_dateLabel(candidate.startsAt)}',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            alreadyExists
                ? 'Ja existe na agenda'
                : '${candidate.weekday} - ${_timeLabel(candidate.startsAt)} ate ${_timeLabel(candidate.endsAt)} (${candidate.durationLabel})',
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

class _ImportMessage extends StatelessWidget {
  const _ImportMessage({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoCandidatesCard extends StatelessWidget {
  const _NoCandidatesCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: const Text(
        'Nenhum plantao encontrado. Tente informar o nome exatamente como aparece na escala, por exemplo apenas o primeiro nome.',
        style: TextStyle(color: AppColors.textSecondary, height: 1.35),
      ),
    );
  }
}

String _firstUsefulName(String value) {
  final terms = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((term) => term.length >= 3)
      .toList();
  return terms.isEmpty ? value.trim() : terms.first;
}

String _dateLabel(DateTime date) {
  return '${_two(date.day)}/${_two(date.month)}/${date.year}';
}

String _timeLabel(DateTime date) {
  return '${_two(date.hour)}:${_two(date.minute)}';
}

String _monthLabel(int month) => month.toString().padLeft(2, '0');

String _two(int value) => value.toString().padLeft(2, '0');
