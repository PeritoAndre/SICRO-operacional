import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/data/occurrence_repository.dart';
import '../../domain/models/occurrence.dart';
import '../../domain/models/vehicle_record.dart';
import '../../features/photos/linked_photos_panel.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/operational_applicability_card.dart';

class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({
    required this.repository,
    required this.occurrenceId,
    super.key,
  });

  final OccurrenceRepository repository;
  final String occurrenceId;

  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
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
              message: 'Nao foi possivel acessar os veiculos deste dossie.',
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Veiculos')),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 96),
              children: [
                _VehiclesHeader(occurrence: occurrence),
                const SizedBox(height: 14),
                OperationalApplicabilityCard(
                  title: 'Veiculos na ocorrencia',
                  message:
                      'Use quando nao havia veiculo no local ou a coleta foi apenas documental.',
                  notApplicable: occurrence.isNotApplicable(
                    OperationalItemIds.vehicles,
                  ),
                  onChanged: (value) =>
                      widget.repository.setOperationalItemNotApplicable(
                        widget.occurrenceId,
                        OperationalItemIds.vehicles,
                        value,
                      ),
                ),
                const SizedBox(height: 14),
                if (occurrence.vehicles.isEmpty)
                  const EmptyState(
                    icon: Icons.directions_car_outlined,
                    title: 'Nenhum veiculo registrado',
                    message:
                        'Adicione veiculos envolvidos para registrar placa, ponto de impacto, avarias, posicao final e fotos vinculadas.',
                  )
                else
                  for (final vehicle in occurrence.vehicles) ...[
                    _VehicleCard(
                      vehicle: vehicle,
                      onTap: () => _openEditor(vehicle),
                      onDelete: () => _confirmDelete(vehicle),
                    ),
                    const SizedBox(height: 10),
                  ],
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _creating ? null : _createVehicle,
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

  Future<void> _createVehicle() async {
    setState(() => _creating = true);
    try {
      final vehicle = await widget.repository.createVehicle(
        widget.occurrenceId,
      );
      if (!mounted || vehicle == null) {
        return;
      }
      _openEditor(vehicle);
    } finally {
      if (mounted) {
        setState(() => _creating = false);
      }
    }
  }

  void _openEditor(VehicleRecord vehicle) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _VehicleEditorScreen(
          repository: widget.repository,
          occurrenceId: widget.occurrenceId,
          vehicleId: vehicle.id,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(VehicleRecord vehicle) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remover veiculo?'),
          content: Text('${vehicle.identifier} sera removido deste dossie.'),
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
      await widget.repository.removeVehicle(widget.occurrenceId, vehicle.id);
    }
  }
}

class _VehicleEditorScreen extends StatefulWidget {
  const _VehicleEditorScreen({
    required this.repository,
    required this.occurrenceId,
    required this.vehicleId,
  });

  final OccurrenceRepository repository;
  final String occurrenceId;
  final String vehicleId;

  @override
  State<_VehicleEditorScreen> createState() => _VehicleEditorScreenState();
}

class _VehicleEditorScreenState extends State<_VehicleEditorScreen> {
  final _identifierController = TextEditingController();
  final _plateController = TextEditingController();
  final _typeController = TextEditingController();
  final _modelController = TextEditingController();
  final _colorController = TextEditingController();
  final _trafficDirectionController = TextEditingController();
  final _finalPositionController = TextEditingController();
  final _impactPointController = TextEditingController();
  final _damageController = TextEditingController();
  final _driverController = TextEditingController();
  final _ownerController = TextEditingController();
  final _noteController = TextEditingController();
  Timer? _saveTimer;
  bool _initialized = false;
  String? _lastSavedSignature;

