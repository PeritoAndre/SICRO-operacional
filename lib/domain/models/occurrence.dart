import 'dart:math' as math;

import 'case_data.dart';
import 'checklist_item.dart';
import 'field_note.dart';
import 'field_photo.dart';
import 'forensic_case_metadata.dart';
import 'location_record.dart';
import 'measurement_record.dart';
import 'trace_record.dart';
import 'vehicle_record.dart';
import 'victim_record.dart';

enum OccurrenceStatus {
  inProgress('em_andamento', 'Em andamento'),
  completed('concluida', 'Concluida'),
  exported('exportada', 'Exportada'),
  pendingReview('pendente_revisao', 'Pendente de revisao'),
  incomplete('incompleta', 'Incompleta'),
  archived('arquivada', 'Arquivada');

  const OccurrenceStatus(this.code, this.label);

  final String code;
  final String label;

  static OccurrenceStatus fromCode(Object? code) {
    if (code == 'em_atendimento' || code == 'em_andamento') {
      return OccurrenceStatus.inProgress;
    }
    if (code == 'pendente' || code == 'coleta_parcial') {
      return OccurrenceStatus.incomplete;
    }
    if (code == 'finalizada' || code == 'coleta_concluida') {
      return OccurrenceStatus.completed;
    }
    for (final status in values) {
      if (status.code == code) {
        return status;
      }
    }
    return OccurrenceStatus.inProgress;
  }
}

enum OperationalItemState {
  pending('pendente', 'Pendente'),
  partial('parcial', 'Parcial'),
  completed('concluido', 'Concluido'),
  notApplicable('nao_aplicavel', 'Nao aplicavel');

  const OperationalItemState(this.code, this.label);

  final String code;
  final String label;
}

class OperationalItemIds {
  static const caseData = 'case_data';
  static const gps = 'gps';
  static const checklist = 'checklist';
  static const photos = 'photos';
  static const tracePhotos = 'trace_photos';
  static const vehicles = 'vehicles';
  static const victims = 'victims';
  static const traces = 'traces';
  static const biologicalTraces = 'biological_traces';
  static const ballisticTraces = 'ballistic_traces';
  static const weaponsObjects = 'weapons_objects';
  static const measurements = 'measurements';
  static const notes = 'notes';
  static const export = 'export';
}

class OperationalStep {
  const OperationalStep({
    required this.id,
    required this.title,
    required this.description,
    required this.state,
  });

  final String id;
  final String title;
  final String description;
  final OperationalItemState state;

  bool get completed => state == OperationalItemState.completed;

  bool get resolved =>
      state == OperationalItemState.completed ||
      state == OperationalItemState.notApplicable;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'titulo': title,
      'descricao': description,
      'estado': state.code,
    };
  }
}

class OperationalProgress {
  const OperationalProgress({
    required this.percent,
    required this.completedRequiredItems,
    required this.totalRequiredItems,
    required this.steps,
    required this.pendingItems,
    required this.notApplicableItems,
  });

  final int percent;
  final int completedRequiredItems;
  final int totalRequiredItems;
  final List<OperationalStep> steps;
  final List<String> pendingItems;
  final List<String> notApplicableItems;

  OperationalItemState stateFor(String id) {
    for (final step in steps) {
      if (step.id == id) {
        return step.state;
      }
    }
    return OperationalItemState.pending;
  }

  Map<String, Object?> toJson() {
    return {
      'percentual': percent,
      'itens_concluidos': completedRequiredItems,
      'itens_totais': totalRequiredItems,
      'pendencias': pendingItems,
      'nao_aplicavel': notApplicableItems,
      'fluxo_sugerido': steps.map((step) => step.toJson()).toList(),
      'modulos': steps
          .map(
            (step) => {
              'id': step.id,
              'titulo': step.title,
              'estado': step.state.code,
              'aplicavel': step.state != OperationalItemState.notApplicable,
            },
          )
          .toList(),
    };
  }
}

enum OccurrenceTimelineEventType {
  created('ocorrencia_criada', 'Ocorrencia criada'),
  gpsStarted('gps_iniciado', 'GPS iniciado'),
  gpsCaptured('gps_capturado', 'GPS capturado'),
  firstPhoto('primeira_foto', 'Primeira foto'),
  exported('exportacao', 'Exportacao'),
  completed('conclusao', 'Conclusao'),
  reopened('reabertura', 'Reabertura'),
  statusChanged('status_alterado', 'Status alterado'),
  archived('arquivamento', 'Arquivamento');

  const OccurrenceTimelineEventType(this.code, this.label);

  final String code;
  final String label;

  static OccurrenceTimelineEventType fromCode(Object? code) {
    for (final type in values) {
      if (type.code == code) {
        return type;
      }
    }
    return OccurrenceTimelineEventType.statusChanged;
  }
}

class OccurrenceTimelineEvent {
  const OccurrenceTimelineEvent({
    required this.id,
    required this.type,
    required this.occurredAt,
    this.title = '',
    this.description = '',
  });

  final String id;
  final OccurrenceTimelineEventType type;
  final DateTime occurredAt;
  final String title;
  final String description;

