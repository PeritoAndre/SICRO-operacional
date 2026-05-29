import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/data/occurrence_repository.dart';
import '../../domain/models/forensic_case_metadata.dart';
import '../../domain/models/occurrence.dart';
import '../../domain/models/trace_record.dart';
import '../../features/photos/linked_photos_panel.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/operational_applicability_card.dart';

class TracesScreen extends StatefulWidget {
  const TracesScreen({
    required this.repository,
    required this.occurrenceId,
    super.key,
  });

  final OccurrenceRepository repository;
  final String occurrenceId;

  @override
  State<TracesScreen> createState() => _TracesScreenState();
}

class _TracesScreenState extends State<TracesScreen> {
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
              message: 'Nao foi possivel acessar os vestigios deste dossie.',
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(title: Text(_screenTitle(occurrence))),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 96),
              children: [
                _TracesHeader(occurrence: occurrence),
                const SizedBox(height: 14),
                OperationalApplicabilityCard(
                  title: _applicabilityTitle(occurrence),
                  message: _applicabilityMessage(occurrence),
                  notApplicable: occurrence.isNotApplicable(
                    OperationalItemIds.traces,
                  ),
                  onChanged: (value) =>
                      widget.repository.setOperationalItemNotApplicable(
                        widget.occurrenceId,
                        OperationalItemIds.traces,
                        value,
                      ),
                ),
                const SizedBox(height: 14),
                if (occurrence.traces.isEmpty)
                  const EmptyState(
                    icon: Icons.scatter_plot_outlined,
                    title: 'Nenhum vestigio registrado',
                    message:
                        'Adicione marcas, fragmentos, fluidos e demais vestigios observados no local.',
                  )
                else
                  for (final trace in occurrence.traces) ...[
                    _TraceCard(
                      trace: trace,
                      onTap: () => _openEditor(trace),
                      onDelete: () => _confirmDelete(trace),
                    ),
                    const SizedBox(height: 10),
                  ],
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _creating ? null : _createTrace,
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

  Future<void> _createTrace() async {
    setState(() => _creating = true);
    try {
      final trace = await widget.repository.createTrace(widget.occurrenceId);
      if (!mounted || trace == null) {
        return;
      }
      _openEditor(trace);
    } finally {
      if (mounted) {
        setState(() => _creating = false);
      }
    }
  }

  void _openEditor(TraceRecord trace) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _TraceEditorScreen(
          repository: widget.repository,
          occurrenceId: widget.occurrenceId,
          traceId: trace.id,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(TraceRecord trace) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remover vestigio?'),
          content: Text('${trace.identifier} sera removido deste dossie.'),
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
      await widget.repository.removeTrace(widget.occurrenceId, trace.id);
    }
  }
}

class _TraceEditorScreen extends StatefulWidget {
  const _TraceEditorScreen({
    required this.repository,
    required this.occurrenceId,
    required this.traceId,
  });

  final OccurrenceRepository repository;
  final String occurrenceId;
  final String traceId;

  @override
  State<_TraceEditorScreen> createState() => _TraceEditorScreenState();
}

class _TraceEditorScreenState extends State<_TraceEditorScreen> {
  final _identifierController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _lengthController = TextEditingController();
  final _widthController = TextEditingController();
  final _directionController = TextEditingController();
  final _noteController = TextEditingController();
  Timer? _saveTimer;
  TraceType? _type;
  bool _initialized = false;
  String? _lastSavedSignature;

