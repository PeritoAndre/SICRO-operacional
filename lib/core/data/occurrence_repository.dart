import 'package:flutter/foundation.dart';

import '../../domain/models/case_data.dart';
import '../../domain/models/checklist_item.dart';
import '../../domain/models/field_note.dart';
import '../../domain/models/field_photo.dart';
import '../../domain/models/forensic_case_metadata.dart';
import '../../domain/models/location_record.dart';
import '../../domain/models/measurement_record.dart';
import '../../domain/models/occurrence.dart';
import '../../domain/models/trace_record.dart';
import '../../domain/models/vehicle_record.dart';
import '../../domain/models/victim_record.dart';
import 'occurrence_storage.dart';

class OccurrenceRepository extends ChangeNotifier {
  OccurrenceRepository({OccurrenceStorage? storage})
    : _storage = storage ?? MemoryOccurrenceStorage();

  final OccurrenceStorage _storage;
  final List<FieldOccurrence> _occurrences = [];
  bool _loaded = false;
  String? _lastError;

  bool get loaded => _loaded;

  String? get lastError => _lastError;

  List<FieldOccurrence> get occurrences {
    final copy = [..._occurrences];
    copy.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return copy;
  }

  FieldOccurrence? findById(String id) {
    for (final occurrence in _occurrences) {
      if (occurrence.id == id) {
        return occurrence;
      }
    }
    return null;
  }