  String get displayTitle => title.trim().isEmpty ? type.label : title.trim();

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'tipo': type.code,
      'titulo': displayTitle,
      'descricao': description,
      'ocorrido_em': occurredAt.toIso8601String(),
    };
  }

  factory OccurrenceTimelineEvent.fromJson(Map<String, Object?> json) {
    final occurredAt = _date(json['ocorrido_em']) ?? DateTime.now();
    return OccurrenceTimelineEvent(
      id: _string(json['id']),
      type: OccurrenceTimelineEventType.fromCode(json['tipo']),
      title: _string(json['titulo']),
      description: _string(json['descricao']),
      occurredAt: occurredAt,
    );
  }
}

class OperationalClosureWarning {
  const OperationalClosureWarning({
    required this.code,
    required this.title,
    required this.description,
    this.critical = false,
  });

  final String code;
  final String title;
  final String description;
  final bool critical;

  Map<String, Object?> toJson() {
    return {
      'codigo': code,
      'titulo': title,
      'descricao': description,
      'criticidade': critical ? 'alta' : 'atencao',
      'bloqueia_conclusao': false,
    };
  }
}

class OccurrenceStats {
  const OccurrenceStats({
    required this.occurrenceId,
    required this.forensicType,
    required this.forensicTypeLabel,
    required this.nature,
    required this.natureLabel,
    required this.result,
    required this.resultLabel,
    required this.occurrenceStatus,
    required this.occurrenceStatusLabel,
    required this.operationalStatus,
    required this.createdAt,
    required this.startedAt,
    required this.finishedAt,
    required this.durationSeconds,
    required this.municipality,
    required this.district,
    required this.address,
    required this.primaryCoordinate,
    required this.bestGpsAccuracyMeters,
    required this.photosCount,
    required this.victimsCount,
    required this.vehiclesCount,
    required this.tracesCount,
    required this.measurementsCount,
    required this.notesCount,
    required this.checklistItemsCount,
    required this.answeredChecklistItemsCount,
    required this.requiredChecklistItemsCount,
    required this.pendingRequiredChecklistItemsCount,
    required this.notApplicableItemsCount,
    required this.exported,
    required this.exportedAt,
  });

  factory OccurrenceStats.fromOccurrence(FieldOccurrence occurrence) {
    final metadata = occurrence.metadata;
    final primaryCoordinate = occurrence.location.hasCoordinates
        ? occurrence.location
        : occurrence.bestGpsLocation;
    return OccurrenceStats(
      occurrenceId: occurrence.id,
      forensicType: metadata.type.code,
      forensicTypeLabel: metadata.type.label,
      nature: metadata.primaryNatureCode ?? '',
      natureLabel: _natureLabel(metadata),
      result: metadata.result.code,
      resultLabel: metadata.result.label,
      occurrenceStatus: occurrence.status.code,
      occurrenceStatusLabel: occurrence.status.label,
      operationalStatus: occurrence.operationalSessionStatusCode,
      createdAt: occurrence.createdAt,
      startedAt: occurrence.effectiveStartedAt,
      finishedAt: occurrence.finishedAt,
      durationSeconds: occurrence.durationSeconds,
      municipality: occurrence.caseData.municipality,
      district: occurrence.caseData.district,
      address: occurrence.caseData.displayLocation,
      primaryCoordinate: primaryCoordinate,
      bestGpsAccuracyMeters: occurrence.bestGpsLocation?.accuracyMeters,
      photosCount: occurrence.photos.length,
      victimsCount: occurrence.victims.length,
      vehiclesCount: occurrence.vehicles.length,
      tracesCount: occurrence.traces.length,
      measurementsCount: occurrence.measurements.length,
      notesCount: occurrence.notes.length,
      checklistItemsCount: occurrence.checklist.length,
      answeredChecklistItemsCount: occurrence.answeredChecklistItems,
      requiredChecklistItemsCount: occurrence.requiredChecklistItems,
      pendingRequiredChecklistItemsCount:
          occurrence.pendingRequiredChecklistItems,
      notApplicableItemsCount: occurrence.notApplicableItems.length,
      exported: occurrence.hasExportRecord,
      exportedAt: occurrence.exportedAt,
    );
  }

  final String occurrenceId;
  final String forensicType;
  final String forensicTypeLabel;
  final String nature;
  final String natureLabel;
  final String result;
  final String resultLabel;
  final String occurrenceStatus;
  final String occurrenceStatusLabel;
  final String operationalStatus;
  final DateTime createdAt;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final int durationSeconds;
  final String municipality;
  final String district;
  final String address;
  final LocationRecord? primaryCoordinate;
  final double? bestGpsAccuracyMeters;
  final int photosCount;
  final int victimsCount;
  final int vehiclesCount;
  final int tracesCount;
  final int measurementsCount;
  final int notesCount;
  final int checklistItemsCount;
  final int answeredChecklistItemsCount;
  final int requiredChecklistItemsCount;
  final int pendingRequiredChecklistItemsCount;
  final int notApplicableItemsCount;
  final bool exported;
  final DateTime? exportedAt;

