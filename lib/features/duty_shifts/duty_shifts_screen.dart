import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/data/app_settings_repository.dart';
import '../../core/data/duty_shift_repository.dart';
import '../../core/services/duty_shift_notification_service.dart';
import '../../domain/models/app_settings.dart';
import '../../domain/models/duty_shift.dart';
import 'duty_shift_schedule_import_screen.dart';

class DutyShiftsScreen extends StatelessWidget {
  const DutyShiftsScreen({
    required this.repository,
    required this.settingsRepository,
    this.notificationService,
    super.key,
  });

  final DutyShiftRepository repository;
  final AppSettingsRepository settingsRepository;
  final DutyShiftNotificationService? notificationService;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: repository,
      builder: (context, _) {
        final shifts = repository.shifts;
        final now = DateTime.now();
        final current = shifts
            .where((shift) => shift.statusAt(now) == DutyShiftStatus.inProgress)
            .toList();
        final upcoming = shifts
            .where((shift) => shift.statusAt(now) == DutyShiftStatus.upcoming)
            .toList();
        final finished =
            shifts
                .where(
                  (shift) => shift.statusAt(now) == DutyShiftStatus.finished,
                )
                .toList()
              ..sort((a, b) => b.startsAt.compareTo(a.startsAt));

        return Scaffold(
          appBar: AppBar(
            title: const Text('Agenda de plantoes'),
            actions: [
              IconButton(
                tooltip: 'Importar escala PDF',
                onPressed: () => _openImport(context),
                icon: const Icon(Icons.picture_as_pdf_outlined),
              ),
              IconButton(
                tooltip: 'Adicionar plantao',
                onPressed: () => _openForm(context),
                icon: const Icon(Icons.add_alarm_outlined),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openForm(context),
            icon: const Icon(Icons.add),
            label: const Text('Novo plantao'),
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              children: [
                _DutyShiftIntro(onImport: () => _openImport(context)),
                if (shifts.isEmpty)
                  const _EmptyDutyShifts()
                else ...[
                  if (current.isNotEmpty)
                    _DutyShiftSection(
                      title: 'Em andamento',
                      shifts: current,
                      statusColor: AppColors.success,
                      onEdit: (shift) => _openForm(context, shift: shift),
                    ),
                  if (upcoming.isNotEmpty)
                    _DutyShiftSection(
                      title: 'Proximos plantoes',
                      shifts: upcoming,
                      statusColor: AppColors.gold,
                      onEdit: (shift) => _openForm(context, shift: shift),
                    ),
                  if (finished.isNotEmpty)
                    _DutyShiftSection(
                      title: 'Historico',
                      shifts: finished,
                      statusColor: AppColors.textSecondary,
                      onEdit: (shift) => _openForm(context, shift: shift),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _openForm(BuildContext context, {DutyShift? shift}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DutyShiftFormScreen(
          repository: repository,
          notificationService: notificationService,
          shift: shift,
        ),
      ),
    );
  }

  void _openImport(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DutyShiftScheduleImportScreen(
          repository: repository,
          notificationService: notificationService,
          initialExpertName: settingsRepository.settings.profile.name,
        ),
      ),
    );
  }
}

class DutyShiftFormScreen extends StatefulWidget {
  const DutyShiftFormScreen({
    required this.repository,
    this.notificationService,
    this.shift,
    super.key,
  });

  final DutyShiftRepository repository;
  final DutyShiftNotificationService? notificationService;
  final DutyShift? shift;

  @override
  State<DutyShiftFormScreen> createState() => _DutyShiftFormScreenState();
}

class _DutyShiftFormScreenState extends State<DutyShiftFormScreen> {
  late DutyShift _draft;
  late final TextEditingController _titleController;
  late final TextEditingController _unitController;
  late final TextEditingController _teamController;
  late final TextEditingController _notesController;
  late ForensicArea _area;
  late DateTime _startsAt;
  late DateTime _endsAt;
  late bool _remindDayBefore;
  late bool _remindTwoHoursBefore;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _draft = widget.shift ?? widget.repository.createDraft();
    _titleController = TextEditingController(text: _draft.title);
    _unitController = TextEditingController(text: _draft.unit);
    _teamController = TextEditingController(text: _draft.team);
    _notesController = TextEditingController(text: _draft.notes);
    _area = _draft.area;
    _startsAt = _draft.startsAt;
    _endsAt = _draft.endsAt;
    _remindDayBefore = _draft.remindDayBefore;
    _remindTwoHoursBefore = _draft.remindTwoHoursBefore;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _unitController.dispose();
    _teamController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.shift != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Editar plantao' : 'Novo plantao'),
        actions: [
          if (editing)
            IconButton(
              tooltip: 'Excluir plantao',
              onPressed: _saving ? null : _confirmDelete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            TextField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Escala / titulo',
                hintText: 'Ex.: Transito I, Local de crime, Sobreaviso',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ForensicArea>(
              initialValue: _area,
              decoration: const InputDecoration(labelText: 'Area'),
              items: [
                for (final area in ForensicArea.values)
                  DropdownMenuItem(value: area, child: Text(area.label)),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _area = value);
                }
              },
            ),
            const SizedBox(height: 12),
            _DateTimeField(
              label: 'Inicio',
              value: _startsAt,
              onChanged: (date) {
                setState(() {
                  final previousDuration = _endsAt.difference(_startsAt);
                  _startsAt = date;
                  _endsAt = date.add(
                    previousDuration.isNegative ||
                            previousDuration.inMinutes < 1
                        ? const Duration(hours: 12)
                        : previousDuration,
                  );
                });
              },
            ),
            const SizedBox(height: 12),
            _DateTimeField(
              label: 'Fim',
              value: _endsAt,
              onChanged: (date) => setState(() => _endsAt = date),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _unitController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Unidade / setor',
                hintText: 'Ex.: Departamento de Criminalistica',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _teamController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Equipe / observacao curta',
                hintText: 'Ex.: dupla, motorista, equipe de apoio',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              minLines: 3,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Observacoes'),
            ),
            const SizedBox(height: 12),
            _ReminderSwitch(
              title: 'Lembrar 24h antes',
              value: _remindDayBefore,
              onChanged: (value) => setState(() => _remindDayBefore = value),
            ),
            const SizedBox(height: 8),
            _ReminderSwitch(
              title: 'Lembrar 2h antes',
              value: _remindTwoHoursBefore,
              onChanged: (value) =>
                  setState(() => _remindTwoHoursBefore = value),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(_saving ? 'Salvando...' : 'Salvar plantao'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_endsAt.isAfter(_startsAt)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('O fim do plantao deve ser apos o inicio.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final updated = _draft.copyWith(
        title: _titleController.text.trim(),
        area: _area,
        startsAt: _startsAt,
        endsAt: _endsAt,
        unit: _unitController.text.trim(),
        team: _teamController.text.trim(),
        notes: _notesController.text.trim(),
        remindDayBefore: _remindDayBefore,
        remindTwoHoursBefore: _remindTwoHoursBefore,
      );
      await widget.repository.saveShift(updated);
      await widget.notificationService?.requestPermission();
      await widget.notificationService?.rescheduleAll(widget.repository.shifts);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plantao salvo com sucesso.')),
      );
      Navigator.of(context).pop();
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir plantao?'),
        content: const Text(
          'Esta acao remove o plantao da agenda local e cancela os lembretes associados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.repository.deleteShift(_draft.id);
      await widget.notificationService?.rescheduleAll(widget.repository.shifts);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Plantao excluido.')));
      Navigator.of(context).pop();
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}

class _DutyShiftIntro extends StatelessWidget {
  const _DutyShiftIntro({required this.onImport});

  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.event_available_outlined, color: AppColors.gold),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Cadastre seus plantoes e deixe o SICRO avisar antes da escala. Tudo fica local no aparelho.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onImport,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Importar escala PDF'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDutyShifts extends StatelessWidget {
  const _EmptyDutyShifts();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        children: [
          Icon(Icons.alarm_add_outlined, color: AppColors.gold, size: 36),
          SizedBox(height: 12),
          Text(
            'Nenhum plantao cadastrado',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
          ),
          SizedBox(height: 6),
          Text(
            'Adicione sua proxima escala para acompanhar datas, horarios e receber lembretes locais.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _DutyShiftSection extends StatelessWidget {
  const _DutyShiftSection({
    required this.title,
    required this.shifts,
    required this.statusColor,
    required this.onEdit,
  });

  final String title;
  final List<DutyShift> shifts;
  final Color statusColor;
  final ValueChanged<DutyShift> onEdit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              title.toUpperCase(),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ),
          for (final shift in shifts)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _DutyShiftCard(
                shift: shift,
                statusColor: statusColor,
                onTap: () => onEdit(shift),
              ),
            ),
        ],
      ),
    );
  }
}

class _DutyShiftCard extends StatelessWidget {
  const _DutyShiftCard({
    required this.shift,
    required this.statusColor,
    required this.onTap,
  });

