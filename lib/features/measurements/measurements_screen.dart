import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/data/occurrence_repository.dart';
import '../../domain/models/measurement_record.dart';
import '../../domain/models/occurrence.dart';
import '../../features/photos/linked_photos_panel.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/operational_applicability_card.dart';

const _measurementUnits = ['m', 'cm', 'mm'];

const _measurementMethods = [
  _MeasurementMethodOption('trena', 'Trena', Icons.straighten_outlined),
  _MeasurementMethodOption(
    'trena_laser',
    'Trena laser',
    Icons.settings_input_component_outlined,
  ),
  _MeasurementMethodOption('estimado', 'Estimado', Icons.visibility_outlined),
  _MeasurementMethodOption('outro', 'Outro', Icons.more_horiz_outlined),
];

class MeasurementsScreen extends StatefulWidget {
  const MeasurementsScreen({
    required this.repository,
    required this.occurrenceId,
    super.key,
  });

  final OccurrenceRepository repository;
  final String occurrenceId;

  @override
  State<MeasurementsScreen> createState() => _MeasurementsScreenState();
}

class _MeasurementsScreenState extends State<MeasurementsScreen> {
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
              message: 'Nao foi possivel acessar as medicoes deste dossie.',
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Medicoes')),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 96),
              children: [
                _MeasurementsHeader(occurrence: occurrence),
                const SizedBox(height: 14),
                OperationalApplicabilityCard(
                  title: 'Medicoes na ocorrencia',
                  message:
                      'Use quando nao houve medicao manual relevante a registrar.',
                  notApplicable: occurrence.isNotApplicable(
                    OperationalItemIds.measurements,
                  ),
                  onChanged: (value) =>
                      widget.repository.setOperationalItemNotApplicable(
                        widget.occurrenceId,
                        OperationalItemIds.measurements,
                        value,
                      ),
                ),
                const SizedBox(height: 14),
                if (occurrence.measurements.isEmpty)
                  const EmptyState(
                    icon: Icons.straighten_outlined,
                    title: 'Nenhuma medicao registrada',
                    message:
                        'Adicione distancias coletadas em campo, como veiculo ate ponto de impacto ou largura da pista.',
                  )
                else
                  for (final measurement in occurrence.measurements) ...[
                    _MeasurementCard(
                      measurement: measurement,
                      onTap: () => _openEditor(measurement),
                      onDelete: () => _confirmDelete(measurement),
                    ),
                    const SizedBox(height: 10),
                  ],
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _creating ? null : _createMeasurement,
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

  Future<void> _createMeasurement() async {
    setState(() => _creating = true);
    try {
      final measurement = await widget.repository.createMeasurement(
        widget.occurrenceId,
      );
      if (!mounted || measurement == null) {
        return;
      }
      _openEditor(measurement);
    } finally {
      if (mounted) {
        setState(() => _creating = false);
      }
    }
  }

  void _openEditor(MeasurementRecord measurement) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _MeasurementEditorScreen(
          repository: widget.repository,
          occurrenceId: widget.occurrenceId,
          measurementId: measurement.id,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(MeasurementRecord measurement) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remover medicao?'),
          content: Text('${measurement.label} sera removida deste dossie.'),
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
      await widget.repository.removeMeasurement(
        widget.occurrenceId,
        measurement.id,
      );
    }
  }
}

class _MeasurementEditorScreen extends StatefulWidget {
  const _MeasurementEditorScreen({
    required this.repository,
    required this.occurrenceId,
    required this.measurementId,
  });

  final OccurrenceRepository repository;
  final String occurrenceId;
  final String measurementId;

  @override
  State<_MeasurementEditorScreen> createState() =>
      _MeasurementEditorScreenState();
}

class _MeasurementEditorScreenState extends State<_MeasurementEditorScreen> {
  final _labelController = TextEditingController();
  final _pointAController = TextEditingController();
  final _pointBController = TextEditingController();
  final _valueController = TextEditingController();
  final _noteController = TextEditingController();
  Timer? _saveTimer;
  String? _unit;
  String? _method;
  bool _initialized = false;
  String? _lastSavedSignature;