  Map<String, Object?> toJson() {
    return {
      'ocorrencia_id': occurrenceId,
      'tipo_pericia': forensicType,
      'tipo_pericia_rotulo': forensicTypeLabel,
      'natureza': nature,
      'natureza_rotulo': natureLabel,
      'resultado': result,
      'resultado_rotulo': resultLabel,
      'status_ocorrencia': occurrenceStatus,
      'status_ocorrencia_rotulo': occurrenceStatusLabel,
      'status_operacional': operationalStatus,
      'criado_em': createdAt.toIso8601String(),
      'iniciado_em': startedAt.toIso8601String(),
      'concluido_em': finishedAt?.toIso8601String(),
      'duracao_segundos': durationSeconds,
      'municipio': municipality,
      'bairro': district,
      'endereco': address,
      'coordenada_principal': primaryCoordinate?.toJson(),
      'melhor_precisao_gps_m': bestGpsAccuracyMeters,
      'total_fotos': photosCount,
      'total_vitimas_corpos': victimsCount,
      'total_veiculos': vehiclesCount,
      'total_vestigios': tracesCount,
      'total_medicoes': measurementsCount,
      'total_observacoes': notesCount,
      'total_itens_checklist': checklistItemsCount,
      'itens_checklist_respondidos': answeredChecklistItemsCount,
      'itens_checklist_obrigatorios': requiredChecklistItemsCount,
      'itens_checklist_obrigatorios_pendentes':
          pendingRequiredChecklistItemsCount,
      'itens_nao_aplicaveis': notApplicableItemsCount,
      'exportada': exported,
      'ultima_exportacao_em': exportedAt?.toIso8601String(),
    };
  }
}

class FieldOccurrence {
  const FieldOccurrence({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.caseData,
    this.metadata = const ForensicCaseMetadata(),
    this.status = OccurrenceStatus.inProgress,
    this.startedAt,
    this.finishedAt,
    this.exportedAt,
    this.exportedPackageName = '',
    this.exportedPackageSha256 = '',
    this.notApplicableItems = const [],
    this.location = const LocationRecord(),
    this.gpsTrack = const [],
    this.checklist = const [],
    this.photos = const [],
    this.vehicles = const [],
    this.victims = const [],
    this.traces = const [],
    this.measurements = const [],
    this.notes = const [],
    this.timeline = const [],
  });

  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final ForensicCaseMetadata metadata;
  final OccurrenceStatus status;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final DateTime? exportedAt;
  final String exportedPackageName;
  final String exportedPackageSha256;
  final List<String> notApplicableItems;
  final CaseData caseData;
  final LocationRecord location;
  final List<LocationRecord> gpsTrack;
  final List<ChecklistItem> checklist;
  final List<FieldPhoto> photos;
  final List<VehicleRecord> vehicles;
  final List<VictimRecord> victims;
  final List<TraceRecord> traces;
  final List<MeasurementRecord> measurements;
  final List<FieldNote> notes;
  final List<OccurrenceTimelineEvent> timeline;

  int get pendingRequiredChecklistItems {
    return checklist
        .where(
          (item) => item.required && item.answer == ChecklistAnswer.unchecked,
        )
        .length;
  }

  int get answeredChecklistItems {
    return checklist
        .where((item) => item.answer != ChecklistAnswer.unchecked)
        .length;
  }

  int get requiredChecklistItems {
    return checklist.where((item) => item.required).length;
  }

  double get checklistProgress {
    if (checklist.isEmpty) {
      return 0;
    }
    return answeredChecklistItems / checklist.length;
  }

  bool get hasTextNote {
    return notes.any((note) => note.text.trim().isNotEmpty);
  }

  bool get hasTracePhoto {
    return photos.any(
      (photo) =>
          photo.category == PhotoCategory.trace ||
          photo.category == PhotoCategory.braking,
    );
  }

  bool get hasExportRecord {
    return exportedAt != null || status == OccurrenceStatus.exported;
  }

  DateTime get effectiveStartedAt {
    return startedAt ?? createdAt;
  }

  bool get sessionActive {
    return status == OccurrenceStatus.inProgress;
  }

  bool get sessionFinished {
    return finishedAt != null ||
        status == OccurrenceStatus.completed ||
        status == OccurrenceStatus.exported ||
        status == OccurrenceStatus.pendingReview ||
        status == OccurrenceStatus.incomplete ||
        status == OccurrenceStatus.archived;
  }

  String get operationalSessionStatusCode {
    return switch (status) {
      OccurrenceStatus.inProgress => 'em_andamento',
      OccurrenceStatus.completed => 'concluida',
      OccurrenceStatus.exported => 'exportada',
      OccurrenceStatus.pendingReview => 'pendente_revisao',
      OccurrenceStatus.incomplete => 'incompleta',
      OccurrenceStatus.archived => 'arquivada',
    };
  }

  int get durationSeconds {
    final end = finishedAt ?? (sessionActive ? DateTime.now() : updatedAt);
    final seconds = end.difference(effectiveStartedAt).inSeconds;
    return seconds < 0 ? 0 : seconds;
  }

  int get gpsReadingsCount => gpsTrack.length;

  LocationRecord? get bestGpsLocation {
    if (location.hasCoordinates) {
      return location;
    }
    LocationRecord? best;
    for (final reading in gpsTrack) {
      if (!reading.hasCoordinates) {
        continue;
      }
      if (best == null || _isBetterGps(reading, best)) {
        best = reading;
      }
    }
    return best;
  }

  double? get gpsDistanceMeters {
    final readings = gpsTrack
        .where((reading) => reading.hasCoordinates)
        .toList(growable: false);
    if (readings.length < 2) {
      return null;
    }

    var total = 0.0;
    for (var index = 1; index < readings.length; index++) {
      total += _distanceMeters(readings[index - 1], readings[index]);
    }
    return total;
  }

  OccurrenceStats get stats => OccurrenceStats.fromOccurrence(this);