  @override
  void dispose() {
    _saveNow();
    _saveTimer?.cancel();
    _identifierController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _lengthController.dispose();
    _widthController.dispose();
    _directionController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.repository,
      builder: (context, _) {
        final occurrence = widget.repository.findById(widget.occurrenceId);
        final trace = _findTrace(occurrence);
        if (trace == null) {
          return const Scaffold(
            body: EmptyState(
              icon: Icons.error_outline,
              title: 'Vestigio nao encontrado',
              message: 'O registro pode ter sido removido deste dossie.',
            ),
          );
        }
        _initialize(trace);

        return Scaffold(
          appBar: AppBar(title: Text('Editar ${trace.identifier}')),
          body: SafeArea(
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              children: [
                _EditorHeader(trace: trace),
                const SizedBox(height: 14),
                DropdownButtonFormField<TraceType>(
                  initialValue: _type,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Tipo',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: TraceType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Row(
                        children: [
                          Icon(_iconFor(type), color: AppColors.gold),
                          const SizedBox(width: 8),
                          Text(type.label),
                        ],
                      ),
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
                TextField(
                  controller: _identifierController,
                  onChanged: _scheduleSave,
                  decoration: const InputDecoration(
                    labelText: 'Identificador',
                    prefixIcon: Icon(Icons.label_outline),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _descriptionController,
                  onChanged: _scheduleSave,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Descricao',
                    prefixIcon: Icon(Icons.subject_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _locationController,
                  onChanged: _scheduleSave,
                  decoration: const InputDecoration(
                    labelText: 'Posicao resumida',
                    prefixIcon: Icon(Icons.place_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _lengthController,
                        onChanged: _scheduleSave,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Comprimento aprox. (m)',
                          prefixIcon: Icon(Icons.straighten_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _widthController,
                        onChanged: _scheduleSave,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Largura aprox. (m)',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _directionController,
                  onChanged: _scheduleSave,
                  decoration: const InputDecoration(
                    labelText: 'Direcao / sentido',
                    prefixIcon: Icon(Icons.explore_outlined),
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
                  linkedPhotoIds: trace.photoIds,
                  onChanged: _setPhotoIds,
                ),
                const SizedBox(height: 14),
                _SketchLinksPanel(count: trace.sketchElementIds.length),
              ],
            ),
          ),
        );
      },
    );
  }

  void _initialize(TraceRecord trace) {
    if (_initialized) {
      return;
    }
    _identifierController.text = trace.identifier;
    _descriptionController.text = trace.description;
    _locationController.text = trace.locationDescription;
    _lengthController.text = _numberText(trace.length);
    _widthController.text = _numberText(trace.width);
    _directionController.text = trace.direction;
    _noteController.text = trace.note;
    _type = trace.type;
    _lastSavedSignature = _signature(trace);
    _initialized = true;
  }

  TraceRecord? _findTrace([FieldOccurrence? occurrence]) {
    occurrence ??= widget.repository.findById(widget.occurrenceId);
    if (occurrence == null) {
      return null;
    }
    for (final trace in occurrence.traces) {
      if (trace.id == widget.traceId) {
        return trace;
      }
    }
    return null;
  }

  Future<void> _setPhotoIds(List<String> photoIds) async {
    _saveTimer?.cancel();
    final current = _findTrace();
    if (current == null || !_initialized) {
      return;
    }
    final updated = _editedTrace(current, photoIds: _uniqueIds(photoIds));
    _lastSavedSignature = _signature(updated);
    await widget.repository.updateTrace(widget.occurrenceId, updated);
  }

  void _scheduleSave(String _) {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 450), _saveNow);
  }

  void _saveNow() {
    _saveTimer?.cancel();
    final current = _findTrace();
    if (current == null || !_initialized) {
      return;
    }
    final updated = _editedTrace(current);
    final signature = _signature(updated);
    if (_lastSavedSignature == signature) {
      return;
    }
    _lastSavedSignature = signature;
    unawaited(widget.repository.updateTrace(widget.occurrenceId, updated));
  }

  TraceRecord _editedTrace(TraceRecord current, {List<String>? photoIds}) {
    return TraceRecord(
      id: current.id,
      identifier: _identifierController.text.trim().isEmpty
          ? current.identifier
          : _identifierController.text.trim(),
      type: _type ?? current.type,
      description: _descriptionController.text.trim(),
      length: _parseNumber(_lengthController.text),
      width: _parseNumber(_widthController.text),
      unit: 'm',
      direction: _directionController.text.trim(),
      locationDescription: _locationController.text.trim(),
      note: _noteController.text.trim(),
      photoIds: photoIds ?? current.photoIds,
      sketchElementIds: current.sketchElementIds,
    );
  }
}

class _TracesHeader extends StatelessWidget {
  const _TracesHeader({required this.occurrence});

  final FieldOccurrence occurrence;

  @override
  Widget build(BuildContext context) {
    final brakingCount = occurrence.traces
        .where((trace) => trace.type == TraceType.braking)
        .length;
    final biologicalCount = occurrence.traces
        .where((trace) => _biologicalTraceTypes.contains(trace.type))
        .length;
    final ballisticCount = occurrence.traces
        .where((trace) => _ballisticTraceTypes.contains(trace.type))
        .length;
    final weaponObjectCount = occurrence.traces
        .where((trace) => _weaponObjectTraceTypes.contains(trace.type))
        .length;
    final multimediaCount = occurrence.traces
        .where((trace) => _multimediaTraceTypes.contains(trace.type))
        .length;
    final papiloscopyCount = occurrence.traces
        .where((trace) => _papiloscopyTraceTypes.contains(trace.type))
        .length;
    final subtitle = switch (occurrence.metadata.type) {
      ForensicCaseType.violentDeath =>
        '$biologicalCount biologico(s) - $ballisticCount balistico(s) - $weaponObjectCount arma/objeto(s)',
      ForensicCaseType.property => _propertySubtitle(occurrence),
      ForensicCaseType.environmental => _environmentalSubtitle(occurrence),
      ForensicCaseType.ballistics =>
        '${occurrence.traces.length} material(is) balistico(s)',
      ForensicCaseType.audioImage =>
        '$multimediaCount midia(s)/arquivo(s) multimidia',
      ForensicCaseType.papiloscopy =>
        '$papiloscopyCount vestigio(s)/registro(s) papiloscopico(s)',
      ForensicCaseType.traffic => '$brakingCount frenagem(ns) registrada(s)',
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.scatter_plot_outlined, color: AppColors.gold),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${occurrence.traces.length} vestigio(s)',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
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

class _TraceCard extends StatelessWidget {
  const _TraceCard({
    required this.trace,
    required this.onTap,
    required this.onDelete,
  });

  final TraceRecord trace;
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
                    child: Icon(_iconFor(trace.type), color: AppColors.gold),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${trace.identifier} - ${trace.type.label}',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          trace.description.isEmpty
                              ? 'Sem descricao'
                              : trace.description,
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
                    tooltip: 'Remover vestigio',
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
                  if (trace.locationDescription.isNotEmpty)
                    _InfoChip(
                      icon: Icons.place_outlined,
                      label: trace.locationDescription,
                    ),
                  if (_dimensionLabel(trace).isNotEmpty)
                    _InfoChip(
                      icon: Icons.straighten_outlined,
                      label: _dimensionLabel(trace),
                    ),
                  if (trace.direction.isNotEmpty)
                    _InfoChip(
                      icon: Icons.explore_outlined,
                      label: trace.direction,
                    ),
                  _InfoChip(
                    icon: Icons.photo_outlined,
                    label: '${trace.photoIds.length} foto(s)',
                  ),
                  _InfoChip(
                    icon: Icons.architecture_outlined,
                    label: '${trace.sketchElementIds.length} croqui',
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
  const _EditorHeader({required this.trace});

  final TraceRecord trace;

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
          Icon(_iconFor(trace.type), color: AppColors.gold),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${trace.identifier} - ${trace.type.label}',
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

IconData _iconFor(TraceType type) {
  return switch (type) {
    TraceType.braking => Icons.tire_repair_outlined,
    TraceType.skid => Icons.gesture_outlined,
    TraceType.drag => Icons.swipe_outlined,
    TraceType.fragment => Icons.category_outlined,
    TraceType.stain => Icons.water_drop_outlined,
    TraceType.furrow => Icons.timeline_outlined,
    TraceType.tire => Icons.radio_button_unchecked,
    TraceType.fluid => Icons.opacity,
    TraceType.detachedPart => Icons.build_outlined,
    TraceType.impactMark => Icons.crisis_alert_outlined,
    TraceType.blood => Icons.water_drop,
    TraceType.biological => Icons.biotech_outlined,
    TraceType.ballisticCase => Icons.adjust_outlined,
    TraceType.projectile => Icons.gps_fixed_outlined,
    TraceType.perforation => Icons.center_focus_strong_outlined,
    TraceType.cartridge => Icons.album_outlined,
    TraceType.ballisticStandard => Icons.compare_arrows_outlined,
    TraceType.gsrSample => Icons.science_outlined,
    TraceType.coldWeapon => Icons.hardware_outlined,
    TraceType.firearm => Icons.construction_outlined,
    TraceType.struggleSign => Icons.front_hand_outlined,
    TraceType.footprint => Icons.directions_walk_outlined,
    TraceType.displacedObject => Icons.category_outlined,
    TraceType.damage => Icons.broken_image_outlined,
    TraceType.toolMark => Icons.handyman_outlined,
    TraceType.rupture => Icons.call_split_outlined,
    TraceType.lock => Icons.lock_open_outlined,
    TraceType.doorWindow => Icons.sensor_door_outlined,
    TraceType.fireFocus => Icons.local_fire_department_outlined,
    TraceType.burnPattern => Icons.whatshot_outlined,
    TraceType.thermalDamage => Icons.thermostat_outlined,
    TraceType.sootResidue => Icons.blur_on_outlined,
    TraceType.combustibleMaterial => Icons.inventory_2_outlined,
    TraceType.vegetationSuppression => Icons.forest_outlined,
    TraceType.effluent => Icons.water_drop_outlined,
    TraceType.burnIndicator => Icons.local_fire_department_outlined,
    TraceType.animalCadaver => Icons.pets_outlined,
    TraceType.environmentalSample => Icons.science_outlined,
    TraceType.multimediaFile => Icons.perm_media_outlined,
    TraceType.cctvDevice => Icons.videocam_outlined,
    TraceType.storageMedia => Icons.storage_outlined,
    TraceType.audioRecord => Icons.graphic_eq_outlined,
    TraceType.videoRecord => Icons.movie_outlined,
    TraceType.imageRecord => Icons.image_outlined,
    TraceType.latentPrint => Icons.fingerprint,
    TraceType.patentPrint => Icons.fingerprint,
    TraceType.plasticPrint => Icons.fingerprint,
    TraceType.fingerprintRecord => Icons.badge_outlined,
    TraceType.palmprintRecord => Icons.back_hand_outlined,
    TraceType.papillaryFragment => Icons.manage_search_outlined,
    TraceType.necroFingerprint => Icons.health_and_safety_outlined,
    TraceType.other => Icons.scatter_plot_outlined,
  };
}

String _screenTitle(FieldOccurrence occurrence) {
  return switch (occurrence.metadata.type) {
    ForensicCaseType.violentDeath => 'Vestigios periciais',
    ForensicCaseType.property => 'Vestigios patrimoniais',
    ForensicCaseType.environmental => 'Vestigios ambientais',
    ForensicCaseType.ballistics => 'Material balistico',
    ForensicCaseType.audioImage => 'Midias e arquivos',
    ForensicCaseType.papiloscopy => 'Vestigios papiloscopicos',
    ForensicCaseType.traffic => 'Vestigios',
  };
}

String _propertySubtitle(FieldOccurrence occurrence) {
  final nature = occurrence.metadata.propertyNature;
  final label = nature?.label ?? 'Patrimonio';
  return '$label - ${occurrence.traces.length} registro(s)';
}

String _environmentalSubtitle(FieldOccurrence occurrence) {
  final nature = occurrence.metadata.environmentalNature;
  final label = nature?.label ?? 'Ambiental';
  return '$label - ${occurrence.traces.length} registro(s)';
}

String _applicabilityTitle(FieldOccurrence occurrence) {
  return switch (occurrence.metadata.type) {
    ForensicCaseType.violentDeath => 'Vestigios no local',
    ForensicCaseType.property => 'Vestigios patrimoniais',
    ForensicCaseType.environmental => 'Vestigios ambientais',
    ForensicCaseType.ballistics => 'Material balistico',
    ForensicCaseType.audioImage => 'Midias/arquivos multimidia',
    ForensicCaseType.papiloscopy => 'Vestigios papiloscopicos',
    ForensicCaseType.traffic => 'Vestigios na ocorrencia',
  };
}

String _applicabilityMessage(FieldOccurrence occurrence) {
  return switch (occurrence.metadata.type) {
    ForensicCaseType.violentDeath =>
      'Use somente se nao havia vestigio tecnico a registrar.',
    ForensicCaseType.property =>
      'Use quando nao havia vestigio patrimonial relevante a registrar.',
    ForensicCaseType.environmental =>
      'Use quando nao havia vestigio ambiental relevante a registrar.',
    ForensicCaseType.ballistics =>
      'Use quando nao havia material balistico relevante a registrar.',
    ForensicCaseType.audioImage =>
      'Use quando nao havia midia ou arquivo multimidia relevante a registrar.',
    ForensicCaseType.papiloscopy =>
      'Use quando nao havia vestigio ou registro papiloscopico relevante.',
    ForensicCaseType.traffic =>
      'Use quando nao havia vestigio tecnico relevante no local.',
  };
}

const _biologicalTraceTypes = {
  TraceType.blood,
  TraceType.biological,
  TraceType.stain,
  TraceType.fluid,
  TraceType.drag,
};

const _ballisticTraceTypes = {
  TraceType.ballisticCase,
  TraceType.projectile,
  TraceType.perforation,
  TraceType.cartridge,
  TraceType.ballisticStandard,
  TraceType.gsrSample,
  TraceType.firearm,
};

const _weaponObjectTraceTypes = {
  TraceType.coldWeapon,
  TraceType.firearm,
  TraceType.struggleSign,
  TraceType.footprint,
  TraceType.displacedObject,
  TraceType.detachedPart,
};

const _multimediaTraceTypes = {
  TraceType.multimediaFile,
  TraceType.cctvDevice,
  TraceType.storageMedia,
  TraceType.audioRecord,
  TraceType.videoRecord,
  TraceType.imageRecord,
};

const _papiloscopyTraceTypes = {
  TraceType.latentPrint,
  TraceType.patentPrint,
  TraceType.plasticPrint,
  TraceType.fingerprintRecord,
  TraceType.palmprintRecord,
  TraceType.papillaryFragment,
  TraceType.necroFingerprint,
};

String _dimensionLabel(TraceRecord trace) {
  final length = _numberText(trace.length);
  final width = _numberText(trace.width);
  if (length.isEmpty && width.isEmpty) {
    return '';
  }
  if (length.isNotEmpty && width.isNotEmpty) {
    return '$length x $width ${trace.unit}';
  }
  if (length.isNotEmpty) {
    return '$length ${trace.unit} comp.';
  }
  return '$width ${trace.unit} larg.';
}

String _numberText(double? value) {
  if (value == null) {
    return '';
  }
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

String _signature(TraceRecord trace) {
  return [
    trace.identifier,
    trace.type.code,
    trace.description,
    trace.length?.toString() ?? '',
    trace.width?.toString() ?? '',
    trace.unit,
    trace.direction,
    trace.locationDescription,
    trace.note,
    trace.photoIds.join(','),
    trace.sketchElementIds.join(','),
  ].join('|');
}
