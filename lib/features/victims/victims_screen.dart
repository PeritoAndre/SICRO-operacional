import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/data/occurrence_repository.dart';
import '../../domain/models/forensic_case_metadata.dart';
import '../../domain/models/occurrence.dart';
import '../../domain/models/victim_record.dart';
import '../../features/photos/linked_photos_panel.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/operational_applicability_card.dart';

class VictimsScreen extends StatefulWidget {
  const VictimsScreen({
    required this.repository,
    required this.occurrenceId,
    super.key,
  });

  final OccurrenceRepository repository;
  final String occurrenceId;

  @override
  State<VictimsScreen> createState() => _VictimsScreenState();
}

class _VictimsScreenState extends State<VictimsScreen> {
  bool _creating = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.repository,
      builder: (context, _) {
        final occurrence = widget.repository.findById(widget.occurrenceId);
        if (occurrence == null) {
          return const Scaffold(
            body: EmptyState(
              icon: Icons.error_outline,
              title: 'Ocorrencia nao encontrada',
              message: 'Nao foi possivel acessar as vitimas deste dossie.',
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(title: Text(_screenTitle(occurrence))),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 96),
              children: [
                _VictimsHeader(occurrence: occurrence),
                const SizedBox(height: 14),
                OperationalApplicabilityCard(
                  title:
                      occurrence.metadata.type == ForensicCaseType.violentDeath
                      ? 'Vitimas/corpos na ocorrencia'
                      : 'Vitimas na ocorrencia',
                  message:
                      occurrence.metadata.type == ForensicCaseType.violentDeath
                      ? 'Use apenas se nao havia corpo ou vitima a registrar no dossie.'
                      : 'Use quando nao houve vitima a registrar nesta ocorrencia.',
                  notApplicable: occurrence.isNotApplicable(
                    OperationalItemIds.victims,
                  ),
                  onChanged: (value) =>
                      widget.repository.setOperationalItemNotApplicable(
                        widget.occurrenceId,
                        OperationalItemIds.victims,
                        value,
                      ),
                ),
                const SizedBox(height: 14),
                if (occurrence.victims.isEmpty)
                  EmptyState(
                    icon: Icons.personal_injury_outlined,
                    title:
                        occurrence.metadata.type ==
                            ForensicCaseType.violentDeath
                        ? 'Nenhum corpo/vitima registrado'
                        : 'Nenhuma vitima registrada',
                    message:
                        occurrence.metadata.type ==
                            ForensicCaseType.violentDeath
                        ? 'Registre identificacao, remocao, posicao corporal, vestes, lesoes aparentes e fotos quando aplicavel.'
                        : 'Adicione pessoas envolvidas para registrar condicao, remocao, destino, posicao corporal e fotos.',
                  )
                else
                  for (final victim in occurrence.victims) ...[
                    _VictimCard(
                      victim: victim,
                      onTap: () => _openEditor(victim),
                      onDelete: () => _confirmDelete(victim),
                    ),
                    const SizedBox(height: 10),
                  ],
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _creating ? null : _createVictim,
            icon: _creating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add),
            label: const Text('Adicionar'),
          ),
        );
      },
    );
  }

  Future<void> _createVictim() async {
    setState(() => _creating = true);
    try {
      final victim = await widget.repository.createVictim(widget.occurrenceId);
      if (!mounted || victim == null) {
        return;
      }
      _openEditor(victim);
    } finally {
      if (mounted) {
        setState(() => _creating = false);
      }
    }
  }

  void _openEditor(VictimRecord victim) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _VictimEditorScreen(
          repository: widget.repository,
          occurrenceId: widget.occurrenceId,
          victimId: victim.id,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(VictimRecord victim) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remover vitima?'),
          content: Text('${victim.identifier} sera removida deste dossie.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Remover'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await widget.repository.removeVictim(widget.occurrenceId, victim.id);
    }
  }
}

String _screenTitle(FieldOccurrence occurrence) {
  return occurrence.metadata.type == ForensicCaseType.violentDeath
      ? 'Vitimas/Corpos'
      : 'Vitimas';
}