  List<OccurrenceTimelineEvent> get effectiveTimeline {
    if (timeline.isNotEmpty) {
      return timeline;
    }
    return [
      OccurrenceTimelineEvent(
        id: 'timeline_created_${createdAt.microsecondsSinceEpoch}',
        type: OccurrenceTimelineEventType.created,
        occurredAt: createdAt,
        description: 'Dossie operacional criado no aparelho.',
      ),
    ];
  }

  List<OperationalClosureWarning> get closureWarnings {
    final warnings = <OperationalClosureWarning>[];
    if (pendingRequiredChecklistItems > 0) {
      warnings.add(
        OperationalClosureWarning(
          code: 'checklist_obrigatorio_pendente',
          title: 'Checklist obrigatorio pendente',
          description:
              '$pendingRequiredChecklistItems item(ns) obrigatorio(s) ainda nao respondido(s).',
          critical: true,
        ),
      );
    }
    if (!photos.any((photo) => photo.category == PhotoCategory.overview)) {
      warnings.add(
        const OperationalClosureWarning(
          code: 'sem_foto_geral',
          title: 'Sem foto geral',
          description:
              'Nenhuma foto classificada como visao geral foi registrada.',
        ),
      );
    }
    if (!hasTextNote) {
      warnings.add(
        const OperationalClosureWarning(
          code: 'sem_observacao_final',
          title: 'Sem observacao final',
          description:
              'Nao ha observacao livre preenchida para consolidar o atendimento.',
        ),
      );
    }
    if (!hasExportRecord) {
      warnings.add(
        const OperationalClosureWarning(
          code: 'sem_exportacao',
          title: 'Sem exportacao',
          description: 'O pacote .sicroapp ainda nao foi gerado.',
        ),
      );
    }
    final accuracy = bestGpsLocation?.accuracyMeters;
    if (accuracy == null) {
      warnings.add(
        const OperationalClosureWarning(
          code: 'gps_nao_capturado',
          title: 'GPS nao capturado',
          description: 'Nao ha coordenada principal registrada no dossie.',
          critical: true,
        ),
      );
    } else if (accuracy > 15) {
      warnings.add(
        OperationalClosureWarning(
          code: 'gps_fraco',
          title: 'GPS fraco',
          description:
              'Melhor precisao registrada: ${accuracy.toStringAsFixed(1)} m.',
        ),
      );
    }
    return warnings;
  }

  Map<String, Object?> operationalSessionToJson() {
    return {
      'status_operacional': operationalSessionStatusCode,
      'status_ocorrencia': status.code,
      'iniciado_em': effectiveStartedAt.toIso8601String(),
      'concluido_em': finishedAt?.toIso8601String(),
      'duracao_segundos': durationSeconds,
      'gps_melhor_leitura': bestGpsLocation?.toJson(),
      'gps_total_leituras': gpsReadingsCount,
      'distancia_aproximada_m': gpsDistanceMeters,
      'pendencias_encerramento': closureWarnings
          .map((warning) => warning.toJson())
          .toList(),
      'estatisticas': operationalStatisticsToJson(),
    };
  }

  Map<String, Object?> operationalStatisticsToJson() {
    return {
      ...stats.toJson(),
      'leituras_gps': gpsReadingsCount,
      'distancia_aproximada_m': gpsDistanceMeters,
      'pendencias_encerramento': closureWarnings
          .map((warning) => warning.toJson())
          .toList(),
    };
  }

  bool get checklistFullyAnswered {
    return checklist.isNotEmpty && answeredChecklistItems == checklist.length;
  }

  bool isNotApplicable(String itemId) {
    return notApplicableItems.contains(itemId);
  }

  bool get vehiclesResolved {
    return vehicles.isNotEmpty || isNotApplicable(OperationalItemIds.vehicles);
  }

  bool get victimsResolved {
    return victims.isNotEmpty || isNotApplicable(OperationalItemIds.victims);
  }

  bool get tracesResolved {
    return traces.isNotEmpty || isNotApplicable(OperationalItemIds.traces);
  }

  bool get measurementsResolved {
    return measurements.isNotEmpty ||
        isNotApplicable(OperationalItemIds.measurements);
  }

  bool get tracePhotosResolved {
    return hasTracePhoto ||
        isNotApplicable(OperationalItemIds.tracePhotos) ||
        isNotApplicable(OperationalItemIds.traces);
  }

  bool get isViolentDeath {
    return metadata.type == ForensicCaseType.violentDeath;
  }

  bool get isProperty {
    return metadata.type == ForensicCaseType.property;
  }

  bool get shouldShowVehicleModule {
    return metadata.type == ForensicCaseType.traffic ||
        metadata.sceneEnvironment == SceneEnvironment.vehicle ||
        vehicles.isNotEmpty;
  }

  bool get hasBiologicalTrace {
    return traces.any((trace) => _biologicalTraceTypes.contains(trace.type));
  }

  bool get hasBallisticTrace {
    return traces.any((trace) => _ballisticTraceTypes.contains(trace.type));
  }

  bool get hasWeaponObjectTrace {
    return traces.any((trace) => _weaponObjectTraceTypes.contains(trace.type));
  }

  OperationalProgress get operationalProgress {
    if (isViolentDeath) {
      return _violentDeathOperationalProgress();
    }
    if (isProperty) {
      return _propertyOperationalProgress();
    }
    return _trafficOperationalProgress();
  }