  @override
  void dispose() {
    _saveNow();
    _saveTimer?.cancel();
    _labelController.dispose();
    _pointAController.dispose();
    _pointBController.dispose();
    _valueController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.repository,
      builder: (context, _) {
        final occurrence = widget.repository.findById(widget.occurrenceId);
        final measurement = _findMeasurement(occurrence);
        if (measurement == null) {
          return const Scaffold(
            body: EmptyState(
              icon: Icons.error_outline,
              title: 'Medicao nao encontrada',
              message: 'O registro pode ter sido removido deste dossie.',
            ),
          );
        }
        _initialize(measurement);

        return Scaffold(
          appBar: AppBar(title: Text('Editar ${measurement.label}')),
          body: SafeArea(
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              children: [
                _EditorHeader(measurement: measurement),
                const SizedBox(height: 14),
                TextField(
                  controller: _labelController,
                  onChanged: _scheduleSave,
                  decoration: const InputDecoration(
                    labelText: 'Identificador',
                    prefixIcon: Icon(Icons.label_outline),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _pointAController,
                        onChanged: _scheduleSave,
                        decoration: const InputDecoration(
                          labelText: 'Ponto A',
                          prefixIcon: Icon(Icons.trip_origin_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _pointBController,
                        onChanged: _scheduleSave,
                        decoration: const InputDecoration(
                          labelText: 'Ponto B',
                          prefixIcon: Icon(Icons.place_outlined),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _valueController,
                        onChanged: _scheduleSave,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Valor',
                          prefixIcon: Icon(Icons.straighten_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _unit,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Unidade'),
                        items: _measurementUnits.map((unit) {
                          return DropdownMenuItem(
                            value: unit,
                            child: Text(unit),
                          );
                        }).toList(),
                        onChanged: (unit) {
                          if (unit == null) {
                            return;
                          }
                          setState(() => _unit = unit);
                          _saveNow();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _method,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Metodo',
                    prefixIcon: Icon(Icons.construction_outlined),
                  ),
                  items: _measurementMethods.map((method) {
                    return DropdownMenuItem(
                      value: method.code,
                      child: Row(
                        children: [
                          Icon(method.icon, color: AppColors.gold),
                          const SizedBox(width: 8),
                          Text(method.label),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (method) {
                    if (method == null) {
                      return;
                    }
                    setState(() => _method = method);
                    _saveNow();
                  },
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
                  linkedPhotoIds: measurement.photoIds,
                  onChanged: _setPhotoIds,
                ),
                const SizedBox(height: 14),
                _SketchLinksPanel(count: measurement.sketchElementIds.length),
              ],
            ),
          ),
        );
      },
    );
  }

  void _initialize(MeasurementRecord measurement) {
    if (_initialized) {
      return;
    }
    _labelController.text = measurement.label;
    _pointAController.text = measurement.pointA;
    _pointBController.text = measurement.pointB;
    _valueController.text = measurement.value == 0
        ? ''
        : _numberText(measurement.value);
    _noteController.text = measurement.note;
    _unit = _normalizedUnit(measurement.unit);
    _method = _normalizedMethod(measurement.method);
    _lastSavedSignature = _signature(measurement);
    _initialized = true;
  }

  MeasurementRecord? _findMeasurement([FieldOccurrence? occurrence]) {
    occurrence ??= widget.repository.findById(widget.occurrenceId);
    if (occurrence == null) {
      return null;
    }
    for (final measurement in occurrence.measurements) {
      if (measurement.id == widget.measurementId) {
        return measurement;
      }
    }
    return null;
  }

  Future<void> _setPhotoIds(List<String> photoIds) async {
    _saveTimer?.cancel();
    final current = _findMeasurement();
    if (current == null || !_initialized) {
      return;
    }
    final updated = _editedMeasurement(current, photoIds: _uniqueIds(photoIds));
    _lastSavedSignature = _signature(updated);
    await widget.repository.updateMeasurement(widget.occurrenceId, updated);
  }

  void _scheduleSave(String _) {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 450), _saveNow);
  }

  void _saveNow() {
    _saveTimer?.cancel();
    final current = _findMeasurement();
    if (current == null || !_initialized) {
      return;
    }
    final updated = _editedMeasurement(current);
    final signature = _signature(updated);
    if (_lastSavedSignature == signature) {
      return;
    }
    _lastSavedSignature = signature;
    unawaited(
      widget.repository.updateMeasurement(widget.occurrenceId, updated),
    );
  }

  MeasurementRecord _editedMeasurement(
    MeasurementRecord current, {
    List<String>? photoIds,
  }) {
    return MeasurementRecord(
      id: current.id,
      label: _labelController.text.trim().isEmpty
          ? current.label
          : _labelController.text.trim(),
      pointA: _pointAController.text.trim(),
      pointB: _pointBController.text.trim(),
      value: _parseNumber(_valueController.text) ?? 0,
      unit: _unit ?? current.unit,
      method: _method ?? current.method,
      note: _noteController.text.trim(),
      photoIds: photoIds ?? current.photoIds,
      sketchElementIds: current.sketchElementIds,
    );
  }
}

class _MeasurementsHeader extends StatelessWidget {
  const _MeasurementsHeader({required this.occurrence});

  final FieldOccurrence occurrence;

  @override
  Widget build(BuildContext context) {
    final withValue = occurrence.measurements
        .where((measurement) => measurement.value > 0)
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
          const Icon(Icons.straighten_outlined, color: AppColors.gold),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${occurrence.measurements.length} medicao(oes)',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '$withValue com valor preenchido',
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

class _MeasurementCard extends StatelessWidget {
  const _MeasurementCard({
    required this.measurement,
    required this.onTap,
    required this.onDelete,
  });

  final MeasurementRecord measurement;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
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
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.panel,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Icon(
                      Icons.straighten_outlined,
                      color: AppColors.gold,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          measurement.label,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _routeLabel(measurement),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remover medicao',
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                    color: AppColors.danger,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoChip(
                    icon: Icons.straighten_outlined,
                    label: _valueLabel(measurement),
                  ),
                  _InfoChip(
                    icon: Icons.construction_outlined,
                    label: _methodLabel(measurement.method),
                  ),
                  _InfoChip(
                    icon: Icons.photo_outlined,
                    label: '${measurement.photoIds.length} foto(s)',
                  ),
                  _InfoChip(
                    icon: Icons.architecture_outlined,
                    label: '${measurement.sketchElementIds.length} croqui',
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
  const _EditorHeader({required this.measurement});

  final MeasurementRecord measurement;

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
          const Icon(Icons.straighten_outlined, color: AppColors.gold),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${measurement.label} - ${_valueLabel(measurement)}',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _SketchLinksPanel extends StatelessWidget {
  const _SketchLinksPanel({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vinculos futuros',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(
                icon: Icons.architecture_outlined,
                label: '$count croqui',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

List<String> _uniqueIds(List<String> ids) {
  return ids.toSet().toList(growable: false);
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

class _MeasurementMethodOption {
  const _MeasurementMethodOption(this.code, this.label, this.icon);

  final String code;
  final String label;
  final IconData icon;
}

String _normalizedUnit(String value) {
  if (_measurementUnits.contains(value)) {
    return value;
  }
  return 'm';
}

String _normalizedMethod(String value) {
  for (final method in _measurementMethods) {
    if (method.code == value) {
      return method.code;
    }
  }
  return 'trena';
}

String _methodLabel(String code) {
  for (final method in _measurementMethods) {
    if (method.code == code) {
      return method.label;
    }
  }
  return 'Outro';
}

String _routeLabel(MeasurementRecord measurement) {
  if (measurement.pointA.isEmpty && measurement.pointB.isEmpty) {
    return 'Pontos ainda nao informados';
  }
  if (measurement.pointA.isNotEmpty && measurement.pointB.isNotEmpty) {
    return '${measurement.pointA} ate ${measurement.pointB}';
  }
  if (measurement.pointA.isNotEmpty) {
    return 'A partir de ${measurement.pointA}';
  }
  return 'Ate ${measurement.pointB}';
}

String _valueLabel(MeasurementRecord measurement) {
  if (measurement.value <= 0) {
    return 'Valor pendente';
  }
  return '${_numberText(measurement.value)} ${measurement.unit}';
}

String _numberText(double value) {
  final fixed = value.toStringAsFixed(2);
  return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
}

double? _parseNumber(String value) {
  final normalized = value.trim().replaceAll(',', '.');
  if (normalized.isEmpty) {
    return null;
  }
  return double.tryParse(normalized);
}

String _signature(MeasurementRecord measurement) {
  return [
    measurement.label,
    measurement.pointA,
    measurement.pointB,
    measurement.value.toString(),
    measurement.unit,
    measurement.method,
    measurement.note,
    measurement.photoIds.join(','),
    measurement.sketchElementIds.join(','),
  ].join('|');
}