  final DutyShift shift;
  final Color statusColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final status = shift.statusAt(now);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: statusColor.withValues(alpha: 0.45)),
              ),
              child: Icon(Icons.event_note_outlined, color: statusColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shift.displayTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${shift.area.label} - ${_dateTimeLabel(shift.startsAt)} ate ${_timeLabel(shift.endsAt)}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (shift.unit.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      shift.unit.trim(),
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _MiniChip(label: status.label, color: statusColor),
                      _MiniChip(
                        label: _durationLabel(shift.duration),
                        color: AppColors.textSecondary,
                      ),
                      if (shift.remindDayBefore || shift.remindTwoHoursBefore)
                        const _MiniChip(
                          label: 'lembrete ativo',
                          color: AppColors.gold,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.more_vert, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _DateTimeField extends StatelessWidget {
  const _DateTimeField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => _pick(context),
      icon: const Icon(Icons.schedule_outlined),
      label: Align(
        alignment: Alignment.centerLeft,
        child: Text('$label: ${_dateTimeLabel(value)}'),
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        alignment: Alignment.centerLeft,
      ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: value,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (date == null || !context.mounted) {
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(value),
    );
    if (time == null) {
      return;
    }
    onChanged(
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }
}

class _ReminderSwitch extends StatelessWidget {
  const _ReminderSwitch({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: const Text(
        'Notificacao local no aparelho.',
        style: TextStyle(color: AppColors.textSecondary),
      ),
      tileColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.border),
      ),
    );
  }
}

String _dateTimeLabel(DateTime date) {
  return '${_two(date.day)}/${_two(date.month)}/${date.year} ${_timeLabel(date)}';
}

String _timeLabel(DateTime date) {
  return '${_two(date.hour)}:${_two(date.minute)}';
}

String _durationLabel(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours <= 0) {
    return '${minutes}min';
  }
  if (minutes == 0) {
    return '${hours}h';
  }
  return '${hours}h${_two(minutes)}';
}

String _two(int value) => value.toString().padLeft(2, '0');