  OperationalProgress _trafficOperationalProgress() {
    final requiredItems = [
      location.hasCoordinates,
      checklistFullyAnswered,
      photos.isNotEmpty,
      tracePhotosResolved,
      vehiclesResolved,
      victimsResolved,
      tracesResolved,
      measurementsResolved,
      hasTextNote,
      hasExportRecord,
    ];
    final completed = requiredItems.where((item) => item).length;
    final percent = ((completed / requiredItems.length) * 100).round();
    final pending = <String>[
      if (!location.hasCoordinates) 'GPS nao capturado',
      if (!checklistFullyAnswered)
        pendingRequiredChecklistItems > 0
            ? 'Checklist com obrigatorios pendentes'
            : 'Checklist incompleto',
      if (photos.isEmpty) 'Nenhuma foto capturada',
      if (!tracePhotosResolved) 'Nenhuma foto de vestigio',
      if (!vehiclesResolved) 'Nenhum veiculo cadastrado',
      if (!victimsResolved) 'Nenhuma vitima registrada',
      if (!tracesResolved) 'Nenhum vestigio cadastrado',
      if (!measurementsResolved) 'Nenhuma medicao registrada',
      if (!hasTextNote) 'Observacoes finais nao preenchidas',
      if (!hasExportRecord) 'Ocorrencia ainda nao exportada',
    ];

    return OperationalProgress(
      percent: percent,
      completedRequiredItems: completed,
      totalRequiredItems: requiredItems.length,
      pendingItems: pending,
      notApplicableItems: notApplicableItems,
      steps: [
        OperationalStep(
          id: OperationalItemIds.caseData,
          title: 'Dados do caso',
          description: 'BO, local, equipe e referencias do atendimento',
          state: _caseDataState(),
        ),
        OperationalStep(
          id: OperationalItemIds.gps,
          title: 'GPS',
          description: 'Coordenada pericial salva no dossie',
          state: location.hasCoordinates
              ? OperationalItemState.completed
              : OperationalItemState.pending,
        ),
        OperationalStep(
          id: OperationalItemIds.checklist,
          title: 'Checklist',
          description: 'Itens operacionais de transito respondidos',
          state: _checklistState(),
        ),
        OperationalStep(
          id: OperationalItemIds.photos,
          title: 'Fotos gerais',
          description: 'Registro fotografico inicial por categoria',
          state: _photosState(),
        ),
        OperationalStep(
          id: OperationalItemIds.tracePhotos,
          title: 'Fotos de vestigio',
          description: 'Registro fotografico de marcas ou vestigios tecnicos',
          state: _tracePhotosState(),
        ),
        OperationalStep(
          id: OperationalItemIds.vehicles,
          title: 'Veiculos',
          description: 'Veiculos envolvidos e fotos vinculadas',
          state: _moduleState(
            itemId: OperationalItemIds.vehicles,
            hasData: vehicles.isNotEmpty,
          ),
        ),
        OperationalStep(
          id: OperationalItemIds.victims,
          title: 'Vitimas',
          description: 'Pessoas envolvidas, remocao e fotos vinculadas',
          state: _moduleState(
            itemId: OperationalItemIds.victims,
            hasData: victims.isNotEmpty,
          ),
        ),
        OperationalStep(
          id: OperationalItemIds.traces,
          title: 'Vestigios',
          description: 'Marcas, fragmentos, fluidos e demais vestigios',
          state: _moduleState(
            itemId: OperationalItemIds.traces,
            hasData: traces.isNotEmpty,
          ),
        ),
        OperationalStep(
          id: OperationalItemIds.measurements,
          title: 'Medicoes',
          description: 'Distancias e medidas relevantes coletadas em campo',
          state: _moduleState(
            itemId: OperationalItemIds.measurements,
            hasData: measurements.isNotEmpty,
          ),
        ),
        OperationalStep(
          id: OperationalItemIds.notes,
          title: 'Observacoes finais',
          description: 'Anotacoes livres e pendencias do atendimento',
          state: hasTextNote
              ? OperationalItemState.completed
              : notes.isEmpty
              ? OperationalItemState.pending
              : OperationalItemState.partial,
        ),
        OperationalStep(
          id: OperationalItemIds.export,
          title: 'Exportacao',
          description: 'Pacote .sicroapp gerado para o desktop',
          state: hasExportRecord
              ? OperationalItemState.completed
              : OperationalItemState.pending,
        ),
      ],
    );
  }