  Future<void> load() async {
    if (_loaded) {
      return;
    }
    try {
      final loadedOccurrences = await _storage.loadOccurrences();
      final normalizedOccurrences = loadedOccurrences
          .map(_normalizeOccurrence)
          .toList();
      _occurrences
        ..clear()
        ..addAll(normalizedOccurrences);
      if (_hasNormalizationChanges(loadedOccurrences, normalizedOccurrences)) {
        await _storage.saveOccurrences(_occurrences);
      }
      _lastError = null;
    } catch (error) {
      _lastError = error.toString();
      _occurrences.clear();
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<FieldOccurrence> createOccurrence(
    CaseData caseData, {
    ForensicCaseMetadata metadata = const ForensicCaseMetadata(),
  }) async {
    final now = DateTime.now();
    final occurrence = FieldOccurrence(
      id: _newId('occ'),
      createdAt: now,
      updatedAt: now,
      startedAt: now,
      metadata: metadata,
      caseData: caseData,
      checklist: defaultChecklistFor(metadata),
      timeline: [
        _timelineEvent(
          OccurrenceTimelineEventType.created,
          occurredAt: now,
          description: 'Dossie operacional criado no aparelho.',
        ),
        _timelineEvent(
          OccurrenceTimelineEventType.gpsStarted,
          occurredAt: now,
          description: 'Sessao operacional iniciada para captura GPS.',
        ),
      ],
    );
    _occurrences.add(occurrence);
    notifyListeners();
    await _persist();
    return occurrence;
  }

  Future<FieldOccurrence?> deleteOccurrence(String id) async {
    final index = _occurrences.indexWhere((occurrence) => occurrence.id == id);
    if (index == -1) {
      return null;
    }

    final removed = _occurrences.removeAt(index);
    notifyListeners();

    try {
      await _storage.saveOccurrences(_occurrences);
      _lastError = null;
      return removed;
    } catch (error) {
      _occurrences.insert(index, removed);
      _lastError = error.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateCaseData(String id, CaseData caseData) async {
    await _replace(id, (occurrence) {
      return occurrence.copyWith(caseData: caseData, updatedAt: DateTime.now());
    });
  }

  Future<void> updateStatus(String id, OccurrenceStatus status) async {
    await _replace(id, (occurrence) {
      final now = DateTime.now();
      final wasFinished = occurrence.sessionFinished;
      var updated = occurrence.copyWith(
        status: status,
        finishedAt: status == OccurrenceStatus.inProgress
            ? occurrence.finishedAt
            : occurrence.finishedAt ?? now,
        clearFinishedAt: status == OccurrenceStatus.inProgress,
        updatedAt: now,
      );
      if (status == OccurrenceStatus.inProgress && wasFinished) {
        updated = _appendTimeline(
          updated,
          OccurrenceTimelineEventType.reopened,
          occurredAt: now,
          description: 'Ocorrencia reaberta para continuidade operacional.',
        );
      } else if (status == OccurrenceStatus.archived) {
        updated = _appendTimeline(
          updated,
          OccurrenceTimelineEventType.archived,
          occurredAt: now,
          description: 'Ocorrencia arquivada localmente.',
        );
      } else if (status != occurrence.status) {
        updated = _appendTimeline(
          updated,
          OccurrenceTimelineEventType.statusChanged,
          occurredAt: now,
          description: 'Status alterado para ${status.label}.',
        );
      }
      return updated;
    });
  }

  Future<void> completeOccurrence(
    String id, {
    DateTime? finishedAt,
    OccurrenceStatus status = OccurrenceStatus.completed,
  }) async {
    final finished = finishedAt ?? DateTime.now();
    await _replace(id, (occurrence) {
      final updated = occurrence.copyWith(
        status: status,
        finishedAt: finished,
        updatedAt: finished,
      );
      return _appendTimeline(
        updated,
        OccurrenceTimelineEventType.completed,
        occurredAt: finished,
        description: 'Pericia encerrada como ${status.label}.',
      );
    });
  }

  Future<void> markExported(
    String id, {
    required DateTime exportedAt,
    required String packageName,
    required String sha256,
  }) async {
    await _replace(id, (occurrence) {
      return occurrence.copyWith(
        status: OccurrenceStatus.exported,
        finishedAt: occurrence.finishedAt ?? exportedAt,
        exportedAt: exportedAt,
        exportedPackageName: packageName,
        exportedPackageSha256: sha256,
        updatedAt: DateTime.now(),
      );
    });
    await _replace(id, (occurrence) {
      return _appendTimeline(
        occurrence,
        OccurrenceTimelineEventType.exported,
        occurredAt: exportedAt,
        description: 'Pacote $packageName gerado e hash registrado.',
      );
    });
  }

  Future<void> setOperationalItemNotApplicable(
    String id,
    String itemId,
    bool notApplicable,
  ) async {
    await _replace(id, (occurrence) {
      final items = [...occurrence.notApplicableItems];
      if (notApplicable) {
        if (!items.contains(itemId)) {
          items.add(itemId);
        }
      } else {
        items.remove(itemId);
      }
      return occurrence.copyWith(
        notApplicableItems: items,
        updatedAt: DateTime.now(),
      );
    });
  }

  Future<void> updateLocation(String id, LocationRecord location) async {
    await _replace(id, (occurrence) {
      final hadCoordinates = occurrence.location.hasCoordinates;
      final gpsTrack = location.hasCoordinates
          ? _trimGpsTrack([...occurrence.gpsTrack, location])
          : occurrence.gpsTrack;
      var updated = occurrence.copyWith(
        location: location,
        gpsTrack: gpsTrack,
        updatedAt: DateTime.now(),
      );
      if (location.hasCoordinates && !hadCoordinates) {
        updated = _appendTimeline(
          updated,
          OccurrenceTimelineEventType.gpsCaptured,
          occurredAt: location.capturedAt ?? DateTime.now(),
          description: 'Primeira coordenada principal registrada.',
          once: true,
        );
      }
      return updated;
    });
  }

  Future<void> addGpsReading(String id, LocationRecord reading) async {
    if (!reading.hasCoordinates) {
      return;
    }

    await _replace(id, (occurrence) {
      if (!occurrence.sessionActive) {
        return occurrence;
      }
      final gpsTrack = _trimGpsTrack([...occurrence.gpsTrack, reading]);
      final best = occurrence.bestGpsLocation;
      final shouldUseAsBest = best == null || _isBetterLocation(reading, best);
      var updated = occurrence.copyWith(
        location: shouldUseAsBest ? reading : occurrence.location,
        gpsTrack: gpsTrack,
        updatedAt: DateTime.now(),
      );
      if (!occurrence.location.hasCoordinates) {
        updated = _appendTimeline(
          updated,
          OccurrenceTimelineEventType.gpsCaptured,
          occurredAt: reading.capturedAt ?? DateTime.now(),
          description: 'Primeira leitura GPS registrada automaticamente.',
          once: true,
        );
      }
      return updated;
    });
  }

  Future<void> updateChecklistItem(
    String id,
    String itemId, {
    ChecklistAnswer? answer,
    String? note,
  }) async {
    await _replace(id, (occurrence) {
      final checklist = [...occurrence.checklist];
      final index = checklist.indexWhere((item) => item.id == itemId);
      if (index == -1) {
        return occurrence;
      }
      checklist[index] = checklist[index].copyWith(answer: answer, note: note);
      return occurrence.copyWith(
        checklist: checklist,
        updatedAt: DateTime.now(),
      );
    });
  }

  Future<ChecklistItem?> addChecklistItem(
    String id, {
    required ChecklistCategory category,
    required String question,
    required bool required,
    String defaultNote = '',
  }) async {
    final trimmedQuestion = question.trim();
    if (trimmedQuestion.isEmpty) {
      return null;
    }
    ChecklistItem? created;
    await _replace(id, (occurrence) {
      created = ChecklistItem(
        id: _newId('checklist'),
        category: category,
        question: trimmedQuestion,
        required: required,
        defaultNote: defaultNote.trim(),
        origin: ChecklistItemOrigin.added,
      );
      return occurrence.copyWith(
        checklist: [...occurrence.checklist, created!],
        updatedAt: DateTime.now(),
      );
    });
    return created;
  }

  Future<void> updateChecklistQuestion(String id, ChecklistItem item) async {
    final trimmedQuestion = item.question.trim();
    if (trimmedQuestion.isEmpty) {
      return;
    }
    await _replace(id, (occurrence) {
      final checklist = [...occurrence.checklist];
      final index = checklist.indexWhere((current) => current.id == item.id);
      if (index == -1) {
        return occurrence;
      }
      checklist[index] = checklist[index].copyWith(
        category: item.category,
        question: trimmedQuestion,
        required: item.required,
        defaultNote: item.defaultNote.trim(),
      );
      return occurrence.copyWith(
        checklist: checklist,
        updatedAt: DateTime.now(),
      );
    });
  }

  Future<ChecklistItem?> removeChecklistItem(String id, String itemId) async {
    ChecklistItem? removed;
    await _replace(id, (occurrence) {
      final checklist = [...occurrence.checklist];
      final index = checklist.indexWhere((item) => item.id == itemId);
      if (index == -1) {
        return occurrence;
      }
      removed = checklist.removeAt(index);
      return occurrence.copyWith(
        checklist: checklist,
        updatedAt: DateTime.now(),
      );
    });
    return removed;
  }

  Future<void> addPhoto(String id, FieldPhoto photo) async {
    await _replace(id, (occurrence) {
      final notApplicableItems = [...occurrence.notApplicableItems];
      if (photo.category == PhotoCategory.trace ||
          photo.category == PhotoCategory.braking) {
        notApplicableItems.remove(OperationalItemIds.tracePhotos);
      }
      var updated = occurrence.copyWith(
        photos: [...occurrence.photos, photo],
        notApplicableItems: notApplicableItems,
        updatedAt: DateTime.now(),
      );
      if (occurrence.photos.isEmpty) {
        updated = _appendTimeline(
          updated,
          OccurrenceTimelineEventType.firstPhoto,
          occurredAt: photo.capturedAt,
          description: 'Primeira foto capturada no dossie.',
          once: true,
        );
      }
      return updated;
    });
  }

  Future<FieldPhoto?> removePhoto(String id, String photoId) async {
    FieldPhoto? removed;
    await _replace(id, (occurrence) {
      final photos = [...occurrence.photos];
      final index = photos.indexWhere((photo) => photo.id == photoId);
      if (index == -1) {
        return occurrence;
      }
      removed = photos.removeAt(index);
      final vehicles = occurrence.vehicles
          .map(
            (vehicle) => vehicle.copyWith(
              photoIds: _withoutId(vehicle.photoIds, photoId),
            ),
          )
          .toList();
      final victims = occurrence.victims
          .map(
            (victim) =>
                victim.copyWith(photoIds: _withoutId(victim.photoIds, photoId)),
          )
          .toList();
      final traces = occurrence.traces
          .map(
            (trace) =>
                trace.copyWith(photoIds: _withoutId(trace.photoIds, photoId)),
          )
          .toList();
      final measurements = occurrence.measurements
          .map(
            (measurement) => measurement.copyWith(
              photoIds: _withoutId(measurement.photoIds, photoId),
            ),
          )
          .toList();

      return occurrence.copyWith(
        photos: photos,
        vehicles: vehicles,
        victims: victims,
        traces: traces,
        measurements: measurements,
        updatedAt: DateTime.now(),
      );
    });
    return removed;
  }

  Future<VehicleRecord?> createVehicle(String id) async {
    VehicleRecord? created;
    await _replace(id, (occurrence) {
      created = VehicleRecord(
        id: _newId('vehicle'),
        identifier: _nextVehicleIdentifier(occurrence.vehicles),
      );
      return occurrence.copyWith(
        vehicles: [...occurrence.vehicles, created!],
        notApplicableItems: _withoutId(
          occurrence.notApplicableItems,
          OperationalItemIds.vehicles,
        ),
        updatedAt: DateTime.now(),
      );
    });
    return created;
  }

  Future<void> updateVehicle(String id, VehicleRecord vehicle) async {
    await _replace(id, (occurrence) {
      final vehicles = [...occurrence.vehicles];
      final index = vehicles.indexWhere((item) => item.id == vehicle.id);
      if (index == -1) {
        return occurrence;
      }
      vehicles[index] = vehicle;
      return occurrence.copyWith(vehicles: vehicles, updatedAt: DateTime.now());
    });
  }

  Future<VehicleRecord?> removeVehicle(String id, String vehicleId) async {
    VehicleRecord? removed;
    await _replace(id, (occurrence) {
      final vehicles = [...occurrence.vehicles];
      final index = vehicles.indexWhere((vehicle) => vehicle.id == vehicleId);
      if (index == -1) {
        return occurrence;
      }
      removed = vehicles.removeAt(index);
      return occurrence.copyWith(vehicles: vehicles, updatedAt: DateTime.now());
    });
    return removed;
  }

  Future<VictimRecord?> createVictim(String id) async {
    VictimRecord? created;
    await _replace(id, (occurrence) {
      created = VictimRecord(
        id: _newId('victim'),
        identifier: _nextVictimIdentifier(occurrence.victims),
      );
      return occurrence.copyWith(
        victims: [...occurrence.victims, created!],
        notApplicableItems: _withoutId(
          occurrence.notApplicableItems,
          OperationalItemIds.victims,
        ),
        updatedAt: DateTime.now(),
      );
    });
    return created;
  }

  Future<void> updateVictim(String id, VictimRecord victim) async {
    await _replace(id, (occurrence) {
      final victims = [...occurrence.victims];
      final index = victims.indexWhere((item) => item.id == victim.id);
      if (index == -1) {
        return occurrence;
      }
      victims[index] = victim;
      return occurrence.copyWith(victims: victims, updatedAt: DateTime.now());
    });
  }

  Future<VictimRecord?> removeVictim(String id, String victimId) async {
    VictimRecord? removed;
    await _replace(id, (occurrence) {
      final victims = [...occurrence.victims];
      final index = victims.indexWhere((victim) => victim.id == victimId);
      if (index == -1) {
        return occurrence;
      }
      removed = victims.removeAt(index);
      return occurrence.copyWith(victims: victims, updatedAt: DateTime.now());
    });
    return removed;
  }

  Future<TraceRecord?> createTrace(String id) async {
    TraceRecord? created;
    await _replace(id, (occurrence) {
      created = TraceRecord(
        id: _newId('trace'),
        identifier: _nextTraceIdentifier(occurrence.traces),
        type: _defaultTraceTypeFor(occurrence.metadata),
      );
      return occurrence.copyWith(
        traces: [...occurrence.traces, created!],
        notApplicableItems: _withoutId(
          occurrence.notApplicableItems,
          OperationalItemIds.traces,
        ),
        updatedAt: DateTime.now(),
      );
    });
    return created;
  }

  Future<void> updateTrace(String id, TraceRecord trace) async {
    await _replace(id, (occurrence) {
      final traces = [...occurrence.traces];
      final index = traces.indexWhere((item) => item.id == trace.id);
      if (index == -1) {
        return occurrence;
      }
      traces[index] = trace;
      return occurrence.copyWith(traces: traces, updatedAt: DateTime.now());
    });
  }

  Future<TraceRecord?> removeTrace(String id, String traceId) async {
    TraceRecord? removed;
    await _replace(id, (occurrence) {
      final traces = [...occurrence.traces];
      final index = traces.indexWhere((trace) => trace.id == traceId);
      if (index == -1) {
        return occurrence;
      }
      removed = traces.removeAt(index);
      return occurrence.copyWith(traces: traces, updatedAt: DateTime.now());
    });
    return removed;
  }

  Future<MeasurementRecord?> createMeasurement(String id) async {
    MeasurementRecord? created;
    await _replace(id, (occurrence) {
      created = MeasurementRecord(
        id: _newId('measurement'),
        label: _nextMeasurementIdentifier(occurrence.measurements),
        value: 0,
        method: 'trena',
      );
      return occurrence.copyWith(
        measurements: [...occurrence.measurements, created!],
        notApplicableItems: _withoutId(
          occurrence.notApplicableItems,
          OperationalItemIds.measurements,
        ),
        updatedAt: DateTime.now(),
      );
    });
    return created;
  }

  Future<void> updateMeasurement(
    String id,
    MeasurementRecord measurement,
  ) async {
    await _replace(id, (occurrence) {
      final measurements = [...occurrence.measurements];
      final index = measurements.indexWhere(
        (item) => item.id == measurement.id,
      );
      if (index == -1) {
        return occurrence;
      }
      measurements[index] = measurement;
      return occurrence.copyWith(
        measurements: measurements,
        updatedAt: DateTime.now(),
      );
    });
  }

  Future<MeasurementRecord?> removeMeasurement(
    String id,
    String measurementId,
  ) async {
    MeasurementRecord? removed;
    await _replace(id, (occurrence) {
      final measurements = [...occurrence.measurements];
      final index = measurements.indexWhere(
        (measurement) => measurement.id == measurementId,
      );
      if (index == -1) {
        return occurrence;
      }
      removed = measurements.removeAt(index);
      return occurrence.copyWith(
        measurements: measurements,
        updatedAt: DateTime.now(),
      );
    });
    return removed;
  }

  Future<FieldNote?> createNote(String id) async {
    FieldNote? created;
    await _replace(id, (occurrence) {
      final now = DateTime.now();
      created = FieldNote(id: _newId('note'), createdAt: now, text: '');
      return occurrence.copyWith(
        notes: [...occurrence.notes, created!],
        updatedAt: DateTime.now(),
      );
    });
    return created;
  }

  Future<void> updateNote(String id, FieldNote note) async {
    await _replace(id, (occurrence) {
      final notes = [...occurrence.notes];
      final index = notes.indexWhere((item) => item.id == note.id);
      if (index == -1) {
        return occurrence;
      }
      notes[index] = note.copyWith(updatedAt: DateTime.now());
      return occurrence.copyWith(notes: notes, updatedAt: DateTime.now());
    });
  }

  Future<FieldNote?> removeNote(String id, String noteId) async {
    FieldNote? removed;
    await _replace(id, (occurrence) {
      final notes = [...occurrence.notes];
      final index = notes.indexWhere((note) => note.id == noteId);
      if (index == -1) {
        return occurrence;
      }
      removed = notes.removeAt(index);
      return occurrence.copyWith(notes: notes, updatedAt: DateTime.now());
    });
    return removed;
  }

  Future<void> _replace(
    String id,
    FieldOccurrence Function(FieldOccurrence occurrence) update,
  ) async {
    final index = _occurrences.indexWhere((occurrence) => occurrence.id == id);
    if (index == -1) {
      return;
    }
    _occurrences[index] = update(_occurrences[index]);
    notifyListeners();
    await _persist();
  }

  String _newId(String prefix) {
    return '${prefix}_${DateTime.now().microsecondsSinceEpoch}';
  }

  OccurrenceTimelineEvent _timelineEvent(
    OccurrenceTimelineEventType type, {
    required DateTime occurredAt,
    String description = '',
  }) {
    return OccurrenceTimelineEvent(
      id: _newId('timeline'),
      type: type,
      occurredAt: occurredAt,
      description: description,
    );
  }

  FieldOccurrence _appendTimeline(
    FieldOccurrence occurrence,
    OccurrenceTimelineEventType type, {
    required DateTime occurredAt,
    String description = '',
    bool once = false,
  }) {
    if (once &&
        occurrence.effectiveTimeline.any((event) => event.type == type)) {
      return occurrence;
    }
    return occurrence.copyWith(
      timeline: [
        ...occurrence.effectiveTimeline,
        _timelineEvent(type, occurredAt: occurredAt, description: description),
      ],
    );
  }

  String _nextVehicleIdentifier(List<VehicleRecord> vehicles) {
    final matcher = RegExp(r'^V(\d+)$');
    var highest = 0;
    for (final vehicle in vehicles) {
      final match = matcher.firstMatch(vehicle.identifier);
      final number = match == null ? null : int.tryParse(match.group(1) ?? '');
      if (number != null && number > highest) {
        highest = number;
      }
    }
    return 'V${highest + 1}';
  }

  String _nextVictimIdentifier(List<VictimRecord> victims) {
    final matcher = RegExp(r'^P(\d+)$');
    var highest = 0;
    for (final victim in victims) {
      final match = matcher.firstMatch(victim.identifier);
      final number = match == null ? null : int.tryParse(match.group(1) ?? '');
      if (number != null && number > highest) {
        highest = number;
      }
    }
    return 'P${highest + 1}';
  }

  String _nextTraceIdentifier(List<TraceRecord> traces) {
    final matcher = RegExp(r'^V(\d+)$');
    var highest = 0;
    for (final trace in traces) {
      final match = matcher.firstMatch(trace.identifier);
      final number = match == null ? null : int.tryParse(match.group(1) ?? '');
      if (number != null && number > highest) {
        highest = number;
      }
    }
    return 'V${highest + 1}';
  }

  String _nextMeasurementIdentifier(List<MeasurementRecord> measurements) {
    final matcher = RegExp(r'^M(\d+)$');
    var highest = 0;
    for (final measurement in measurements) {
      final match = matcher.firstMatch(measurement.label);
      final number = match == null ? null : int.tryParse(match.group(1) ?? '');
      if (number != null && number > highest) {
        highest = number;
      }
    }
    return 'M${highest + 1}';
  }

  List<String> _withoutId(List<String> ids, String id) {
    return ids.where((item) => item != id).toList(growable: false);
  }

  List<LocationRecord> _trimGpsTrack(List<LocationRecord> readings) {
    const maxReadings = 1000;
    if (readings.length <= maxReadings) {
      return readings;
    }
    return readings.sublist(readings.length - maxReadings);
  }

  bool _isBetterLocation(LocationRecord candidate, LocationRecord currentBest) {
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

  Future<void> _persist() async {
    try {
      await _storage.saveOccurrences(_occurrences);
      _lastError = null;
    } catch (error) {
      _lastError = error.toString();
      notifyListeners();
    }
  }
}

FieldOccurrence _normalizeOccurrence(FieldOccurrence occurrence) {
  if (occurrence.metadata.type == ForensicCaseType.violentDeath &&
      _shouldReplaceLegacyChecklist(occurrence)) {
    return occurrence.copyWith(checklist: defaultViolentDeathChecklist());
  }
  if (occurrence.metadata.type == ForensicCaseType.property &&
      _shouldReplaceLegacyPropertyChecklist(occurrence)) {
    return occurrence.copyWith(
      checklist: defaultPropertyChecklist(occurrence.metadata.propertyNature),
    );
  }
  return occurrence;
}

bool _shouldReplaceLegacyChecklist(FieldOccurrence occurrence) {
  if (occurrence.checklist.isEmpty) {
    return true;
  }
  if (occurrence.checklist.any(
    (item) => item.origin == ChecklistItemOrigin.added,
  )) {
    return false;
  }
  final hasViolentDeathChecklist = occurrence.checklist.any(
    (item) => item.id.startsWith('mv_'),
  );
  if (hasViolentDeathChecklist) {
    return false;
  }
  return occurrence.answeredChecklistItems == 0;
}

bool _shouldReplaceLegacyPropertyChecklist(FieldOccurrence occurrence) {
  if (occurrence.checklist.isEmpty) {
    return true;
  }
  if (occurrence.checklist.any(
    (item) => item.origin == ChecklistItemOrigin.added,
  )) {
    return false;
  }
  final hasPropertyChecklist = occurrence.checklist.any(
    (item) => item.id.startsWith('pat_'),
  );
  if (hasPropertyChecklist) {
    return false;
  }
  return occurrence.answeredChecklistItems == 0;
}

bool _hasNormalizationChanges(
  List<FieldOccurrence> original,
  List<FieldOccurrence> normalized,
) {
  if (original.length != normalized.length) {
    return true;
  }
  for (var index = 0; index < original.length; index++) {
    final before = original[index].checklist.map((item) => item.id).join('|');
    final after = normalized[index].checklist.map((item) => item.id).join('|');
    if (before != after) {
      return true;
    }
  }
  return false;
}

List<ChecklistItem> defaultChecklistFor(ForensicCaseMetadata metadata) {
  return switch (metadata.type) {
    ForensicCaseType.traffic => defaultTrafficChecklist(),
    ForensicCaseType.violentDeath => defaultViolentDeathChecklist(),
    ForensicCaseType.property => defaultPropertyChecklist(
      metadata.propertyNature,
    ),
  };
}

TraceType _defaultTraceTypeFor(ForensicCaseMetadata metadata) {
  if (metadata.type == ForensicCaseType.violentDeath) {
    return TraceType.biological;
  }
  if (metadata.type == ForensicCaseType.property) {
    return switch (metadata.propertyNature) {
      PropertyNature.burglary => TraceType.toolMark,
      PropertyNature.fire => TraceType.thermalDamage,
      PropertyNature.damages => TraceType.damage,
      PropertyNature.directEvaluation => TraceType.other,
      PropertyNature.indirectEvaluation => TraceType.other,
      null => TraceType.other,
    };
  }
  return TraceType.braking;
}

List<ChecklistItem> defaultTrafficChecklist() {
  return const [
    ChecklistItem(
      id: 'local_preservado',
      category: ChecklistCategory.preservation,
      question: 'Local isolado/preservado?',
      required: true,
    ),
    ChecklistItem(
      id: 'area_isolada',
      category: ChecklistCategory.preservation,
      question: 'Area isolada adequadamente?',
      required: true,
    ),
    ChecklistItem(
      id: 'vitimas_removidas',
      category: ChecklistCategory.victims,
      question: 'Vitimas removidas antes da chegada?',
      required: true,
    ),
    ChecklistItem(
      id: 'atendimento_medico',
      category: ChecklistCategory.victims,
      question: 'Atendimento medico identificado/registrado?',
    ),
    ChecklistItem(
      id: 'veiculos_removidos',
      category: ChecklistCategory.vehicles,
      question: 'Veiculos removidos antes da chegada?',
      required: true,
    ),
    ChecklistItem(
      id: 'posicoes_finais_preservadas',
      category: ChecklistCategory.vehicles,
      question: 'Posicoes finais dos veiculos preservadas?',
    ),
    ChecklistItem(
      id: 'sentido_via_identificado',
      category: ChecklistCategory.roadConditions,
      question: 'Sentido(s) de trafego identificado(s)?',
      required: true,
    ),
    ChecklistItem(
      id: 'tipo_via_registrado',
      category: ChecklistCategory.roadConditions,
      question: 'Tipo de via registrado?',
    ),
    ChecklistItem(
      id: 'pavimento_molhado',
      category: ChecklistCategory.pavement,
      question: 'Pavimento molhado?',
      required: true,
    ),
    ChecklistItem(
      id: 'defeito_pavimento',
      category: ChecklistCategory.pavement,
      question: 'Defeitos relevantes no pavimento?',
    ),
    ChecklistItem(
      id: 'iluminacao_existente',
      category: ChecklistCategory.lighting,
      question: 'Iluminacao publica existente?',
    ),
    ChecklistItem(
      id: 'iluminacao_funcionando',
      category: ChecklistCategory.lighting,
      question: 'Iluminacao publica funcionando?',
    ),
    ChecklistItem(
      id: 'chuva_momento',
      category: ChecklistCategory.weatherVisibility,
      question: 'Chovia no momento do exame?',
    ),
    ChecklistItem(
      id: 'visibilidade_reduzida',
      category: ChecklistCategory.weatherVisibility,
      question: 'Visibilidade reduzida?',
    ),
    ChecklistItem(
      id: 'sinalizacao_vertical',
      category: ChecklistCategory.signaling,
      question: 'Sinalizacao vertical presente?',
    ),
    ChecklistItem(
      id: 'sinalizacao_horizontal',
      category: ChecklistCategory.signaling,
      question: 'Sinalizacao horizontal presente?',
    ),
    ChecklistItem(
      id: 'semaforo_existente',
      category: ChecklistCategory.trafficLight,
      question: 'Semaforo existente no trecho/intersecao?',
    ),
    ChecklistItem(
      id: 'semaforo_funcionando',
      category: ChecklistCategory.trafficLight,
      question: 'Semaforo existente e funcionando?',
    ),
    ChecklistItem(
      id: 'marcas_frenagem',
      category: ChecklistCategory.traces,
      question: 'Marcas de frenagem?',
      required: true,
    ),
    ChecklistItem(
      id: 'marcas_arrasto',
      category: ChecklistCategory.traces,
      question: 'Marcas de arrasto?',
    ),
    ChecklistItem(
      id: 'fragmentos',
      category: ChecklistCategory.traces,
      question: 'Fragmentos ou pecas no local?',
    ),
    ChecklistItem(
      id: 'vestigios_removidos',
      category: ChecklistCategory.traces,
      question: 'Vestigios removidos por terceiros?',
      required: true,
    ),
  ];
}

List<ChecklistItem> defaultViolentDeathChecklist() {
  return const [
    ChecklistItem(
      id: 'mv_local_isolado',
      category: ChecklistCategory.preservation,
      question: 'Local isolado?',
      required: true,
    ),
    ChecklistItem(
      id: 'mv_alteracao_antes_chegada',
      category: ChecklistCategory.preservation,
      question: 'Houve alteracao antes da chegada?',
      required: true,
    ),
    ChecklistItem(
      id: 'mv_corpo_removido_antes_pericia',
      category: ChecklistCategory.preservation,
      question: 'Corpo removido antes da pericia?',
      required: true,
    ),
    ChecklistItem(
      id: 'mv_vestigios_removidos_manipulados',
      category: ChecklistCategory.preservation,
      question: 'Vestigios removidos/manipulados?',
      required: true,
    ),
    ChecklistItem(
      id: 'mv_pessoas_presentes_identificadas',
      category: ChecklistCategory.preservation,
      question: 'Pessoas presentes no local identificadas?',
    ),
    ChecklistItem(
      id: 'mv_corpo_presente_local',
      category: ChecklistCategory.bodyVictim,
      question: 'Corpo presente no local?',
      required: true,
    ),
    ChecklistItem(
      id: 'mv_posicao_corporal_registrada',
      category: ChecklistCategory.bodyVictim,
      question: 'Posicao corporal registrada?',
      required: true,
    ),
    ChecklistItem(
      id: 'mv_vestes_registradas',
      category: ChecklistCategory.bodyVictim,
      question: 'Vestes registradas?',
    ),
    ChecklistItem(
      id: 'mv_sinais_violencia_observados',
      category: ChecklistCategory.bodyVictim,
      question: 'Sinais aparentes de violencia observados?',
    ),
    ChecklistItem(
      id: 'mv_rigidez_livores_observados',
      category: ChecklistCategory.bodyVictim,
      question: 'Rigidez/livores observados?',
    ),
    ChecklistItem(
      id: 'mv_lesoes_aparentes_fotografadas',
      category: ChecklistCategory.bodyVictim,
      question: 'Lesoes aparentes fotografadas?',
    ),
    ChecklistItem(
      id: 'mv_sangue_manchas_presentes',
      category: ChecklistCategory.biologicalTraces,
      question: 'Sangue/manchas biologicas presentes?',
      required: true,
    ),
    ChecklistItem(
      id: 'mv_gotejamento_poca_arrastamento',
      category: ChecklistCategory.biologicalTraces,
      question: 'Gotejamento/poca/arrastamento?',
    ),
    ChecklistItem(
      id: 'mv_material_biologico_coletado',
      category: ChecklistCategory.biologicalTraces,
      question: 'Material biologico coletado?',
    ),
    ChecklistItem(
      id: 'mv_vestigios_protegidos_contaminacao',
      category: ChecklistCategory.biologicalTraces,
      question: 'Vestigios protegidos da contaminacao?',
    ),
    ChecklistItem(
      id: 'mv_capsulas_estojos_presentes',
      category: ChecklistCategory.ballisticTraces,
      question: 'Capsulas/estojos presentes?',
    ),
    ChecklistItem(
      id: 'mv_projeteis_presentes',
      category: ChecklistCategory.ballisticTraces,
      question: 'Projeteis presentes?',
    ),
    ChecklistItem(
      id: 'mv_perfuracoes_aparentes',
      category: ChecklistCategory.ballisticTraces,
      question: 'Perfuracoes aparentes?',
    ),
    ChecklistItem(
      id: 'mv_impactos_paredes_moveis_veiculos',
      category: ChecklistCategory.ballisticTraces,
      question: 'Impactos em paredes/moveis/veiculos?',
    ),
    ChecklistItem(
      id: 'mv_trajetoria_aparente_observada',
      category: ChecklistCategory.ballisticTraces,
      question: 'Trajetoria aparente observada?',
    ),
    ChecklistItem(
      id: 'mv_arma_fogo_localizada',
      category: ChecklistCategory.weaponsObjects,
      question: 'Arma de fogo localizada?',
    ),
    ChecklistItem(
      id: 'mv_arma_branca_localizada',
      category: ChecklistCategory.weaponsObjects,
      question: 'Arma branca localizada?',
    ),
    ChecklistItem(
      id: 'mv_objetos_deslocados_quebrados',
      category: ChecklistCategory.weaponsObjects,
      question: 'Objetos deslocados/quebrados?',
    ),
    ChecklistItem(
      id: 'mv_sinais_luta',
      category: ChecklistCategory.weaponsObjects,
      question: 'Sinais de luta?',
    ),
    ChecklistItem(
      id: 'mv_pertences_vitima_registrados',
      category: ChecklistCategory.weaponsObjects,
      question: 'Pertences da vitima registrados?',
    ),
    ChecklistItem(
      id: 'mv_local_interno_externo_descrito',
      category: ChecklistCategory.environment,
      question: 'Local interno/externo descrito?',
      required: true,
    ),
    ChecklistItem(
      id: 'mv_iluminacao_observada',
      category: ChecklistCategory.environment,
      question: 'Iluminacao observada?',
    ),
    ChecklistItem(
      id: 'mv_acessos_rotas_registrados',
      category: ChecklistCategory.environment,
      question: 'Acessos/rotas de entrada e saida registrados?',
    ),
    ChecklistItem(
      id: 'mv_cameras_proximas_identificadas',
      category: ChecklistCategory.environment,
      question: 'Cameras proximas identificadas?',
    ),
    ChecklistItem(
      id: 'mv_condicoes_climaticas_relevantes',
      category: ChecklistCategory.environment,
      question: 'Condicoes climaticas relevantes?',
    ),
    ChecklistItem(
      id: 'mv_fotos_gerais_local',
      category: ChecklistCategory.photographicRecord,
      question: 'Fotos gerais do local?',
      required: true,
    ),
    ChecklistItem(
      id: 'mv_fotos_aproximacao',
      category: ChecklistCategory.photographicRecord,
      question: 'Fotos de aproximacao?',
    ),
    ChecklistItem(
      id: 'mv_fotos_corpo',
      category: ChecklistCategory.photographicRecord,
      question: 'Fotos do corpo?',
      required: true,
    ),
    ChecklistItem(
      id: 'mv_fotos_lesoes',
      category: ChecklistCategory.photographicRecord,
      question: 'Fotos de lesoes?',
    ),
    ChecklistItem(
      id: 'mv_fotos_vestigios',
      category: ChecklistCategory.photographicRecord,
      question: 'Fotos de vestigios?',
      required: true,
    ),
    ChecklistItem(
      id: 'mv_fotos_armas_objetos',
      category: ChecklistCategory.photographicRecord,
      question: 'Fotos de armas/objetos?',
    ),
  ];
}

List<ChecklistItem> defaultPropertyChecklist(PropertyNature? nature) {
  return switch (nature) {
    PropertyNature.directEvaluation => _propertyEvaluationChecklist(
      indirect: false,
    ),
    PropertyNature.indirectEvaluation => _propertyEvaluationChecklist(
      indirect: true,
    ),
    PropertyNature.damages => _propertyDamageChecklist(),
    PropertyNature.burglary => _propertyBurglaryChecklist(),
    PropertyNature.fire => _propertyFireChecklist(),
    null => _propertyEvaluationChecklist(indirect: false),
  };
}

List<ChecklistItem> _propertyEvaluationChecklist({required bool indirect}) {
  final prefix = indirect ? 'pat_avaliacao_indireta' : 'pat_avaliacao_direta';
  return [
    ChecklistItem(
      id: '${prefix}_bem_identificado',
      category: ChecklistCategory.propertyGoods,
      question: 'Bem avaliado identificado?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_descricao_registrada',
      category: ChecklistCategory.propertyGoods,
      question: 'Descricao do bem registrada?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_estado_conservacao',
      category: ChecklistCategory.propertyGoods,
      question: 'Estado de conservacao registrado?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_valor_referencia',
      category: ChecklistCategory.propertyGoods,
      question: 'Valor/referencia de avaliacao registrado?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_documentacao_disponivel',
      category: ChecklistCategory.documentation,
      question: indirect
          ? 'Documentacao ou fonte indireta registrada?'
          : 'Documentacao do bem fotografada/registrada?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_fotos_bem',
      category: ChecklistCategory.photographicRecord,
      question: 'Fotos do bem registradas?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_fotos_detalhes',
      category: ChecklistCategory.photographicRecord,
      question: 'Fotos de detalhes/identificadores registradas?',
    ),
  ];
}

List<ChecklistItem> _propertyDamageChecklist() {
  return const [
    ChecklistItem(
      id: 'pat_danos_bem_estrutura_identificada',
      category: ChecklistCategory.damage,
      question: 'Bem/estrutura danificada identificada?',
      required: true,
    ),
    ChecklistItem(
      id: 'pat_danos_extensao_registrada',
      category: ChecklistCategory.damage,
      question: 'Extensao do dano registrada?',
      required: true,
    ),
    ChecklistItem(
      id: 'pat_danos_causa_aparente',
      category: ChecklistCategory.damage,
      question: 'Causa aparente descrita?',
      required: true,
    ),
    ChecklistItem(
      id: 'pat_danos_estado_conservacao',
      category: ChecklistCategory.propertyGoods,
      question: 'Estado de conservacao do bem registrado?',
    ),
    ChecklistItem(
      id: 'pat_danos_medicoes_relevantes',
      category: ChecklistCategory.damage,
      question: 'Dimensoes/medicoes relevantes registradas?',
    ),
    ChecklistItem(
      id: 'pat_danos_fotos_gerais',
      category: ChecklistCategory.photographicRecord,
      question: 'Fotos gerais do bem/estrutura registradas?',
      required: true,
    ),
    ChecklistItem(
      id: 'pat_danos_fotos_detalhes',
      category: ChecklistCategory.photographicRecord,
      question: 'Fotos de detalhe dos danos registradas?',
      required: true,
    ),
  ];
}

List<ChecklistItem> _propertyBurglaryChecklist() {
  return const [
    ChecklistItem(
      id: 'pat_arrombamento_ponto_acesso',
      category: ChecklistCategory.burglary,
      question: 'Ponto de acesso/arrombamento identificado?',
      required: true,
    ),
    ChecklistItem(
      id: 'pat_arrombamento_marcas_ferramenta',
      category: ChecklistCategory.burglary,
      question: 'Marcas de ferramenta registradas?',
      required: true,
    ),
    ChecklistItem(
      id: 'pat_arrombamento_rompimentos',
      category: ChecklistCategory.burglary,
      question: 'Rompimentos registrados?',
    ),
    ChecklistItem(
      id: 'pat_arrombamento_fechaduras',
      category: ChecklistCategory.burglary,
      question: 'Fechaduras/travas examinadas?',
      required: true,
    ),
    ChecklistItem(
      id: 'pat_arrombamento_portas_janelas',
      category: ChecklistCategory.burglary,
      question: 'Portas/janelas examinadas?',
      required: true,
    ),
    ChecklistItem(
      id: 'pat_arrombamento_vestigios_preservados',
      category: ChecklistCategory.traces,
      question: 'Vestigios preservados e fotografados?',
      required: true,
    ),
    ChecklistItem(
      id: 'pat_arrombamento_fotos_gerais',
      category: ChecklistCategory.photographicRecord,
      question: 'Fotos gerais do local registradas?',
      required: true,
    ),
    ChecklistItem(
      id: 'pat_arrombamento_fotos_detalhes',
      category: ChecklistCategory.photographicRecord,
      question: 'Fotos de detalhe das marcas/rompimentos registradas?',
      required: true,
    ),
  ];
}

List<ChecklistItem> _propertyFireChecklist() {
  return const [
    ChecklistItem(
      id: 'pat_incendio_foco_provavel',
      category: ChecklistCategory.fire,
      question: 'Foco provavel registrado?',
      required: true,
    ),
    ChecklistItem(
      id: 'pat_incendio_padrao_queima',
      category: ChecklistCategory.fire,
      question: 'Padrao de queima observado?',
      required: true,
    ),
    ChecklistItem(
      id: 'pat_incendio_danos_termicos',
      category: ChecklistCategory.fire,
      question: 'Danos termicos registrados?',
      required: true,
    ),
    ChecklistItem(
      id: 'pat_incendio_material_combustivel',
      category: ChecklistCategory.fire,
      question: 'Material combustivel identificado?',
    ),
    ChecklistItem(
      id: 'pat_incendio_fuligem_residuos',
      category: ChecklistCategory.fire,
      question: 'Fuligem/residuos registrados?',
    ),
    ChecklistItem(
      id: 'pat_incendio_area_afetada',
      category: ChecklistCategory.fire,
      question: 'Area afetada delimitada/medida?',
      required: true,
    ),
    ChecklistItem(
      id: 'pat_incendio_fotos_gerais',
      category: ChecklistCategory.photographicRecord,
      question: 'Fotos gerais da area afetada registradas?',
      required: true,
    ),
    ChecklistItem(
      id: 'pat_incendio_fotos_detalhes',
      category: ChecklistCategory.photographicRecord,
      question: 'Fotos de detalhes de queima/residuos registradas?',
      required: true,
    ),
  ];
}