  @override
  void dispose() {
    _saveNow();
    _saveTimer?.cancel();
    _identifierController.dispose();
    _plateController.dispose();
    _typeController.dispose();
    _modelController.dispose();
    _colorController.dispose();
    _trafficDirectionController.dispose();
    _finalPositionController.dispose();
    _impactPointController.dispose();
    _damageController.dispose();
    _driverController.dispose();
    _ownerController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.repository,
      builder: (context, _) {
        final occurrence = widget.repository.findById(widget.occurrenceId);
        final vehicle = _findVehicle(occurrence);
        if (vehicle == null) {
          return const Scaffold(
            body: EmptyState(
              icon: Icons.error_outline,
              title: 'Veiculo nao encontrado',
              message: 'O registro pode ter sido removido deste dossie.',
            ),
          );
        }
        _initialize(vehicle);

        return Scaffold(
          appBar: AppBar(title: Text('Editar ${vehicle.identifier}')),
          body: SafeArea(
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              children: [
                _EditorHeader(vehicle: vehicle),
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
                      child: TextField(
                        controller: _plateController,
                        onChanged: _scheduleSave,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Placa',
                          prefixIcon: Icon(Icons.pin_outlined),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _modelController,
                  onChanged: _scheduleSave,
                  decoration: const InputDecoration(
                    labelText: 'Modelo',
                    prefixIcon: Icon(Icons.directions_car_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _typeController,
                        onChanged: _scheduleSave,
                        decoration: const InputDecoration(labelText: 'Tipo'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _colorController,
                        onChanged: _scheduleSave,
                        decoration: const InputDecoration(labelText: 'Cor'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _trafficDirectionController,
                  onChanged: _scheduleSave,
                  decoration: const InputDecoration(
                    labelText: 'Sentido de trafego',
                    prefixIcon: Icon(Icons.explore_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _finalPositionController,
                  onChanged: _scheduleSave,
                  decoration: const InputDecoration(
                    labelText: 'Posicao final',
                    prefixIcon: Icon(Icons.place_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _impactPointController,
                  onChanged: _scheduleSave,
                  decoration: const InputDecoration(
                    labelText: 'Ponto de impacto',
                    prefixIcon: Icon(Icons.crisis_alert_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _damageController,
                  onChanged: _scheduleSave,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Avarias',
                    prefixIcon: Icon(Icons.car_crash_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _driverController,
                        onChanged: _scheduleSave,
                        decoration: const InputDecoration(
                          labelText: 'Condutor',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _ownerController,
                        onChanged: _scheduleSave,
                        decoration: const InputDecoration(
                          labelText: 'Proprietario',
                        ),
                      ),
                    ),
                  ],
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
                  linkedPhotoIds: vehicle.photoIds,
                  onChanged: _setPhotoIds,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _initialize(VehicleRecord vehicle) {
    if (_initialized) {
      return;
    }
    _identifierController.text = vehicle.identifier;
    _plateController.text = vehicle.plate;
    _typeController.text = vehicle.type;
    _modelController.text = vehicle.model;
    _colorController.text = vehicle.color;
    _trafficDirectionController.text = vehicle.trafficDirection;
    _finalPositionController.text = vehicle.finalPosition;
    _impactPointController.text = vehicle.impactPoint;
    _damageController.text = vehicle.damage;
    _driverController.text = vehicle.driver;
    _ownerController.text = vehicle.owner;
    _noteController.text = vehicle.note;
    _lastSavedSignature = _signature(vehicle);
    _initialized = true;
  }

  VehicleRecord? _findVehicle([FieldOccurrence? occurrence]) {
    occurrence ??= widget.repository.findById(widget.occurrenceId);
    if (occurrence == null) {
      return null;
    }
    for (final vehicle in occurrence.vehicles) {
      if (vehicle.id == widget.vehicleId) {
        return vehicle;
      }
    }
    return null;
  }

  Future<void> _setPhotoIds(List<String> photoIds) async {
    _saveTimer?.cancel();
    final current = _findVehicle();
    if (current == null || !_initialized) {
      return;
    }
    final updated = _editedVehicle(current, photoIds: _uniqueIds(photoIds));
    _lastSavedSignature = _signature(updated);
    await widget.repository.updateVehicle(widget.occurrenceId, updated);
  }

  void _scheduleSave(String _) {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 450), _saveNow);
  }

  void _saveNow() {
    _saveTimer?.cancel();
    final current = _findVehicle();
    if (current == null || !_initialized) {
      return;
    }
    final updated = _editedVehicle(current);
    final signature = _signature(updated);
    if (_lastSavedSignature == signature) {
      return;
    }
    _lastSavedSignature = signature;
    unawaited(widget.repository.updateVehicle(widget.occurrenceId, updated));
  }

  VehicleRecord _editedVehicle(
    VehicleRecord current, {
    List<String>? photoIds,
  }) {
    return VehicleRecord(
      id: current.id,
      identifier: _identifierController.text.trim().isEmpty
          ? current.identifier
          : _identifierController.text.trim(),
      plate: _plateController.text.trim().toUpperCase(),
      type: _typeController.text.trim(),
      model: _modelController.text.trim(),
      color: _colorController.text.trim(),
      trafficDirection: _trafficDirectionController.text.trim(),
      finalPosition: _finalPositionController.text.trim(),
      impactPoint: _impactPointController.text.trim(),
      damage: _damageController.text.trim(),
      driver: _driverController.text.trim(),
      owner: _ownerController.text.trim(),
      note: _noteController.text.trim(),
      photoIds: photoIds ?? current.photoIds,
    );
  }
}

class _VehiclesHeader extends StatelessWidget {
  const _VehiclesHeader({required this.occurrence});

  final FieldOccurrence occurrence;

  @override
  Widget build(BuildContext context) {
    final linkedPhotos = occurrence.vehicles.fold<int>(
      0,
      (total, vehicle) => total + vehicle.photoIds.length,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.directions_car_outlined, color: AppColors.gold),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${occurrence.vehicles.length} veiculo(s)',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '$linkedPhotos foto(s) vinculada(s)',
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

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({
    required this.vehicle,
    required this.onTap,
    required this.onDelete,
  });

  final VehicleRecord vehicle;
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
                      Icons.directions_car_outlined,
                      color: AppColors.gold,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _title(vehicle),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          vehicle.damage.isEmpty
                              ? 'Sem avarias'
                              : vehicle.damage,
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
                    tooltip: 'Remover veiculo',
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
                  if (vehicle.finalPosition.isNotEmpty)
                    _InfoChip(
                      icon: Icons.place_outlined,
                      label: vehicle.finalPosition,
                    ),
                  if (vehicle.impactPoint.isNotEmpty)
                    _InfoChip(
                      icon: Icons.crisis_alert_outlined,
                      label: vehicle.impactPoint,
                    ),
                  if (vehicle.trafficDirection.isNotEmpty)
                    _InfoChip(
                      icon: Icons.explore_outlined,
                      label: vehicle.trafficDirection,
                    ),
                  _InfoChip(
                    icon: Icons.photo_outlined,
                    label: '${vehicle.photoIds.length} foto(s)',
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
  const _EditorHeader({required this.vehicle});

  final VehicleRecord vehicle;

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
          const Icon(Icons.directions_car_outlined, color: AppColors.gold),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _title(vehicle),
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

String _title(VehicleRecord vehicle) {
  final plate = vehicle.plate.isEmpty ? 'sem placa' : vehicle.plate;
  final model = vehicle.model.isEmpty ? '' : ' - ${vehicle.model}';
  return '${vehicle.identifier} ($plate)$model';
}

String _signature(VehicleRecord vehicle) {
  return [
    vehicle.identifier,
    vehicle.plate,
    vehicle.type,
    vehicle.model,
    vehicle.color,
    vehicle.trafficDirection,
    vehicle.finalPosition,
    vehicle.impactPoint,
    vehicle.damage,
    vehicle.driver,
    vehicle.owner,
    vehicle.note,
    vehicle.photoIds.join(','),
  ].join('|');
}

List<String> _uniqueIds(List<String> ids) {
  return ids.toSet().toList(growable: false);
}