  OperationalProgress _violentDeathOperationalProgress() {
    final requiredItems = [
      location.hasCoordinates,
      checklistFullyAnswered,
      photos.isNotEmpty,
      victimsResolved,
      tracesResolved,
      measurementsResolved,
      hasTextNote,
      hasExportRecord,
    ];
    final completed = requiredItems.where((item) => item).length;
    final percent = ((completed / requiredItems.length) * 100).round();
    final pending = <String>[
      if (!location.hasCoordinates) 'GPS nao capturado',
      if (!checklistFullyAnswered)
        pendingRequiredChecklistItems > 0
            ? 'Checklist de morte violenta com obrigatorios pendentes'
            : 'Checklist de morte violenta incompleto',
      if (photos.isEmpty) 'Nenhuma foto capturada',
      if (!victimsResolved) 'Nenhum corpo/vitima registrado',
      if (!tracesResolved) 'Nenhum vestigio cadastrado',
      if (!measurementsResolved) 'Nenhuma medicao registrada',
      if (!hasTextNote) 'Observacoes finais nao preenchidas',
      if (!hasExportRecord) 'Ocorrencia ainda nao exportada',
    ];

    final steps = <OperationalStep>[
      OperationalStep(
        id: OperationalItemIds.caseData,
        title: 'Dados do caso',
        description: 'BO, local, equipe e referencias do atendimento',
        state: _caseDataState(),
      ),
      OperationalStep(
        id: OperationalItemIds.gps,
        title: 'GPS',
        description: 'Coordenada pericial salva no dossie',
        state: location.hasCoordinates
            ? OperationalItemState.completed
            : OperationalItemState.pending,
      ),
      OperationalStep(
        id: OperationalItemIds.checklist,
        title: 'Checklist de morte violenta',
        description: 'Preservacao, corpo, vestigios e registro fotografico',
        state: _checklistState(),
      ),
      OperationalStep(
        id: OperationalItemIds.photos,
        title: 'Fotos categorizadas',
        description: 'Registro geral, corpo, lesoes, vestigios e objetos',
        state: _photosState(),
      ),
      OperationalStep(
        id: OperationalItemIds.victims,
        title: 'Vitimas/Corpos',
        description: 'Identificacao, remocao, posicao corporal e fotos',
        state: _moduleState(
          itemId: OperationalItemIds.victims,
          hasData: victims.isNotEmpty,
        ),
      ),
      OperationalStep(
        id: OperationalItemIds.biologicalTraces,
        title: 'Vestigios biologicos',
        description: 'Sangue, manchas, fluidos e materiais biologicos',
        state: _traceGroupState(hasData: hasBiologicalTrace),
      ),
      OperationalStep(
        id: OperationalItemIds.ballisticTraces,
        title: 'Vestigios balisticos',
        description: 'Capsulas, estojos, projeteis, impactos e trajetoria',
        state: _traceGroupState(hasData: hasBallisticTrace),
      ),
      OperationalStep(
        id: OperationalItemIds.weaponsObjects,
        title: 'Armas/objetos',
        description: 'Armas, sinais de luta, pertences e objetos deslocados',
        state: _traceGroupState(hasData: hasWeaponObjectTrace),
      ),
      if (shouldShowVehicleModule)
        OperationalStep(
          id: OperationalItemIds.vehicles,
          title: 'Veiculos',
          description: 'Veiculo como ambiente ou elemento complementar',
          state: _moduleState(
            itemId: OperationalItemIds.vehicles,
            hasData: vehicles.isNotEmpty,
          ),
        ),
      OperationalStep(
        id: OperationalItemIds.measurements,
        title: 'Medicoes',
        description: 'Distancias e medidas relevantes coletadas em campo',
        state: _moduleState(
          itemId: OperationalItemIds.measurements,
          hasData: measurements.isNotEmpty,
        ),
      ),
      OperationalStep(
        id: OperationalItemIds.notes,
        title: 'Observacoes finais',
        description: 'Anotacoes livres e pendencias do atendimento',
        state: hasTextNote
            ? OperationalItemState.completed
            : notes.isEmpty
            ? OperationalItemState.pending
            : OperationalItemState.partial,
      ),
      OperationalStep(
        id: OperationalItemIds.export,
        title: 'Exportacao',
        description: 'Pacote .sicroapp gerado para o desktop',
        state: hasExportRecord
            ? OperationalItemState.completed
            : OperationalItemState.pending,
      ),
    ];

    return OperationalProgress(
      percent: percent,
      completedRequiredItems: completed,
      totalRequiredItems: requiredItems.length,
      pendingItems: pending,
      notApplicableItems: notApplicableItems,
      steps: steps,
    );
  }

  OperationalProgress _propertyOperationalProgress() {
    final requiredItems = [
      location.hasCoordinates,
      checklistFullyAnswered,
      photos.isNotEmpty,
      tracesResolved,
      measurementsResolved,
      hasTextNote,
      hasExportRecord,
    ];
    final completed = requiredItems.where((item) => item).length;
    final percent = ((completed / requiredItems.length) * 100).round();
    final pending = <String>[
      if (!location.hasCoordinates) 'GPS nao capturado',
      if (!checklistFullyAnswered)
        pendingRequiredChecklistItems > 0
            ? 'Checklist de patrimonio com obrigatorios pendentes'
            : 'Checklist de patrimonio incompleto',
      if (photos.isEmpty) 'Nenhuma foto capturada',
      if (!tracesResolved) 'Nenhum vestigio patrimonial cadastrado',
      if (!measurementsResolved) 'Nenhuma medicao registrada',
      if (!hasTextNote) 'Observacoes finais nao preenchidas',
      if (!hasExportRecord) 'Ocorrencia ainda nao exportada',
    ];

    return OperationalProgress(
      percent: percent,
      completedRequiredItems: completed,
      totalRequiredItems: requiredItems.length,
      pendingItems: pending,
      notApplicableItems: notApplicableItems,
      steps: [
        OperationalStep(
          id: OperationalItemIds.caseData,
          title: 'Dados do caso',
          description: 'BO, local, equipe e referencias do atendimento',
          state: _caseDataState(),
        ),
        OperationalStep(
          id: OperationalItemIds.gps,
          title: 'GPS',
          description: 'Coordenada pericial salva no dossie',
          state: location.hasCoordinates
              ? OperationalItemState.completed
              : OperationalItemState.pending,
        ),
        OperationalStep(
          id: OperationalItemIds.checklist,
          title: 'Checklist de patrimonio',
          description:
              'Itens conforme avaliacao, danos, arrombamento ou incendio',
          state: _checklistState(),
        ),
        OperationalStep(
          id: OperationalItemIds.photos,
          title: 'Fotos categorizadas',
          description: 'Fotos gerais, documentais, danos e detalhes',
          state: _photosState(),
        ),
        OperationalStep(
          id: OperationalItemIds.traces,
          title: 'Vestigios',
          description: 'Danos, arrombamento, marcas, fuligem ou residuos',
          state: _moduleState(
            itemId: OperationalItemIds.traces,
            hasData: traces.isNotEmpty,
          ),
        ),
        OperationalStep(
          id: OperationalItemIds.measurements,
          title: 'Medicoes',
          description: 'Dimensoes, extensao de dano e area afetada',
          state: _moduleState(
            itemId: OperationalItemIds.measurements,
            hasData: measurements.isNotEmpty,
          ),
        ),
        OperationalStep(
          id: OperationalItemIds.notes,
          title: 'Observacoes finais',
          description: 'Descricao tecnica e pendencias do atendimento',
          state: hasTextNote
              ? OperationalItemState.completed
              : notes.isEmpty
              ? OperationalItemState.pending
              : OperationalItemState.partial,
        ),
        OperationalStep(
          id: OperationalItemIds.export,
          title: 'Exportacao',
          description: 'Pacote .sicroapp gerado para o desktop',
          state: hasExportRecord
              ? OperationalItemState.completed
              : OperationalItemState.pending,
        ),
      ],
    );
  }