class _VictimEditorScreen extends StatefulWidget {
  const _VictimEditorScreen({
    required this.repository,
    required this.occurrenceId,
    required this.victimId,
  });

  final OccurrenceRepository repository;
  final String occurrenceId;
  final String victimId;

  @override
  State<_VictimEditorScreen> createState() => _VictimEditorScreenState();
}

class _VictimEditorScreenState extends State<_VictimEditorScreen> {
  final _identifierController = TextEditingController();
  final _nameController = TextEditingController();
  final _rescuedByController = TextEditingController();
  final _destinationController = TextEditingController();
  final _removedAtController = TextEditingController();
  final _bodyPositionController = TextEditingController();
  final _protectiveEquipmentController = TextEditingController();
  final _noteController = TextEditingController();
  Timer? _saveTimer;
  VictimCondition _condition = VictimCondition.unknown;
  VictimType _type = VictimType.other;
  VictimRemovalStatus _removalStatus = VictimRemovalStatus.unknown;
  bool _initialized = false;
  String? _lastSavedSignature;

  @override
  void dispose() {
    _saveNow();
    _saveTimer?.cancel();
    _identifierController.dispose();
    _nameController.dispose();
    _rescuedByController.dispose();
    _destinationController.dispose();
    _removedAtController.dispose();
    _bodyPositionController.dispose();
    _protectiveEquipmentController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.repository,
      builder: (context, _) {
        final occurrence = widget.repository.findById(widget.occurrenceId);
        final victim = _findVictim(occurrence);
        if (victim == null) {
          return const Scaffold(
            body: EmptyState(
              icon: Icons.error_outline,
              title: 'Vitima nao encontrada',
              message: 'O registro pode ter sido removido deste dossie.',
            ),
          );
        }
        _initialize(victim);

        return Scaffold(
          appBar: AppBar(title: Text('Editar ${victim.identifier}')),
          body: SafeArea(
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              children: [
                _EditorHeader(victim: victim),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _identifierController,
                        onChanged: _scheduleSave,
                        decoration: const InputDecoration(
                          labelText: 'Identificador',
                          prefixIcon: Icon(Icons.label_outline),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _nameController,
                        onChanged: _scheduleSave,
                        decoration: const InputDecoration(
                          labelText: 'Nome, se conhecido',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<VictimCondition>(
                  initialValue: _condition,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Condicao',
                    prefixIcon: Icon(Icons.medical_information_outlined),
                  ),
                  items: VictimCondition.values.map((condition) {
                    return DropdownMenuItem(
                      value: condition,
                      child: Text(condition.label),
                    );
                  }).toList(),
                  onChanged: (condition) {
                    if (condition == null) {
                      return;
                    }
                    setState(() => _condition = condition);
                    _saveNow();
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<VictimType>(
                  initialValue: _type,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Tipo',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  items: VictimType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type.label),
                    );
                  }).toList(),
                  onChanged: (type) {
                    if (type == null) {
                      return;
                    }
                    setState(() => _type = type);
                    _saveNow();
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<VictimRemovalStatus>(
                  initialValue: _removalStatus,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Removida do local',
                    prefixIcon: Icon(Icons.local_hospital_outlined),
                  ),
                  items: VictimRemovalStatus.values.map((status) {
                    return DropdownMenuItem(
                      value: status,
                      child: Text(status.label),
                    );
                  }).toList(),
                  onChanged: (status) {
                    if (status == null) {
                      return;
                    }
                    setState(() => _removalStatus = status);
                    _saveNow();
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _rescuedByController,
                  onChanged: _scheduleSave,
                  decoration: const InputDecoration(
                    labelText: 'Socorrida por',
                    prefixIcon: Icon(Icons.health_and_safety_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _destinationController,
                  onChanged: _scheduleSave,
                  decoration: const InputDecoration(
                    labelText: 'Hospital / destino',
                    prefixIcon: Icon(Icons.location_city_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _removedAtController,
                  onChanged: _scheduleSave,
                  keyboardType: TextInputType.datetime,
                  decoration: const InputDecoration(
                    labelText: 'Horario aproximado de remocao',
                    hintText: 'Ex.: 14:35 ou 19/05/2026 14:35',
                    prefixIcon: Icon(Icons.schedule_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _bodyPositionController,
                  onChanged: _scheduleSave,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Posicao corporal descrita',
                    prefixIcon: Icon(Icons.accessibility_new_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _protectiveEquipmentController,
                  onChanged: _scheduleSave,
                  decoration: const InputDecoration(
                    labelText: 'Uso de capacete / EPI',
                    prefixIcon: Icon(Icons.shield_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _noteController,
                  onChanged: _scheduleSave,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Observacoes',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                LinkedPhotosPanel(
                  title: 'Fotos vinculadas',
                  allPhotos: occurrence!.photos,
                  linkedPhotoIds: victim.photoIds,
                  onChanged: _setPhotoIds,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _initialize(VictimRecord victim) {
    if (_initialized) {
      return;
    }
    _identifierController.text = victim.identifier;
    _nameController.text = victim.name;
    _rescuedByController.text = victim.rescuedBy;
    _destinationController.text = victim.destination;
    _removedAtController.text = _dateInputLabel(victim.removedAt);
    _bodyPositionController.text = victim.bodyPosition;
    _protectiveEquipmentController.text = victim.protectiveEquipment;
    _noteController.text = victim.note;
    _condition = victim.condition;
    _type = victim.type;
    _removalStatus = victim.removalStatus;
    _lastSavedSignature = _signature(victim);
    _initialized = true;
  }

  VictimRecord? _findVictim([FieldOccurrence? occurrence]) {
    occurrence ??= widget.repository.findById(widget.occurrenceId);
    if (occurrence == null) {
      return null;
    }
    for (final victim in occurrence.victims) {
      if (victim.id == widget.victimId) {
        return victim;
      }
    }
    return null;
  }

  Future<void> _setPhotoIds(List<String> photoIds) async {
    _saveTimer?.cancel();
    final current = _findVictim();
    if (current == null || !_initialized) {
      return;
    }
    final updated = _editedVictim(current, photoIds: _uniqueIds(photoIds));
    _lastSavedSignature = _signature(updated);
    await widget.repository.updateVictim(widget.occurrenceId, updated);
  }

  void _scheduleSave(String _) {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 450), _saveNow);
  }

  void _saveNow() {
    _saveTimer?.cancel();
    final current = _findVictim();
    if (current == null || !_initialized) {
      return;
    }
    final updated = _editedVictim(current);
    final signature = _signature(updated);
    if (_lastSavedSignature == signature) {
      return;
    }
    _lastSavedSignature = signature;
    unawaited(widget.repository.updateVictim(widget.occurrenceId, updated));
  }

  VictimRecord _editedVictim(VictimRecord current, {List<String>? photoIds}) {
    return VictimRecord(
      id: current.id,
      identifier: _identifierController.text.trim().isEmpty
          ? current.identifier
          : _identifierController.text.trim(),
      name: _nameController.text.trim(),
      condition: _condition,
      type: _type,
      removalStatus: _removalStatus,
      rescuedBy: _rescuedByController.text.trim(),
      destination: _destinationController.text.trim(),
      removedAt: _parseDateTime(_removedAtController.text),
      bodyPosition: _bodyPositionController.text.trim(),
      protectiveEquipment: _protectiveEquipmentController.text.trim(),
      note: _noteController.text.trim(),
      photoIds: photoIds ?? current.photoIds,
    );
  }
}

class _VictimsHeader extends StatelessWidget {
  const _VictimsHeader({required this.occurrence});

  final FieldOccurrence occurrence;

  @override
  Widget build(BuildContext context) {
    final severe = occurrence.victims
        .where(
          (victim) =>
              victim.condition == VictimCondition.injured ||
              victim.condition == VictimCondition.death,
        )
        .length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.personal_injury_outlined, color: AppColors.gold),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${occurrence.victims.length} vitima(s)',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '$severe lesionada(s)/obito(s)',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VictimCard extends StatelessWidget {
  const _VictimCard({
    required this.victim,
    required this.onTap,
    required this.onDelete,
  });

  final VictimRecord victim;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final color = _conditionColor(victim.condition);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: color, width: 4)),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.personal_injury_outlined,
                    color: AppColors.gold,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _title(victim),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  _ConditionBadge(condition: victim.condition),
                  IconButton(
                    tooltip: 'Remover vitima',
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                    color: AppColors.danger,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _subtitle(victim),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoChip(
                    icon: Icons.badge_outlined,
                    label: victim.type.label,
                  ),
                  _InfoChip(
                    icon: Icons.local_hospital_outlined,
                    label: 'Removida: ${victim.removalStatus.label}',
                  ),
                  _InfoChip(
                    icon: Icons.photo_outlined,
                    label: '${victim.photoIds.length} foto(s)',
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

class _EditorHeader extends StatelessWidget {
  const _EditorHeader({required this.victim});

  final VictimRecord victim;

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
          const Icon(Icons.personal_injury_outlined, color: AppColors.gold),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title(victim),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '${victim.type.label} - ${victim.removalStatus.label}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          _ConditionBadge(condition: victim.condition),
        ],
      ),
    );
  }
}

class _ConditionBadge extends StatelessWidget {
  const _ConditionBadge({required this.condition});

  final VictimCondition condition;

  @override
  Widget build(BuildContext context) {
    final color = _conditionColor(condition);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Text(
        condition.label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.gold),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.62,
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Color _conditionColor(VictimCondition condition) {
  return switch (condition) {
    VictimCondition.unharmed => AppColors.success,
    VictimCondition.injured => AppColors.gold,
    VictimCondition.death => AppColors.danger,
    VictimCondition.unknown => AppColors.textSecondary,
  };
}

String _title(VictimRecord victim) {
  if (victim.name.isEmpty) {
    return '${victim.identifier} - nome nao informado';
  }
  return '${victim.identifier} - ${victim.name}';
}

String _subtitle(VictimRecord victim) {
  final parts = [
    if (victim.destination.isNotEmpty) victim.destination,
    if (victim.bodyPosition.isNotEmpty) victim.bodyPosition,
    if (victim.note.isNotEmpty) victim.note,
  ];
  return parts.isEmpty ? 'Sem detalhes adicionais' : parts.join(' - ');
}

String _dateInputLabel(DateTime? value) {
  if (value == null) {
    return '';
  }
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}

DateTime? _parseDateTime(String value) {
  final text = value.trim();
  if (text.isEmpty) {
    return null;
  }
  final now = DateTime.now();
  final timeMatch = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(text);
  if (timeMatch != null) {
    final hour = int.tryParse(timeMatch.group(1) ?? '');
    final minute = int.tryParse(timeMatch.group(2) ?? '');
    if (hour != null && minute != null && hour < 24 && minute < 60) {
      return DateTime(now.year, now.month, now.day, hour, minute);
    }
  }
  final fullMatch = RegExp(
    r'^(\d{1,2})/(\d{1,2})/(\d{4})\s+(\d{1,2}):(\d{2})$',
  ).firstMatch(text);
  if (fullMatch != null) {
    final day = int.tryParse(fullMatch.group(1) ?? '');
    final month = int.tryParse(fullMatch.group(2) ?? '');
    final year = int.tryParse(fullMatch.group(3) ?? '');
    final hour = int.tryParse(fullMatch.group(4) ?? '');
    final minute = int.tryParse(fullMatch.group(5) ?? '');
    if (day != null &&
        month != null &&
        year != null &&
        hour != null &&
        minute != null) {
      return DateTime(year, month, day, hour, minute);
    }
  }
  return DateTime.tryParse(text);
}

String _signature(VictimRecord victim) {
  return [
    victim.identifier,
    victim.name,
    victim.condition.code,
    victim.type.code,
    victim.removalStatus.code,
    victim.rescuedBy,
    victim.destination,
    victim.removedAt?.toIso8601String() ?? '',
    victim.bodyPosition,
    victim.protectiveEquipment,
    victim.note,
    victim.photoIds.join(','),
  ].join('|');
}

List<String> _uniqueIds(List<String> ids) {
  return ids.toSet().toList(growable: false);
}