  FieldOccurrence copyWith({
    DateTime? updatedAt,
    OccurrenceStatus? status,
    DateTime? startedAt,
    DateTime? finishedAt,
    DateTime? exportedAt,
    String? exportedPackageName,
    String? exportedPackageSha256,
    List<String>? notApplicableItems,
    ForensicCaseMetadata? metadata,
    CaseData? caseData,
    LocationRecord? location,
    List<LocationRecord>? gpsTrack,
    List<ChecklistItem>? checklist,
    List<FieldPhoto>? photos,
    List<VehicleRecord>? vehicles,
    List<VictimRecord>? victims,
    List<TraceRecord>? traces,
    List<MeasurementRecord>? measurements,
    List<FieldNote>? notes,
    List<OccurrenceTimelineEvent>? timeline,
    bool clearFinishedAt = false,
  }) {
    return FieldOccurrence(
      id: id,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: clearFinishedAt ? null : finishedAt ?? this.finishedAt,
      exportedAt: exportedAt ?? this.exportedAt,
      exportedPackageName: exportedPackageName ?? this.exportedPackageName,
      exportedPackageSha256:
          exportedPackageSha256 ?? this.exportedPackageSha256,
      notApplicableItems: notApplicableItems ?? this.notApplicableItems,
      metadata: metadata ?? this.metadata,
      caseData: caseData ?? this.caseData,
      location: location ?? this.location,
      gpsTrack: gpsTrack ?? this.gpsTrack,
      checklist: checklist ?? this.checklist,
      photos: photos ?? this.photos,
      vehicles: vehicles ?? this.vehicles,
      victims: victims ?? this.victims,
      traces: traces ?? this.traces,
      measurements: measurements ?? this.measurements,
      notes: notes ?? this.notes,
      timeline: timeline ?? this.timeline,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'status': status.code,
      'criado_em': createdAt.toIso8601String(),
      'atualizado_em': updatedAt.toIso8601String(),
      'iniciado_em': effectiveStartedAt.toIso8601String(),
      'concluido_em': finishedAt?.toIso8601String(),
      'duracao_segundos': durationSeconds,
      'exportado_em': exportedAt?.toIso8601String(),
      'ultimo_pacote_exportado': exportedPackageName,
      'ultimo_sha256_exportado': exportedPackageSha256,
      'nao_aplicavel': notApplicableItems,
      'metadados_periciais': metadata.toJson(),
      'sessao_operacional': operationalSessionToJson(),
      'operacional': operationalProgress.toJson(),
      'caso': caseData.toJson(),
      'localizacao': location.toJson(),
      'gps_leituras': gpsTrack.map((reading) => reading.toJson()).toList(),
      'estatisticas': operationalStatisticsToJson(),
      'timeline': effectiveTimeline.map((event) => event.toJson()).toList(),
      'checklist': checklist.map((item) => item.toJson()).toList(),
      'fotos': photos.map((photo) => photo.toJson()).toList(),
      'veiculos': vehicles.map((vehicle) => vehicle.toJson()).toList(),
      'vitimas': victims.map((victim) => victim.toJson()).toList(),
      'vestigios': traces.map((trace) => trace.toJson()).toList(),
      'medicoes': measurements
          .map((measurement) => measurement.toJson())
          .toList(),
      'observacoes': notes.map((note) => note.toJson()).toList(),
    };
  }

  factory FieldOccurrence.fromJson(Map<String, Object?> json) {
    return FieldOccurrence(
      id: _string(json['id']),
      status: OccurrenceStatus.fromCode(json['status']),
      createdAt: _date(json['criado_em']) ?? DateTime.now(),
      updatedAt: _date(json['atualizado_em']) ?? DateTime.now(),
      startedAt: _date(json['iniciado_em']) ?? _date(json['criado_em']),
      finishedAt: _date(json['concluido_em']),
      exportedAt: _date(json['exportado_em']),
      exportedPackageName: _string(json['ultimo_pacote_exportado']),
      exportedPackageSha256: _string(json['ultimo_sha256_exportado']),
      notApplicableItems: _stringList(json['nao_aplicavel']),
      metadata: ForensicCaseMetadata.fromJson(
        _map(json['metadados_periciais']),
      ),
      caseData: CaseData.fromJson(_map(json['caso'])),
      location: LocationRecord.fromJson(_map(json['localizacao'])),
      gpsTrack: _list(
        json['gps_leituras'],
      ).map((item) => LocationRecord.fromJson(_map(item))).toList(),
      timeline: _list(
        json['timeline'],
      ).map((item) => OccurrenceTimelineEvent.fromJson(_map(item))).toList(),
      checklist: _list(
        json['checklist'],
      ).map((item) => ChecklistItem.fromJson(_map(item))).toList(),
      photos: _list(
        json['fotos'],
      ).map((item) => FieldPhoto.fromJson(_map(item))).toList(),
      vehicles: _list(
        json['veiculos'],
      ).map((item) => VehicleRecord.fromJson(_map(item))).toList(),
      victims: _list(
        json['vitimas'],
      ).map((item) => VictimRecord.fromJson(_map(item))).toList(),
      traces: _list(
        json['vestigios'],
      ).map((item) => TraceRecord.fromJson(_map(item))).toList(),
      measurements: _list(
        json['medicoes'],
      ).map((item) => MeasurementRecord.fromJson(_map(item))).toList(),
      notes: _list(
        json['observacoes'],
      ).map((item) => FieldNote.fromJson(_map(item))).toList(),
    );
  }

  OperationalItemState _caseDataState() {
    final filled = [
      caseData.bo,
      caseData.requisition,
      caseData.protocol,
      caseData.policeUnit,
      caseData.municipality,
      caseData.district,
      caseData.street,
      caseData.reference,
      caseData.peritians,
      caseData.supportTeam,
    ].where((value) => value.trim().isNotEmpty).length;
    if (filled >= 3) {
      return OperationalItemState.completed;
    }
    if (filled > 0) {
      return OperationalItemState.partial;
    }
    return OperationalItemState.pending;
  }

  OperationalItemState _photosState() {
    if (photos.isEmpty) {
      return OperationalItemState.pending;
    }
    if (photos.length < 3) {
      return OperationalItemState.partial;
    }
    return OperationalItemState.completed;
  }

  OperationalItemState _tracePhotosState() {
    if (isNotApplicable(OperationalItemIds.traces) ||
        isNotApplicable(OperationalItemIds.tracePhotos)) {
      return OperationalItemState.notApplicable;
    }
    return hasTracePhoto
        ? OperationalItemState.completed
        : OperationalItemState.pending;
  }

  OperationalItemState _moduleState({
    required String itemId,
    required bool hasData,
  }) {
    if (isNotApplicable(itemId)) {
      return OperationalItemState.notApplicable;
    }
    return hasData
        ? OperationalItemState.completed
        : OperationalItemState.pending;
  }

  OperationalItemState _traceGroupState({required bool hasData}) {
    if (isNotApplicable(OperationalItemIds.traces)) {
      return OperationalItemState.notApplicable;
    }
    return hasData
        ? OperationalItemState.completed
        : traces.isEmpty
        ? OperationalItemState.pending
        : OperationalItemState.partial;
  }

  OperationalItemState _checklistState() {
    if (checklist.isEmpty || answeredChecklistItems == 0) {
      return OperationalItemState.pending;
    }
    if (!checklistFullyAnswered || pendingRequiredChecklistItems > 0) {
      return OperationalItemState.partial;
    }
    return OperationalItemState.completed;
  }
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
};

const _weaponObjectTraceTypes = {
  TraceType.coldWeapon,
  TraceType.firearm,
  TraceType.struggleSign,
  TraceType.footprint,
  TraceType.displacedObject,
  TraceType.detachedPart,
};

String _string(Object? value) => value is String ? value : '';

DateTime? _date(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}

Map<String, Object?> _map(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  return const {};
}

List<Object?> _list(Object? value) => value is List ? value : const [];

List<String> _stringList(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value.whereType<String>().toList();
}

bool _isBetterGps(LocationRecord candidate, LocationRecord currentBest) {
  final candidateAccuracy = candidate.accuracyMeters;
  final bestAccuracy = currentBest.accuracyMeters;
  if (candidateAccuracy == null) {
    return false;
  }
  if (bestAccuracy == null) {
    return true;
  }
  return candidateAccuracy < bestAccuracy;
}

String _natureLabel(ForensicCaseMetadata metadata) {
  return switch (metadata.type) {
    ForensicCaseType.traffic => metadata.trafficNature?.label ?? '',
    ForensicCaseType.violentDeath => metadata.violentDeathNature?.label ?? '',
    ForensicCaseType.property => metadata.propertyNature?.label ?? '',
  };
}

double _distanceMeters(LocationRecord a, LocationRecord b) {
  final lat1 = _radians(a.latitude ?? 0);
  final lon1 = _radians(a.longitude ?? 0);
  final lat2 = _radians(b.latitude ?? 0);
  final lon2 = _radians(b.longitude ?? 0);
  final dLat = lat2 - lat1;
  final dLon = lon2 - lon1;
  final haversine =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1) * math.cos(lat2) * math.sin(dLon / 2) * math.sin(dLon / 2);
  return 6371000 *
      2 *
      math.atan2(math.sqrt(haversine), math.sqrt(1 - haversine));
}

double _radians(double degrees) {
  return degrees * math.pi / 180;
}
