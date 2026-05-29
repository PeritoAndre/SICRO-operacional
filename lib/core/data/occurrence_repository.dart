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

  Future<FieldOccurrence> importOccurrence(FieldOccurrence occurrence) async {
    final now = DateTime.now();
    final imported = _normalizeOccurrence(occurrence.copyWith(updatedAt: now))
        .copyWith(
          timeline: [
            ...occurrence.effectiveTimeline,
            _timelineEvent(
              OccurrenceTimelineEventType.imported,
              occurredAt: now,
              description: 'Dossie importado de pacote .sicroapp recebido.',
            ),
          ],
        );
    _occurrences.add(imported);
    notifyListeners();
    await _persist();
    return imported;
  }

  Future<void> restoreOccurrences(List<FieldOccurrence> occurrences) async {
    final normalizedOccurrences = occurrences
        .map(_normalizeOccurrence)
        .toList();
    _occurrences
      ..clear()
      ..addAll(normalizedOccurrences);
    notifyListeners();
    await _persist();
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
  if (occurrence.metadata.type == ForensicCaseType.environmental &&
      _shouldReplaceLegacyEnvironmentalChecklist(occurrence)) {
    return occurrence.copyWith(
      checklist: defaultEnvironmentalChecklist(
        occurrence.metadata.environmentalNature,
      ),
    );
  }
  if (occurrence.metadata.type == ForensicCaseType.ballistics &&
      _shouldReplaceLegacyBallisticsChecklist(occurrence)) {
    return occurrence.copyWith(
      checklist: defaultBallisticsChecklist(
        occurrence.metadata.ballisticsNature,
      ),
    );
  }
  if (occurrence.metadata.type == ForensicCaseType.audioImage &&
      _shouldReplaceLegacyAudioImageChecklist(occurrence)) {
    return occurrence.copyWith(
      checklist: defaultAudioImageChecklist(
        occurrence.metadata.audioImageNature,
      ),
    );
  }
  if (occurrence.metadata.type == ForensicCaseType.papiloscopy &&
      _shouldReplaceLegacyPapiloscopyChecklist(occurrence)) {
    return occurrence.copyWith(
      checklist: defaultPapiloscopyChecklist(
        occurrence.metadata.papiloscopyNature,
      ),
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
  final hasLocalCrimePopChecklist = occurrence.checklist.any(
    (item) => item.id == 'mv_materiais_equipe_conferidos',
  );
  if (hasViolentDeathChecklist && hasLocalCrimePopChecklist) {
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

bool _shouldReplaceLegacyEnvironmentalChecklist(FieldOccurrence occurrence) {
  if (occurrence.checklist.isEmpty) {
    return true;
  }
  if (occurrence.checklist.any(
    (item) => item.origin == ChecklistItemOrigin.added,
  )) {
    return false;
  }
  final hasEnvironmentalChecklist = occurrence.checklist.any(
    (item) => item.id.startsWith('amb_'),
  );
  if (hasEnvironmentalChecklist) {
    return false;
  }
  return occurrence.answeredChecklistItems == 0;
}

bool _shouldReplaceLegacyBallisticsChecklist(FieldOccurrence occurrence) {
  if (occurrence.checklist.isEmpty) {
    return true;
  }
  if (occurrence.checklist.any(
    (item) => item.origin == ChecklistItemOrigin.added,
  )) {
    return false;
  }
  final hasBallisticsChecklist = occurrence.checklist.any(
    (item) => item.id.startsWith('bal_'),
  );
  if (hasBallisticsChecklist) {
    return false;
  }
  return occurrence.answeredChecklistItems == 0;
}

bool _shouldReplaceLegacyAudioImageChecklist(FieldOccurrence occurrence) {
  if (occurrence.checklist.isEmpty) {
    return true;
  }
  if (occurrence.checklist.any(
    (item) => item.origin == ChecklistItemOrigin.added,
  )) {
    return false;
  }
  final hasAudioImageChecklist = occurrence.checklist.any(
    (item) => item.id.startsWith('ai_'),
  );
  if (hasAudioImageChecklist) {
    return false;
  }
  return occurrence.answeredChecklistItems == 0;
}

bool _shouldReplaceLegacyPapiloscopyChecklist(FieldOccurrence occurrence) {
  if (occurrence.checklist.isEmpty) {
    return true;
  }
  if (occurrence.checklist.any(
    (item) => item.origin == ChecklistItemOrigin.added,
  )) {
    return false;
  }
  final hasPapiloscopyChecklist = occurrence.checklist.any(
    (item) => item.id.startsWith('pap_'),
  );
  if (hasPapiloscopyChecklist) {
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
    ForensicCaseType.environmental => defaultEnvironmentalChecklist(
      metadata.environmentalNature,
    ),
    ForensicCaseType.ballistics => defaultBallisticsChecklist(
      metadata.ballisticsNature,
    ),
    ForensicCaseType.audioImage => defaultAudioImageChecklist(
      metadata.audioImageNature,
    ),
    ForensicCaseType.papiloscopy => defaultPapiloscopyChecklist(
      metadata.papiloscopyNature,
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
  if (metadata.type == ForensicCaseType.environmental) {
    return switch (metadata.environmentalNature) {
      EnvironmentalNature.deforestation => TraceType.vegetationSuppression,
      EnvironmentalNature.animalAbuse => TraceType.biological,
      EnvironmentalNature.waterPollution => TraceType.effluent,
      EnvironmentalNature.forestFire => TraceType.burnIndicator,
      EnvironmentalNature.veterinaryNecropsy => TraceType.animalCadaver,
      EnvironmentalNature.other => TraceType.environmentalSample,
      null => TraceType.environmentalSample,
    };
  }
  if (metadata.type == ForensicCaseType.ballistics) {
    return switch (metadata.ballisticsNature) {
      BallisticsNature.firearmEfficiency => TraceType.firearm,
      BallisticsNature.ammunitionEfficiency => TraceType.cartridge,
      BallisticsNature.gsrCollection => TraceType.gsrSample,
      BallisticsNature.ballisticComparison => TraceType.ballisticCase,
      BallisticsNature.other => TraceType.ballisticCase,
      null => TraceType.ballisticCase,
    };
  }
  if (metadata.type == ForensicCaseType.audioImage) {
    return switch (metadata.audioImageNature) {
      AudioImageNature.cctvPreservation => TraceType.cctvDevice,
      AudioImageNature.speakerComparison => TraceType.audioRecord,
      AudioImageNature.contentAnalysis => TraceType.videoRecord,
      AudioImageNature.imageEnhancement => TraceType.imageRecord,
      AudioImageNature.imageRecognition => TraceType.imageRecord,
      AudioImageNature.facialComparison => TraceType.imageRecord,
      AudioImageNature.imageEditVerification => TraceType.multimediaFile,
      AudioImageNature.statureEstimation => TraceType.imageRecord,
      AudioImageNature.other => TraceType.multimediaFile,
      null => TraceType.multimediaFile,
    };
  }
  if (metadata.type == ForensicCaseType.papiloscopy) {
    return switch (metadata.papiloscopyNature) {
      PapiloscopyNature.criminalIdentification => TraceType.fingerprintRecord,
      PapiloscopyNature.crimeScenePrints => TraceType.latentPrint,
      PapiloscopyNature.labPrints => TraceType.papillaryFragment,
      PapiloscopyNature.necropapiloscopy => TraceType.necroFingerprint,
      PapiloscopyNature.other => TraceType.papillaryFragment,
      null => TraceType.papillaryFragment,
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
      question: 'Tipo de via/pavimento registrado?',
    ),
    ChecklistItem(
      id: 'metodo_croqui_registrado',
      category: ChecklistCategory.sketchSurvey,
      question: 'Metodo de croqui/levantamento registrado?',
      required: true,
      defaultNote: 'Ex.: drone, trena, trena laser, imagens ou outro metodo.',
    ),
    ChecklistItem(
      id: 'levantamento_drone_realizado',
      category: ChecklistCategory.sketchSurvey,
      question: 'Houve levantamento com drone?',
    ),
    ChecklistItem(
      id: 'croqui_manual_trena',
      category: ChecklistCategory.sketchSurvey,
      question: 'Croqui manual com trena/pontos de referencia realizado?',
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
      id: 'marcas_derrapagem',
      category: ChecklistCategory.traces,
      question: 'Marcas de derrapagem/yaw?',
    ),
    ChecklistItem(
      id: 'sulcagem_pavimento',
      category: ChecklistCategory.traces,
      question: 'Sulcagem/sulcos no pavimento?',
    ),
    ChecklistItem(
      id: 'marcas_impacto',
      category: ChecklistCategory.traces,
      question: 'Marcas de impacto em objeto fixo ou estrutura?',
    ),
    ChecklistItem(
      id: 'fluidos_local',
      category: ChecklistCategory.traces,
      question: 'Fluidos ou manchas relevantes no local?',
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
      id: 'mv_materiais_equipe_conferidos',
      category: ChecklistCategory.preservation,
      question: 'Materiais, equipamentos e equipe pericial conferidos?',
      required: true,
    ),
    ChecklistItem(
      id: 'mv_seguranca_local',
      category: ChecklistCategory.preservation,
      question: 'Condicoes de seguranca do local e da equipe avaliadas?',
      required: true,
    ),
    ChecklistItem(
      id: 'mv_equipe_policial_preservacao_identificada',
      category: ChecklistCategory.preservation,
      question:
          'Equipe policial, unidade, viatura e responsavel pela preservacao identificados?',
      required: true,
    ),
    ChecklistItem(
      id: 'mv_informacoes_preliminares',
      category: ChecklistCategory.preservation,
      question: 'Informacoes preliminares dos fatos solicitadas e registradas?',
      required: true,
    ),
    ChecklistItem(
      id: 'mv_area_mediata_isolada',
      category: ChecklistCategory.preservation,
      question: 'Area mediata isolada e preservada?',
      required: true,
    ),
    ChecklistItem(
      id: 'mv_area_imediata_isolada',
      category: ChecklistCategory.preservation,
      question: 'Area imediata isolada e preservada?',
      required: true,
    ),
    ChecklistItem(
      id: 'mv_estado_preservacao_registrado',
      category: ChecklistCategory.preservation,
      question: 'Estado de preservacao registrado por texto e/ou imagem?',
      required: true,
    ),
    ChecklistItem(
      id: 'mv_alteracoes_antes_pericia',
      category: ChecklistCategory.preservation,
      question:
          'Alteracoes, acessos, socorro ou manuseios anteriores registrados?',
      required: true,
    ),
    ChecklistItem(
      id: 'mv_padrao_busca',
      category: ChecklistCategory.preservation,
      question: 'Padrao de busca definido e registrado?',
      required: true,
    ),
    ChecklistItem(
      id: 'mv_acesso_local_controlado',
      category: ChecklistCategory.preservation,
      question: 'Acesso ao local controlado pela equipe pericial?',
    ),
    ChecklistItem(
      id: 'mv_local_mediato_imediato_relacionado',
      category: ChecklistCategory.environment,
      question:
          'Locais mediato, imediato e relacionado avaliados quando existentes?',
      required: true,
    ),
    ChecklistItem(
      id: 'mv_local_descrito_georreferenciado',
      category: ChecklistCategory.environment,
      question: 'Local descrito e georreferenciado por GPS?',
      required: true,
    ),
    ChecklistItem(
      id: 'mv_condicoes_ambientais',
      category: ChecklistCategory.environment,
      question:
          'Topografia, clima, temperatura, luminosidade e visibilidade registrados?',
      required: true,
    ),
    ChecklistItem(
      id: 'mv_acessos_obstaculos',
      category: ChecklistCategory.environment,
      question:
          'Vias de acesso, obstaculos e rotas de entrada/saida verificados?',
      required: true,
    ),
    ChecklistItem(
      id: 'mv_sistemas_vigilancia',
      category: ChecklistCategory.environment,
      question:
          'Sistemas de vigilancia/cameras identificados e orientados a investigacao?',
    ),
    ChecklistItem(
      id: 'mv_fotos_panoramicas_gerais',
      category: ChecklistCategory.photographicRecord,
      question: 'Fotografias panoramicas e gerais do local realizadas?',
      required: true,
    ),
    ChecklistItem(
      id: 'mv_busca_elementos_materiais',
      category: ChecklistCategory.traces,
      question: 'Busca por elementos materiais visiveis e latentes realizada?',
      required: true,
    ),
    ChecklistItem(
      id: 'mv_sinais_luta_desalinho',
      category: ChecklistCategory.traces,
      question:
          'Sinais de luta, desalinho, marcas sugestivas ou dinamica aparente verificados?',
      required: true,
    ),
    ChecklistItem(
      id: 'mv_posicao_relativa_vestigios',
      category: ChecklistCategory.traces,
      question: 'Posicao relativa dos vestigios determinada por pontos fixos?',
      required: true,
    ),
    ChecklistItem(
      id: 'mv_vestigios_numerados_plotados',
      category: ChecklistCategory.traces,
      question: 'Vestigios numerados, plotados ou individualizados?',
      required: true,
    ),
    ChecklistItem(
      id: 'mv_vestigios_fotografados_descritos',
      category: ChecklistCategory.traces,
      question: 'Vestigios fotografados e descritos antes da coleta?',
      required: true,
    ),
    ChecklistItem(
      id: 'mv_vestigios_vulneraveis_priorizados',
      category: ChecklistCategory.traces,
      question: 'Vestigios vulneraveis ou temporarios priorizados?',
    ),
    ChecklistItem(
      id: 'mv_ausencia_vestigios_relevantes',
      category: ChecklistCategory.traces,
      question: 'Ausencia de vestigios esperados registrada quando relevante?',
    ),
    ChecklistItem(
      id: 'mv_coletas_acondicionadas',
      category: ChecklistCategory.chainOfCustody,
      question: 'Vestigios coletados e acondicionados conforme sua natureza?',
      required: true,
    ),
    ChecklistItem(
      id: 'mv_lacres_rotulos',
      category: ChecklistCategory.chainOfCustody,
      question:
          'Lacres e rotulos preenchidos com data, hora e responsavel pela coleta?',
      required: true,
    ),
    ChecklistItem(
      id: 'mv_cadeia_custodia_registrada',
      category: ChecklistCategory.chainOfCustody,
      question: 'Cadeia de custodia registrada para vestigios coletados?',
      required: true,
    ),
    ChecklistItem(
      id: 'mv_biologicos_identificados',
      category: ChecklistCategory.biologicalTraces,
      question: 'Manchas ou materiais biologicos pesquisados e registrados?',
      required: true,
    ),
    ChecklistItem(
      id: 'mv_padrao_sangue_arrastamento',
      category: ChecklistCategory.biologicalTraces,
      question: 'Gotejamento, poca, arrastamento ou padrao de sangue avaliado?',
    ),
    ChecklistItem(
      id: 'mv_biologicos_swab_contraprova',
      category: ChecklistCategory.biologicalTraces,
      question:
          'Coleta biologica com swab, prova/contraprova e troca de luvas quando aplicavel?',
    ),
    ChecklistItem(
      id: 'mv_medidas_anticontaminacao',
      category: ChecklistCategory.biologicalTraces,
      question: 'Medidas contra contaminacao adotadas?',
      required: true,
    ),
    ChecklistItem(
      id: 'mv_papiloscopicos_latentes',
      category: ChecklistCategory.biologicalTraces,
      question: 'Vestigios papiloscopicos ou latentes avaliados?',
    ),
    ChecklistItem(
      id: 'mv_elementos_balisticos',
      category: ChecklistCategory.ballisticTraces,
      question:
          'Capsulas, estojos, projeteis, perfuracoes e impactos pesquisados?',
    ),
    ChecklistItem(
      id: 'mv_projeteis_preservados',
      category: ChecklistCategory.ballisticTraces,
      question: 'Projeteis coletados preservando marcas individualizadoras?',
    ),
    ChecklistItem(
      id: 'mv_trajetoria_aparente',
      category: ChecklistCategory.ballisticTraces,
      question: 'Trajetoria aparente ou alinhamentos balisticos observados?',
    ),
    ChecklistItem(
      id: 'mv_armas_instrumentos',
      category: ChecklistCategory.weaponsObjects,
      question:
          'Armas, instrumentos ou objetos potencialmente usados localizados?',
    ),
    ChecklistItem(
      id: 'mv_armas_preservadas_identificadores',
      category: ChecklistCategory.weaponsObjects,
      question:
          'Armas/objetos preservados para DNA, papiloscopia ou outros exames antes de manipulacao?',
    ),
    ChecklistItem(
      id: 'mv_pertences_vitima_registrados',
      category: ChecklistCategory.weaponsObjects,
      question: 'Pertences, vestes e objetos associados a vitima registrados?',
    ),
    ChecklistItem(
      id: 'mv_mensagens_dispositivos',
      category: ChecklistCategory.weaponsObjects,
      question:
          'Mensagens, bilhetes, eletronicos ou objetos de vinculo vitima/autor verificados?',
    ),
    ChecklistItem(
      id: 'mv_indicadores_genero_sexual',
      category: ChecklistCategory.weaponsObjects,
      question:
          'Indicadores de violencia de genero, sexual, domestica ou simbolica avaliados quando cabivel?',
    ),
    ChecklistItem(
      id: 'mv_veiculos_relacionados',
      category: ChecklistCategory.vehicles,
      question: 'Veiculos relacionados ao evento periciados quando existentes?',
    ),
    ChecklistItem(
      id: 'mv_sinais_vitais',
      category: ChecklistCategory.bodyVictim,
      question: 'Havendo corpo, ausencia de sinais vitais verificada?',
      required: true,
    ),
    ChecklistItem(
      id: 'mv_corpo_posicao_condicoes_fotografado',
      category: ChecklistCategory.bodyVictim,
      question:
          'Cadaver fotografado na posicao e condicoes em que foi encontrado?',
      required: true,
    ),
    ChecklistItem(
      id: 'mv_corpo_identificacao_fotografada',
      category: ChecklistCategory.bodyVictim,
      question:
          'Face, sinais identificadores, pertences e objetos fotografados?',
      required: true,
    ),
    ChecklistItem(
      id: 'mv_vestes_alteracoes_fotografadas',
      category: ChecklistCategory.bodyVictim,
      question:
          'Vestes, calcados, acessorios e alteracoes fotografados/descritos?',
      required: true,
    ),
    ChecklistItem(
      id: 'mv_posicao_corporal_membros',
      category: ChecklistCategory.bodyVictim,
      question: 'Posicao do corpo e dos membros descrita?',
      required: true,
    ),
    ChecklistItem(
      id: 'mv_lesoes_fotografadas_escala',
      category: ChecklistCategory.bodyVictim,
      question:
          'Lesoes externas fotografadas com aproximacao/escala quando possivel?',
      required: true,
    ),
    ChecklistItem(
      id: 'mv_lesoes_regiao_instrumento',
      category: ChecklistCategory.bodyVictim,
      question:
          'Lesoes descritas por regiao anatomica e possivel meio/instrumento/acao?',
      required: true,
    ),
    ChecklistItem(
      id: 'mv_sinais_tanatologicos',
      category: ChecklistCategory.bodyVictim,
      question: 'Sinais tanatologicos observados descritos?',
      required: true,
    ),
    ChecklistItem(
      id: 'mv_residuografico_areas_preservadas',
      category: ChecklistCategory.bodyVictim,
      question:
          'Exame residuografico realizado ou areas anatomicas preservadas quando aplicavel?',
    ),
    ChecklistItem(
      id: 'mv_material_subungueal_defesa',
      category: ChecklistCategory.biologicalTraces,
      question:
          'Lesoes de defesa, mordidas ou material subungueal avaliados quando aplicavel?',
    ),
    ChecklistItem(
      id: 'mv_vestes_coletadas',
      category: ChecklistCategory.chainOfCustody,
      question:
          'Vestes coletadas ou preservadas para exames complementares quando necessario?',
    ),
    ChecklistItem(
      id: 'mv_cadaver_individualizado',
      category: ChecklistCategory.bodyVictim,
      question: 'Cadaver individualizado por metodo inequivoco?',
      required: true,
    ),
    ChecklistItem(
      id: 'mv_transferencia_custodia_cadaver',
      category: ChecklistCategory.chainOfCustody,
      question: 'Transferencia de custodia do cadaver registrada?',
      required: true,
    ),
    ChecklistItem(
      id: 'mv_local_relacionado_desova',
      category: ChecklistCategory.environment,
      question:
          'Possivel local relacionado, desova ou deslocamento do corpo avaliado?',
    ),
    ChecklistItem(
      id: 'mv_local_liberado_registrado',
      category: ChecklistCategory.preservation,
      question:
          'Liberacao do local comunicada e horario de termino registrado?',
      required: true,
    ),
    ChecklistItem(
      id: 'mv_retorno_local_lacre',
      category: ChecklistCategory.preservation,
      question:
          'Necessidade de retorno, fechamento ou lacre do local registrada?',
    ),
  ];
}

List<ChecklistItem> legacyViolentDeathChecklistBeforeLocalCrimePop() {
  return const [
    ChecklistItem(
      id: 'mv_seguranca_local',
      category: ChecklistCategory.preservation,
      question: 'Condicoes de seguranca do local e da equipe avaliadas?',
      required: true,
    ),
    ChecklistItem(
      id: 'mv_equipe_policial_preservacao',
      category: ChecklistCategory.preservation,
      question:
          'Policiais/unidade/viatura responsaveis pela preservacao identificados?',
      required: true,
    ),
    ChecklistItem(
      id: 'mv_informacoes_preliminares',
      category: ChecklistCategory.preservation,
      question: 'Informacoes preliminares dos fatos solicitadas e registradas?',
    ),
    ChecklistItem(
      id: 'mv_area_mediata_isolada',
      category: ChecklistCategory.preservation,
      question: 'Area mediata isolada e preservada?',
      required: true,
    ),
    ChecklistItem(
      id: 'mv_area_imediata_isolada',
      category: ChecklistCategory.preservation,
      question: 'Area imediata isolada e preservada?',
      required: true,
    ),
    ChecklistItem(
      id: 'mv_estado_preservacao_registrado',
      category: ChecklistCategory.preservation,
      question: 'Estado de preservacao registrado por escrito e/ou imagem?',
      required: true,
    ),
    ChecklistItem(
      id: 'mv_alteracoes_antes_pericia',
      category: ChecklistCategory.preservation,
      question:
          'Alteracoes, acessos, socorro ou manuseios anteriores registrados?',
      required: true,
    ),
    ChecklistItem(
      id: 'mv_padrao_busca',
      category: ChecklistCategory.preservation,
      question: 'Padrao de busca definido e registrado?',
    ),
    ChecklistItem(
      id: 'mv_corpo_presente_local',
      category: ChecklistCategory.bodyVictim,
      question: 'Havendo corpo, ausencia de sinais vitais verificada?',
      required: true,
    ),
    ChecklistItem(
      id: 'mv_cadaver_fotografado_posicao',
      category: ChecklistCategory.bodyVictim,
      question:
          'Cadaver fotografado na posicao e condicoes em que foi encontrado?',
      required: true,
    ),
    ChecklistItem(
      id: 'mv_identificacao_cadaver',
      category: ChecklistCategory.bodyVictim,
      question:
          'Face, sinais identificadores, tatuagens/piercings e pertences registrados?',
      required: true,
    ),
    ChecklistItem(
      id: 'mv_vestes_acessorios_registrados',
      category: ChecklistCategory.bodyVictim,
      question: 'Vestes, calcados, acessorios e alteracoes descritos?',
    ),
    ChecklistItem(
      id: 'mv_posicao_corporal_membros',
      category: ChecklistCategory.bodyVictim,
      question: 'Posicao do corpo e dos membros descrita?',
      required: true,
    ),
    ChecklistItem(
      id: 'mv_lesoes_regiao_instrumento',
      category: ChecklistCategory.bodyVictim,
      question:
          'Lesoes externas descritas por regiao anatomica e possivel instrumento/acao?',
      required: true,
    ),
    ChecklistItem(
      id: 'mv_sinais_tanatologicos',
      category: ChecklistCategory.bodyVictim,
      question: 'Sinais tanatologicos observados e descritos?',
    ),
    ChecklistItem(
      id: 'mv_areas_residuografico_preservadas',
      category: ChecklistCategory.bodyVictim,
      question:
          'Areas anatomicas de interesse residuografico preservadas/coletadas quando aplicavel?',
    ),
    ChecklistItem(
      id: 'mv_individualizacao_cadaver',
      category: ChecklistCategory.bodyVictim,
      question: 'Cadaver individualizado para remocao/custodia?',
      required: true,
    ),
    ChecklistItem(
      id: 'mv_sangue_manchas_presentes',
      category: ChecklistCategory.biologicalTraces,
      question:
          'Manchas ou materiais biologicos pesquisados no local e no corpo?',
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
      question:
          'Material biologico coletado com tecnica adequada, prova/contraprova quando possivel?',
    ),
    ChecklistItem(
      id: 'mv_vestigios_protegidos_contaminacao',
      category: ChecklistCategory.biologicalTraces,
      question: 'Vestigios protegidos da contaminacao?',
    ),
    ChecklistItem(
      id: 'mv_unhas_mordidas_contato',
      category: ChecklistCategory.biologicalTraces,
      question:
          'Material subungueal, mordidas ou DNA de contato avaliados quando pertinente?',
    ),
    ChecklistItem(
      id: 'mv_capsulas_estojos_presentes',
      category: ChecklistCategory.ballisticTraces,
      question:
          'Capsulas/estojos pesquisados, fotografados e individualizados?',
    ),
    ChecklistItem(
      id: 'mv_projeteis_presentes',
      category: ChecklistCategory.ballisticTraces,
      question:
          'Projeteis ou fragmentos balisticos coletados preservando marcas individualizadoras?',
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
      question:
          'Arma de fogo localizada, tornada segura e preservada para exames?',
    ),
    ChecklistItem(
      id: 'mv_arma_branca_localizada',
      category: ChecklistCategory.weaponsObjects,
      question: 'Arma branca/instrumento ofensivo localizado e preservado?',
    ),
    ChecklistItem(
      id: 'mv_objetos_deslocados_quebrados',
      category: ChecklistCategory.weaponsObjects,
      question:
          'Objetos deslocados, quebrados ou com dano simbólico registrados?',
    ),
    ChecklistItem(
      id: 'mv_sinais_luta',
      category: ChecklistCategory.weaponsObjects,
      question: 'Sinais de luta/desalinho/marcas sugestivas pesquisados?',
      required: true,
    ),
    ChecklistItem(
      id: 'mv_pertences_vitima_registrados',
      category: ChecklistCategory.weaponsObjects,
      question: 'Pertences da vitima registrados?',
    ),
    ChecklistItem(
      id: 'mv_papiloscopia_latentes',
      category: ChecklistCategory.weaponsObjects,
      question:
          'Vestigios papiloscopicos/latentes fotografados antes de revelacao/decalque?',
    ),
    ChecklistItem(
      id: 'mv_vinculo_presenca',
      category: ChecklistCategory.weaponsObjects,
      question:
          'Elementos de vinculo/presenca da vitima ou suspeito no local pesquisados?',
    ),
    ChecklistItem(
      id: 'mv_local_interno_externo_descrito',
      category: ChecklistCategory.environment,
      question:
          'Local imediato, mediato e relacionado descritos do geral para o particular?',
      required: true,
    ),
    ChecklistItem(
      id: 'mv_georreferenciamento_local',
      category: ChecklistCategory.environment,
      question: 'Local georreferenciado por GPS?',
      required: true,
    ),
    ChecklistItem(
      id: 'mv_condicoes_ambientais',
      category: ChecklistCategory.environment,
      question:
          'Condicoes topograficas, climaticas, temperatura, luminosidade e visibilidade registradas?',
      required: true,
    ),
    ChecklistItem(
      id: 'mv_acessos_rotas_registrados',
      category: ChecklistCategory.environment,
      question: 'Vias de acesso/obstaculos verificados?',
      required: true,
    ),
    ChecklistItem(
      id: 'mv_cameras_proximas_identificadas',
      category: ChecklistCategory.environment,
      question:
          'Sistemas de vigilancia identificados e equipe de investigacao orientada?',
    ),
    ChecklistItem(
      id: 'mv_veiculos_relacionados',
      category: ChecklistCategory.environment,
      question: 'Veiculos relacionados ao evento periciados quando existentes?',
    ),
    ChecklistItem(
      id: 'mv_genero_violencia_contextual',
      category: ChecklistCategory.environment,
      question:
          'Indicadores de violência de gênero/doméstica, sexual ou simbólica avaliados quando pertinente?',
    ),
    ChecklistItem(
      id: 'mv_fotos_gerais_local',
      category: ChecklistCategory.photographicRecord,
      question: 'Fotografias panoramicas e gerais do local registradas?',
      required: true,
    ),
    ChecklistItem(
      id: 'mv_fotos_aproximacao',
      category: ChecklistCategory.photographicRecord,
      question: 'Fotografias do geral para o especifico realizadas?',
    ),
    ChecklistItem(
      id: 'mv_fotos_corpo',
      category: ChecklistCategory.photographicRecord,
      question:
          'Fotos do corpo realizadas em multiplos angulos e proximidades?',
      required: true,
    ),
    ChecklistItem(
      id: 'mv_fotos_lesoes',
      category: ChecklistCategory.photographicRecord,
      question:
          'Fotos de lesoes antes/depois de limpeza e com escala quando possivel?',
    ),
    ChecklistItem(
      id: 'mv_fotos_vestigios',
      category: ChecklistCategory.photographicRecord,
      question: 'Vestigios fotografados com numeracao/escala antes da coleta?',
      required: true,
    ),
    ChecklistItem(
      id: 'mv_fotos_armas_objetos',
      category: ChecklistCategory.photographicRecord,
      question: 'Fotos de armas/objetos?',
    ),
    ChecklistItem(
      id: 'mv_posicao_relativa_vestigios',
      category: ChecklistCategory.traces,
      question: 'Posicao relativa dos vestigios determinada por pontos fixos?',
      required: true,
    ),
    ChecklistItem(
      id: 'mv_vestigios_numerados_plotados',
      category: ChecklistCategory.traces,
      question:
          'Vestigios numerados/individualizados e plotados quando aplicavel?',
      required: true,
    ),
    ChecklistItem(
      id: 'mv_vestigios_vulneraveis',
      category: ChecklistCategory.traces,
      question: 'Vestigios sensiveis ou temporarios priorizados?',
    ),
    ChecklistItem(
      id: 'mv_coleta_acondicionamento',
      category: ChecklistCategory.chainOfCustody,
      question:
          'Vestigios coletados e acondicionados conforme natureza do material?',
      required: true,
    ),
    ChecklistItem(
      id: 'mv_lacre_rotulo',
      category: ChecklistCategory.chainOfCustody,
      question: 'Embalagens lacradas e rotuladas com dados legais da coleta?',
      required: true,
    ),
    ChecklistItem(
      id: 'mv_vestes_coletadas',
      category: ChecklistCategory.chainOfCustody,
      question:
          'Vestes coletadas/preservadas para exames complementares quando necessario?',
    ),
    ChecklistItem(
      id: 'mv_transferencia_custodia_cadaver',
      category: ChecklistCategory.chainOfCustody,
      question: 'Transferencia de custodia do cadaver ao IML registrada?',
      required: true,
    ),
    ChecklistItem(
      id: 'mv_liberacao_local',
      category: ChecklistCategory.chainOfCustody,
      question:
          'Liberacao do local comunicada e horario de termino registrado?',
      required: true,
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

List<ChecklistItem> defaultBallisticsChecklist(BallisticsNature? nature) {
  return switch (nature) {
    BallisticsNature.ballisticComparison => _ballisticsComparisonChecklist(
      'bal_confronto',
    ),
    BallisticsNature.gsrCollection => _ballisticsGsrChecklist('bal_gsr'),
    BallisticsNature.firearmEfficiency => _ballisticsFirearmEfficiencyChecklist(
      'bal_arma_eficiencia',
    ),
    BallisticsNature.ammunitionEfficiency =>
      _ballisticsAmmunitionEfficiencyChecklist('bal_municao_eficiencia'),
    BallisticsNature.other => _ballisticsGeneralChecklist('bal_outro'),
    null => _ballisticsGeneralChecklist('bal_geral'),
  };
}

List<ChecklistItem> _ballisticsBaseChecklist(String prefix) {
  return [
    ChecklistItem(
      id: '${prefix}_documento_conferido',
      category: ChecklistCategory.ballisticReceipt,
      question: 'Requisicao/oficio analisado e objetivo pericial definido?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_embalagem_lacre_origem',
      category: ChecklistCategory.ballisticReceipt,
      question:
          'Forma de encaminhamento, embalagem, lacre, conteudo e origem descritos?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_compatibilidade_material',
      category: ChecklistCategory.ballisticReceipt,
      question: 'Material recebido compativel com o documento de envio?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_fotos_lacres_embalagens',
      category: ChecklistCategory.photographicRecord,
      question: 'Embalagens, lacres e material recebido fotografados?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_exames_complementares_verificados',
      category: ChecklistCategory.ballisticReceipt,
      question:
          'Exames biologicos, papiloscopicos ou complementares verificados antes da balistica?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_seguranca_epi',
      category: ChecklistCategory.ballisticSafety,
      question: 'Riscos, EPI e local seguro de manuseio/teste avaliados?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_biologico_contaminacao',
      category: ChecklistCategory.ballisticSafety,
      question:
          'Material biologico/quimico ou risco de contaminacao registrado e tratado com EPI adequado?',
    ),
    ChecklistItem(
      id: '${prefix}_cadeia_custodia',
      category: ChecklistCategory.chainOfCustody,
      question: 'Cadeia de custodia preservada e registrada?',
      required: true,
    ),
  ];
}

List<ChecklistItem> _ballisticsGeneralChecklist(String prefix) {
  return [
    ..._ballisticsBaseChecklist(prefix),
    ChecklistItem(
      id: '${prefix}_material_caracterizado',
      category: ChecklistCategory.ballisticTraces,
      question: 'Material balistico caracterizado, descrito e individualizado?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_destino_material',
      category: ChecklistCategory.chainOfCustody,
      question: 'Destino do material remanescente registrado?',
    ),
  ];
}

List<ChecklistItem> _ballisticsComparisonChecklist(String prefix) {
  return [
    ..._ballisticsBaseChecklist(prefix),
    ChecklistItem(
      id: '${prefix}_arma_segura',
      category: ChecklistCategory.ballisticSafety,
      question:
          'Arma tratada como carregada e descarregada/desmuniciada com seguranca quando aplicavel?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_arma_descricao_sinab',
      category: ChecklistCategory.firearms,
      question: 'Arma descrita/individualizada em padrao compativel com SINAB?',
    ),
    ChecklistItem(
      id: '${prefix}_elementos_classificados',
      category: ChecklistCategory.ballisticTraces,
      question:
          'Estojos, projeteis, fragmentos ou cartuchos classificados e individualizados?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_limpeza_sem_dano',
      category: ChecklistCategory.ballisticTraces,
      question:
          'Limpeza do material questionado realizada sem comprometer marcas identificadoras?',
    ),
    ChecklistItem(
      id: '${prefix}_caracteristicas_genericas',
      category: ChecklistCategory.ballisticTraces,
      question:
          'Calibre, fabricante/origem, raiamento, marcas de percussao ou caracteristicas genericas registradas?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_padroes_coletados',
      category: ChecklistCategory.ballisticComparison,
      question:
          'Padroes balisticos coletados com municao identica ou mais similar possivel?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_padroes_individualizados',
      category: ChecklistCategory.ballisticComparison,
      question: 'Padroes identificados/individualizados e vinculados a arma?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_microcomparacao_condicoes',
      category: ChecklistCategory.ballisticComparison,
      question: 'Condicoes minimas para confronto microbalistico avaliadas?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_resultado_confronto',
      category: ChecklistCategory.ballisticComparison,
      question: 'Resultado positivo, negativo ou inconclusivo fundamentado?',
    ),
    ChecklistItem(
      id: '${prefix}_sinab_bnpb',
      category: ChecklistCategory.ballisticComparison,
      question: 'Elegibilidade SINAB/BNPB ou envio a outra unidade avaliado?',
    ),
  ];
}

List<ChecklistItem> _ballisticsGsrChecklist(String prefix) {
  return [
    ..._ballisticsBaseChecklist(prefix),
    ChecklistItem(
      id: '${prefix}_contaminacao_prevenida',
      category: ChecklistCategory.gsrCollection,
      question:
          'Medidas para evitar contaminacao do perito, vestimentas e materiais adotadas?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_superficie_preservada',
      category: ChecklistCategory.gsrCollection,
      question:
          'Superficies de coleta preservadas sem lavagem, toque indevido ou atrito?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_suspeito_vigilancia',
      category: ChecklistCategory.gsrCollection,
      question:
          'Suspeito mantido sob vigilancia e condicoes de algema/manuseio registradas?',
    ),
    ChecklistItem(
      id: '${prefix}_stub_carbono',
      category: ChecklistCategory.gsrCollection,
      question: 'Coleta realizada com stub e fita dupla face de carbono?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_tecnica_toques',
      category: ChecklistCategory.gsrCollection,
      question:
          'Coleta feita por toques sucessivos, sem esfregar ou girar o stub?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_amostras_maos',
      category: ChecklistCategory.gsrCollection,
      question: 'Amostras de maos/palmar/dorsal individualizadas por pessoa?',
    ),
    ChecklistItem(
      id: '${prefix}_face_pescoco',
      category: ChecklistCategory.gsrCollection,
      question: 'Face/pescoco coletados quando indicado por arma longa?',
    ),
    ChecklistItem(
      id: '${prefix}_tempo_coleta',
      category: ChecklistCategory.gsrCollection,
      question: 'Horario do fato/coleta e janela temporal registrados?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_vestes_acondicionadas',
      category: ChecklistCategory.gsrCollection,
      question:
          'Vestes acondicionadas individualmente e sem perda de particulas quando necessario?',
    ),
    ChecklistItem(
      id: '${prefix}_veiculo_local',
      category: ChecklistCategory.gsrCollection,
      question:
          'Superficies de veiculo/local coletadas antes de remocao ou alteracao?',
    ),
    ChecklistItem(
      id: '${prefix}_amostras_identificadas',
      category: ChecklistCategory.chainOfCustody,
      question: 'Amostras tampadas, identificadas, lacradas e enviadas?',
      required: true,
    ),
  ];
}

List<ChecklistItem> _ballisticsFirearmEfficiencyChecklist(String prefix) {
  return [
    ..._ballisticsBaseChecklist(prefix),
    ChecklistItem(
      id: '${prefix}_arma_carregada',
      category: ChecklistCategory.ballisticSafety,
      question: 'Arma manuseada como carregada ate verificacao final?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_cano_obstrucao',
      category: ChecklistCategory.ballisticSafety,
      question: 'Carregamento e obstrucao do cano verificados?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_arma_descrita',
      category: ChecklistCategory.firearms,
      question:
          'Tipo, marca, modelo, origem, calibre e numero de serie registrados?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_raiamento_cano',
      category: ChecklistCategory.firearms,
      question:
          'Comprimento do cano, raiamento e orientacao avaliados quando possivel?',
    ),
    ChecklistItem(
      id: '${prefix}_conservacao_mecanismos',
      category: ChecklistCategory.firearms,
      question: 'Estado de conservacao e mecanismos de seguranca descritos?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_fotos_arma',
      category: ChecklistCategory.photographicRecord,
      question:
          'Fotos gerais, escala, inscricoes e avarias da arma realizadas?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_sem_reparo_previo',
      category: ChecklistCategory.firearms,
      question:
          'Nenhum reparo/manutencao realizado antes do exame sem registro?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_teste_seguro',
      category: ChecklistCategory.ballisticSafety,
      question:
          'Teste realizado em estande/local seguro, para-balas ou acionamento remoto quando necessario?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_falha_intervalo',
      category: ChecklistCategory.firearms,
      question:
          'Falha de deflagracao tratada com intervalo de seguranca e repeticoes controladas?',
    ),
    ChecklistItem(
      id: '${prefix}_resultado_eficiencia',
      category: ChecklistCategory.firearms,
      question: 'Resultado de eficiencia positivo/negativo fundamentado?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_padroes_bnpb',
      category: ChecklistCategory.ballisticComparison,
      question:
          'Projeteis/estojos padrao coletados e destino SINAB/BNPB avaliado?',
    ),
  ];
}

List<ChecklistItem> _ballisticsAmmunitionEfficiencyChecklist(String prefix) {
  return [
    ..._ballisticsBaseChecklist(prefix),
    ChecklistItem(
      id: '${prefix}_cartuchos_separados',
      category: ChecklistCategory.ammunition,
      question:
          'Cartuchos separados por calibre, origem, fabricante e caracteristicas?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_cartuchos_descritos',
      category: ChecklistCategory.ammunition,
      question:
          'Quantidade, calibre, fabricante, estojo, projetil, lote e conservacao descritos?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_fotos_cartuchos',
      category: ChecklistCategory.photographicRecord,
      question:
          'Registro fotografico dos cartuchos com escala, inscricoes e estampa da base?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_inspecao_integridade',
      category: ChecklistCategory.ammunition,
      question:
          'Integridade, percussao, corrosao, recarga, danos e folgas verificados?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_impedimento_exame',
      category: ChecklistCategory.ammunition,
      question: 'Impedimento ao exame de eficiencia registrado quando houver?',
    ),
    ChecklistItem(
      id: '${prefix}_amostragem',
      category: ChecklistCategory.ammunition,
      question: 'Amostragem representativa/ABNT registrada quando aplicavel?',
    ),
    ChecklistItem(
      id: '${prefix}_teste_seguro',
      category: ChecklistCategory.ballisticSafety,
      question:
          'Teste de tiro/provete/dispositivo realizado com EPI e seguranca?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_picotados',
      category: ChecklistCategory.ammunition,
      question:
          'Cartuchos picotados/percutidos avaliados conforme risco e valor probatorio?',
    ),
    ChecklistItem(
      id: '${prefix}_resultado_quantidades',
      category: ChecklistCategory.ammunition,
      question: 'Quantidade de cartuchos eficientes e ineficientes consignada?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_destino_remanescente',
      category: ChecklistCategory.chainOfCustody,
      question:
          'Destino de estojos, projeteis e material remanescente registrado?',
      required: true,
    ),
  ];
}

List<ChecklistItem> defaultAudioImageChecklist(AudioImageNature? nature) {
  return switch (nature) {
    AudioImageNature.contentAnalysis => _audioImageContentChecklist(
      'ai_conteudo',
    ),
    AudioImageNature.imageEnhancement => _audioImageEnhancementChecklist(
      'ai_melhoramento',
    ),
    AudioImageNature.imageRecognition => _audioImageRecognitionChecklist(
      'ai_reconhecimento',
    ),
    AudioImageNature.facialComparison => _audioImageFacialChecklist(
      'ai_facial',
    ),
    AudioImageNature.imageEditVerification => _audioImageEditChecklist(
      'ai_edicao',
    ),
    AudioImageNature.speakerComparison => _audioImageSpeakerChecklist(
      'ai_locutor',
    ),
    AudioImageNature.cctvPreservation => _audioImageCctvChecklist('ai_cftv'),
    AudioImageNature.statureEstimation => _audioImageStatureChecklist(
      'ai_estatura',
    ),
    AudioImageNature.other => _audioImageGeneralChecklist('ai_outro'),
    null => _audioImageGeneralChecklist('ai_geral'),
  };
}

List<ChecklistItem> _audioImageBaseChecklist(String prefix) {
  return [
    ChecklistItem(
      id: '${prefix}_documento_quesitos',
      category: ChecklistCategory.multimediaReceipt,
      question: 'Requisicao/oficio, quesitos e objetivo do exame definidos?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_embalagem_lacre',
      category: ChecklistCategory.multimediaReceipt,
      question: 'Embalagem, lacre, midia/suporte e origem descritos?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_fotos_material',
      category: ChecklistCategory.photographicRecord,
      question: 'Material recebido, lacres e suporte fotografados com escala?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_condicao_fisica',
      category: ChecklistCategory.multimediaReceipt,
      question:
          'Condicao fisica do suporte/midia avaliada quanto a danos ou avarias?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_bloqueio_escrita',
      category: ChecklistCategory.multimediaPreservation,
      question: 'Bloqueio fisico ou logico contra gravacao aplicado?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_clone_duplicada',
      category: ChecklistCategory.multimediaPreservation,
      question:
          'Imagem/clone da midia ou duplicada dos arquivos questionados gerada quando possivel?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_hash_sha256',
      category: ChecklistCategory.multimediaPreservation,
      question: 'Hashes SHA-256 dos arquivos/midias recebidos calculados?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_copia_trabalho',
      category: ChecklistCategory.multimediaPreservation,
      question:
          'Copia de trabalho criada sem modificacao do material original?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_originalidade_material',
      category: ChecklistCategory.multimediaAdequacy,
      question:
          'Material original recebido ou limitacao por copia/WhatsApp/captura secundaria registrada?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_adequabilidade',
      category: ChecklistCategory.multimediaAdequacy,
      question:
          'Adequabilidade, viabilidade e impeditivos tecnicos do exame avaliados?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_delimitacao',
      category: ChecklistCategory.multimediaAdequacy,
      question:
          'Arquivo, trecho, intervalo temporal, frame ou alvo questionado delimitado?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_metadados',
      category: ChecklistCategory.multimediaProcessing,
      question:
          'Metadados, estrutura do arquivo, formato, resolucao, fps ou codec registrados quando aplicavel?',
    ),
    ChecklistItem(
      id: '${prefix}_cadeia_custodia',
      category: ChecklistCategory.chainOfCustody,
      question: 'Cadeia de custodia preservada e documentada?',
      required: true,
    ),
  ];
}

List<ChecklistItem> _audioImageGeneralChecklist(String prefix) {
  return [
    ..._audioImageBaseChecklist(prefix),
    ChecklistItem(
      id: '${prefix}_material_questionado',
      category: ChecklistCategory.multimediaProcessing,
      question: 'Material efetivamente questionado definido e registrado?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_resultado_limitacoes',
      category: ChecklistCategory.multimediaProcessing,
      question:
          'Resultados, limitacoes tecnicas e necessidade de oficios complementares registrados?',
    ),
  ];
}

List<ChecklistItem> _audioImageContentChecklist(String prefix) {
  return [
    ..._audioImageBaseChecklist(prefix),
    ChecklistItem(
      id: '${prefix}_parametro_temporal',
      category: ChecklistCategory.multimediaProcessing,
      question:
          'Parametro temporal definido por tempo de reproducao, frame ou horario em tela?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_eventos_descritos',
      category: ChecklistCategory.multimediaProcessing,
      question:
          'Eventos visualizados descritos e vinculados a referencias temporais?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_quadros_extraidos',
      category: ChecklistCategory.multimediaProcessing,
      question:
          'Quadros relevantes extraidos/salvos para laudo quando cabivel?',
    ),
    ChecklistItem(
      id: '${prefix}_coerencia_quesitos',
      category: ChecklistCategory.multimediaProcessing,
      question:
          'Coerencia entre conteudo visualizado e quesitos/dinamica proposta avaliada?',
    ),
  ];
}

List<ChecklistItem> _audioImageEnhancementChecklist(String prefix) {
  return [
    ..._audioImageBaseChecklist(prefix),
    ChecklistItem(
      id: '${prefix}_trecho_melhoramento',
      category: ChecklistCategory.multimediaProcessing,
      question: 'Trecho/area da imagem a melhorar definido?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_ajustes_registrados',
      category: ChecklistCategory.multimediaProcessing,
      question:
          'Sequencia de filtros, ajustes e criterios de melhoramento registrada?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_arquivo_resultante_hash',
      category: ChecklistCategory.multimediaPreservation,
      question:
          'Arquivo melhorado ou quadros exportados com hash e integridade controlada?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_sem_alterar_sentido',
      category: ChecklistCategory.multimediaAdequacy,
      question:
          'Melhoramento preserva o sentido informacional e limitacoes foram registradas?',
      required: true,
    ),
  ];
}

List<ChecklistItem> _audioImageRecognitionChecklist(String prefix) {
  return [
    ..._audioImageBaseChecklist(prefix),
    ChecklistItem(
      id: '${prefix}_alvo_reconhecimento',
      category: ChecklistCategory.multimediaAdequacy,
      question: 'Pessoa/objeto questionado definido de forma inequivoca?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_imagem_adequada',
      category: ChecklistCategory.multimediaAdequacy,
      question:
          'Qualidade, foco, angulo, iluminacao e obstrucoes avaliados para reconhecimento?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_padrao_disponivel',
      category: ChecklistCategory.multimediaProcessing,
      question:
          'Material padrao/origem conhecida disponivel e vinculado quando houver comparacao?',
    ),
    ChecklistItem(
      id: '${prefix}_resultado_cauteloso',
      category: ChecklistCategory.multimediaProcessing,
      question: 'Resultado descrito com grau de limitacao e cautela tecnica?',
    ),
  ];
}

List<ChecklistItem> _audioImageFacialChecklist(String prefix) {
  return [
    ..._audioImageBaseChecklist(prefix),
    ChecklistItem(
      id: '${prefix}_questionado_padrao',
      category: ChecklistCategory.facialComparison,
      question: 'Imagem questionada e material padrao definidos?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_face_desobstruida',
      category: ChecklistCategory.facialComparison,
      question: 'Face e estruturas faciais visiveis, sem obstrucao impeditiva?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_criterios_adequabilidade',
      category: ChecklistCategory.facialComparison,
      question:
          'Pose, iluminacao, resolucao, nitidez e expressao avaliadas quanto a adequabilidade?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_linhas_metodologia',
      category: ChecklistCategory.facialComparison,
      question:
          'Metodologia de comparacao facial e criterios observados registrados?',
      required: true,
    ),
  ];
}

List<ChecklistItem> _audioImageEditChecklist(String prefix) {
  return [
    ..._audioImageBaseChecklist(prefix),
    ChecklistItem(
      id: '${prefix}_autenticidade_hipoteses',
      category: ChecklistCategory.imageAuthenticity,
      question: 'Hipoteses de autenticidade/edicao definidas?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_analise_perceptual_contextual',
      category: ChecklistCategory.imageAuthenticity,
      question: 'Analise perceptual e contextual realizada?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_analise_formato_estrutura',
      category: ChecklistCategory.imageAuthenticity,
      question: 'Formato, estrutura, metadados e fluxo audiovisual avaliados?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_conclusao_escala',
      category: ChecklistCategory.imageAuthenticity,
      question:
          'Conclusao expressa por escala/forca de suporte ou limitacao tecnica?',
    ),
  ];
}

List<ChecklistItem> _audioImageSpeakerChecklist(String prefix) {
  return [
    ..._audioImageBaseChecklist(prefix),
    ChecklistItem(
      id: '${prefix}_questionado_padrao',
      category: ChecklistCategory.speakerComparison,
      question: 'Material questionado e padrao vocal definidos?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_qualidade_audio',
      category: ChecklistCategory.speakerComparison,
      question:
          'Qualidade, ruido, sobreposicao de fala, compressao e duracao avaliados?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_coleta_padrao_consentimento',
      category: ChecklistCategory.speakerComparison,
      question:
          'Coleta de padrao vocal com consentimento, identificacao e seguranca quando aplicavel?',
    ),
    ChecklistItem(
      id: '${prefix}_fala_comparavel',
      category: ChecklistCategory.speakerComparison,
      question: 'Trechos de fala comparaveis e linguisticamente adequados?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_metodologia_resultado',
      category: ChecklistCategory.speakerComparison,
      question:
          'Metodologia e conclusao por escala/verbalizacao de suporte registradas?',
    ),
  ];
}

List<ChecklistItem> _audioImageCctvChecklist(String prefix) {
  return [
    ..._audioImageBaseChecklist(prefix),
    ChecklistItem(
      id: '${prefix}_acoes_preliminares',
      category: ChecklistCategory.cctvCollection,
      question:
          'Tipo de delito, dia/hora e lapso temporal de interesse definidos?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_estado_local',
      category: ChecklistCategory.cctvCollection,
      question: 'Estado em que o sistema/local foi encontrado registrado?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_equipamento_identificado',
      category: ChecklistCategory.cctvCollection,
      question:
          'DVR/NVR/HVR, cameras, midias, capacidade, firmware e configuracoes identificados?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_cameras_interesse',
      category: ChecklistCategory.cctvCollection,
      question: 'Cameras e intervalos de interesse determinados?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_formato_nativo',
      category: ChecklistCategory.cctvCollection,
      question:
          'Extracao preferencialmente em formato nativo e player proprietario copiado quando disponivel?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_sobrescrita_risco',
      category: ChecklistCategory.cctvCollection,
      question:
          'Risco de sobrescrita, acesso remoto ou alteracao/destruicao avaliado?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_hash_midia_extraida',
      category: ChecklistCategory.multimediaPreservation,
      question: 'Dados extraidos hashados e registrados no documento oficial?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_testemunha_responsavel',
      category: ChecklistCategory.cctvCollection,
      question:
          'Procedimento acompanhado por responsavel/testemunha e sistema reiniciado/verificado quando necessario?',
    ),
  ];
}

List<ChecklistItem> _audioImageStatureChecklist(String prefix) {
  return [
    ..._audioImageBaseChecklist(prefix),
    ChecklistItem(
      id: '${prefix}_individuo_objeto_definido',
      category: ChecklistCategory.multimediaAdequacy,
      question: 'Individuo ou objeto questionado definido de forma inequivoca?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_topo_base_visiveis',
      category: ChecklistCategory.multimediaAdequacy,
      question:
          'Topo e base do individuo/objeto visiveis em condicao adequada?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_referencias_conhecidas',
      category: ChecklistCategory.multimediaAdequacy,
      question:
          'Ao menos duas medidas conhecidas ou objetos de referencia na cena identificados?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_tecnica_estimada',
      category: ChecklistCategory.multimediaProcessing,
      question:
          'Tecnica de estimativa escolhida: projecao reversa, fotomontagem, trigonometria ou outra?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_resultado_intervalo',
      category: ChecklistCategory.multimediaProcessing,
      question:
          'Resultado registrado como intervalo de estimativa e limitacoes?',
      required: true,
    ),
  ];
}

List<ChecklistItem> defaultPapiloscopyChecklist(PapiloscopyNature? nature) {
  return switch (nature) {
    PapiloscopyNature.criminalIdentification =>
      _papiloscopyCriminalIdentificationChecklist('pap_identificacao'),
    PapiloscopyNature.crimeScenePrints => _papiloscopyCrimeSceneChecklist(
      'pap_local',
    ),
    PapiloscopyNature.labPrints => _papiloscopyLabChecklist('pap_laboratorio'),
    PapiloscopyNature.necropapiloscopy => _papiloscopyNecroChecklist(
      'pap_necro',
    ),
    PapiloscopyNature.other => _papiloscopyGeneralChecklist('pap_outro'),
    null => _papiloscopyGeneralChecklist('pap_geral'),
  };
}

List<ChecklistItem> _papiloscopyBaseChecklist(String prefix) {
  return [
    ChecklistItem(
      id: '${prefix}_documentacao_requisicao',
      category: ChecklistCategory.documentation,
      question: 'Requisicao, objetivo do exame e material/pessoa conferidos?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_biosseguranca_epi',
      category: ChecklistCategory.papiloscopyBiosafety,
      question: 'EPI e medidas de biosseguranca adequados ao procedimento?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_materiais_equipamentos',
      category: ChecklistCategory.papiloscopyCollection,
      question:
          'Materiais, suportes, camera, escalas e equipamentos conferidos?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_fotografias_escala',
      category: ChecklistCategory.photographicRecord,
      question:
          'Registros fotograficos realizados com escala quando aplicavel?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_qualidade_afis_abis',
      category: ChecklistCategory.papiloscopyIdentification,
      question:
          'Qualidade suficiente para analise, confronto ou AFIS/ABIS avaliada?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_limitacoes_registradas',
      category: ChecklistCategory.documentation,
      question:
          'Limitacoes, inviabilidades ou peculiaridades tecnicas registradas?',
    ),
    ChecklistItem(
      id: '${prefix}_cadeia_custodia',
      category: ChecklistCategory.chainOfCustody,
      question:
          'Cadeia de custodia, lacres, rotulos e responsavel registrados?',
      required: true,
    ),
  ];
}

List<ChecklistItem> _papiloscopyGeneralChecklist(String prefix) {
  return [
    ..._papiloscopyBaseChecklist(prefix),
    ChecklistItem(
      id: '${prefix}_suporte_avaliado',
      category: ChecklistCategory.papiloscopyDevelopment,
      question: 'Suporte, superficie ou pessoa examinada descritos?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_tecnica_adequada',
      category: ChecklistCategory.papiloscopyDevelopment,
      question: 'Tecnica papiloscopica escolhida conforme o suporte/objetivo?',
      required: true,
    ),
  ];
}

List<ChecklistItem> _papiloscopyCriminalIdentificationChecklist(String prefix) {
  return [
    ..._papiloscopyBaseChecklist(prefix),
    ChecklistItem(
      id: '${prefix}_dados_identificado',
      category: ChecklistCategory.papiloscopyIdentification,
      question: 'Dados do identificado, nome social e formulario conferidos?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_consentimento_recusa',
      category: ChecklistCategory.documentation,
      question:
          'Termo de consentimento, recusa ou impossibilidade de assinatura registrado?',
    ),
    ChecklistItem(
      id: '${prefix}_maos_inspecionadas',
      category: ChecklistCategory.papiloscopyCollection,
      question:
          'Maos, falanges, palmares, lesoes, cicatrizes ou anomalias examinadas?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_higiene_maos',
      category: ChecklistCategory.papiloscopyBiosafety,
      question:
          'Lavagem/secagem das maos ou preparo para sudorese/ressecamento realizado?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_live_scan_entintamento',
      category: ChecklistCategory.papiloscopyCollection,
      question:
          'Metodo de coleta definido: live scan, entintamento ou tecnica adequada?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_datilogramas_sequencia',
      category: ChecklistCategory.papiloscopyCollection,
      question:
          'Digitais batidas e roladas coletadas na sequencia correta sem repeticao?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_palmares_hipotenar',
      category: ChecklistCategory.papiloscopyCollection,
      question:
          'Impressoes palmares e regiao hipotenar coletadas quando cabivel?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_fotografia_sinaletica',
      category: ChecklistCategory.photographicRecord,
      question:
          'Fotografia sinaletica frontal e perfis registrada quando cabivel?',
    ),
    ChecklistItem(
      id: '${prefix}_falhas_borroes_trocas',
      category: ChecklistCategory.papiloscopyIdentification,
      question:
          'Falhas, borroes, linhas duplas, dedos repetidos ou inversao descartados?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_armazenamento_backup',
      category: ChecklistCategory.papiloscopyIdentification,
      question:
          'Fichas/imagens salvas, digitalizadas ou preparadas para NIST/AFIS/ABIS?',
      required: true,
    ),
  ];
}

List<ChecklistItem> _papiloscopyCrimeSceneChecklist(String prefix) {
  return [
    ..._papiloscopyBaseChecklist(prefix),
    ChecklistItem(
      id: '${prefix}_local_preservado',
      category: ChecklistCategory.preservation,
      question:
          'Local preservado para busca papiloscopica antes de manipulacoes?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_superficies_priorizadas',
      category: ChecklistCategory.papiloscopyDevelopment,
      question:
          'Superficies e objetos de maior potencial papiloscopico priorizados?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_busca_luz_forense',
      category: ChecklistCategory.papiloscopyDevelopment,
      question:
          'Busca com iluminacao adequada/luz forense realizada quando cabivel?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_latentes_patentes_moldadas',
      category: ChecklistCategory.papiloscopyDevelopment,
      question:
          'Impressoes latentes, patentes ou moldadas pesquisadas e diferenciadas?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_dna_antes_revelacao',
      category: ChecklistCategory.papiloscopyBiosafety,
      question:
          'Preservacao de DNA/outros exames considerada antes de tecnica destrutiva?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_tecnica_suporte',
      category: ChecklistCategory.papiloscopyDevelopment,
      question:
          'Po/reagente/tecnica escolhido conforme tipo de suporte e contraste?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_foto_antes_decalque',
      category: ChecklistCategory.photographicRecord,
      question:
          'Impressao fotografada com escala antes de revelacao/decalque/coleta?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_decalque_suporte_adesivo',
      category: ChecklistCategory.papiloscopyCollection,
      question:
          'Decalque, suporte adesivo ou coleta realizados sem contaminar o vestigio?',
    ),
    ChecklistItem(
      id: '${prefix}_numeracao_catalogacao',
      category: ChecklistCategory.chainOfCustody,
      question: 'Vestigios numerados, etiquetados, embalados e catalogados?',
      required: true,
    ),
  ];
}

List<ChecklistItem> _papiloscopyLabChecklist(String prefix) {
  return [
    ..._papiloscopyBaseChecklist(prefix),
    ChecklistItem(
      id: '${prefix}_lacre_recebimento',
      category: ChecklistCategory.chainOfCustody,
      question:
          'Lacre, embalagem e condicao de recebimento do material registrados?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_fispq_epi_epc',
      category: ChecklistCategory.papiloscopyLab,
      question:
          'FISPQ, EPI, EPC, ventilacao e rotas de emergencia considerados?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_tecnica_reagente_suporte',
      category: ChecklistCategory.papiloscopyLab,
      question:
          'Tecnica/reagente selecionado conforme superficie e material questionado?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_sequencia_tecnicas',
      category: ChecklistCategory.papiloscopyLab,
      question:
          'Sequencia de tecnicas compativeis e menos destrutivas avaliada?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_impressao_revelada_registrada',
      category: ChecklistCategory.papiloscopyDevelopment,
      question:
          'Impressao revelada fotografada/digitalizada com identificacao do suporte?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_residuos_quimicos',
      category: ChecklistCategory.papiloscopyLab,
      question:
          'Residuos quimicos e materiais contaminados descartados adequadamente?',
    ),
    ChecklistItem(
      id: '${prefix}_reacondicionamento_lacre',
      category: ChecklistCategory.chainOfCustody,
      question:
          'Material residual reacondicionado, lacrado e devolvido a custodia?',
      required: true,
    ),
  ];
}

List<ChecklistItem> _papiloscopyNecroChecklist(String prefix) {
  return [
    ..._papiloscopyBaseChecklist(prefix),
    ChecklistItem(
      id: '${prefix}_identificacao_corpo',
      category: ChecklistCategory.papiloscopyNecro,
      question:
          'Numero/identificacao do corpo conferido com o registro papiloscopico?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_estado_pele',
      category: ChecklistCategory.papiloscopyNecro,
      question: 'Estado da pele espessa/mumificacao/queima/submersao avaliado?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_tratamento_escolhido',
      category: ChecklistCategory.papiloscopyNecro,
      question:
          'Tratamento escolhido conforme condicao da pele e justificativa registrada?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_limpeza_preparo',
      category: ChecklistCategory.papiloscopyBiosafety,
      question: 'Limpeza, higienizacao e preparo da area de coleta realizados?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_registro_metodo',
      category: ChecklistCategory.papiloscopyNecro,
      question:
          'Metodo de registro definido: fotografia direta, microadesao ou face interna?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_sequencia_maos_dedos',
      category: ChecklistCategory.papiloscopyCollection,
      question:
          'Sequencia correta de maos/dedos mantida sem inversao ou sobreposicao?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_espelhamento_imagem',
      category: ChecklistCategory.photographicRecord,
      question:
          'Espelhamento de fotografia direta/face interna realizado quando necessario?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_tratamento_periodico',
      category: ChecklistCategory.papiloscopyNecro,
      question:
          'Inspecao periodica de tecido em tratamento quimico registrada?',
    ),
    ChecklistItem(
      id: '${prefix}_falanges_excisao',
      category: ChecklistCategory.papiloscopyNecro,
      question:
          'Excisao de falanges/maos evitada ou justificada apos esgotar alternativas?',
    ),
    ChecklistItem(
      id: '${prefix}_liberacao_corpo',
      category: ChecklistCategory.chainOfCustody,
      question:
          'Liberacao do corpo somente apos conferencia rigorosa do procedimento?',
      required: true,
    ),
  ];
}

List<ChecklistItem> defaultEnvironmentalChecklist(EnvironmentalNature? nature) {
  return switch (nature) {
    EnvironmentalNature.deforestation => _environmentalDeforestationChecklist(),
    EnvironmentalNature.animalAbuse => _environmentalAnimalAbuseChecklist(),
    EnvironmentalNature.waterPollution =>
      _environmentalWaterPollutionChecklist(),
    EnvironmentalNature.forestFire => _environmentalForestFireChecklist(),
    EnvironmentalNature.veterinaryNecropsy =>
      _environmentalVeterinaryNecropsyChecklist(),
    EnvironmentalNature.other => _environmentalGeneralChecklist('amb_outro'),
    null => _environmentalGeneralChecklist('amb_geral'),
  };
}

List<ChecklistItem> _environmentalBaseChecklist(String prefix) {
  return [
    ChecklistItem(
      id: '${prefix}_documentos_analisados',
      category: ChecklistCategory.environmentalPlanning,
      question: 'Documentos, oficio, historico e objetivo pericial analisados?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_localizacao_confirmada',
      category: ChecklistCategory.environmentalPlanning,
      question: 'Endereco, rota e localizacao geografica confirmados?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_risco_epi',
      category: ChecklistCategory.environmentalPlanning,
      question: 'Riscos do local, EPI e apoio necessario avaliados?',
    ),
    ChecklistItem(
      id: '${prefix}_coordenadas_pontos',
      category: ChecklistCategory.environmentalScene,
      question: 'Coordenadas dos pontos relevantes registradas?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_registro_fotografico',
      category: ChecklistCategory.photographicRecord,
      question: 'Fotos gerais, aproximacao e detalhes registradas?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_vestigios_identificados',
      category: ChecklistCategory.traces,
      question: 'Vestigios identificados, descritos e fotografados?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_amostras_necessidade',
      category: ChecklistCategory.environmentalSamples,
      question: 'Necessidade de amostras ou exame complementar avaliada?',
    ),
    ChecklistItem(
      id: '${prefix}_cadeia_custodia',
      category: ChecklistCategory.chainOfCustody,
      question: 'Coletas identificadas, embaladas, lacradas e registradas?',
    ),
  ];
}

List<ChecklistItem> _environmentalGeneralChecklist(String prefix) {
  return [
    ..._environmentalBaseChecklist(prefix),
    ChecklistItem(
      id: '${prefix}_caracterizacao_local',
      category: ChecklistCategory.environmentalScene,
      question: 'Caracterizacao ambiental do local registrada?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_dano_ambiental',
      category: ChecklistCategory.environmentalDamage,
      question: 'Dano ambiental aparente descrito e fotografado?',
      required: true,
    ),
  ];
}

List<ChecklistItem> _environmentalDeforestationChecklist() {
  const prefix = 'amb_desmatamento';
  return [
    ..._environmentalBaseChecklist(prefix),
    ChecklistItem(
      id: '${prefix}_area_delimitada',
      category: ChecklistCategory.environmentalDamage,
      question: 'Area suprimida delimitada ou estimada?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_bioma_fitofisionomia',
      category: ChecklistCategory.environmentalScene,
      question: 'Bioma, fitofisionomia e estagio de regeneracao avaliados?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_area_protegida',
      category: ChecklistCategory.environmentalScene,
      question: 'APP, reserva legal, unidade de conservacao ou TI verificada?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_licencas_autorizacoes',
      category: ChecklistCategory.documentation,
      question: 'ASV/licenca/CAR/SICAR/SINAFLOR/DOF consultados se aplicavel?',
    ),
    ChecklistItem(
      id: '${prefix}_tocos_material_lenhoso',
      category: ChecklistCategory.traces,
      question:
          'Tocos, material lenhoso, marcas de corte ou queima registrados?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_corpo_hidrico_nascente',
      category: ChecklistCategory.environmentalScene,
      question: "Corpo hidrico, nascente ou olho d'agua afetado verificado?",
    ),
    ChecklistItem(
      id: '${prefix}_imagens_gnss_rpa',
      category: ChecklistCategory.environmentalPlanning,
      question: 'Imagens orbitais, GNSS ou RPA considerados para area?',
    ),
    ChecklistItem(
      id: '${prefix}_coleta_botanica',
      category: ChecklistCategory.environmentalSamples,
      question: 'Coleta botanica realizada ou justificada quando necessaria?',
    ),
  ];
}

List<ChecklistItem> _environmentalAnimalAbuseChecklist() {
  const prefix = 'amb_maus_tratos';
  return [
    ..._environmentalBaseChecklist(prefix),
    ChecklistItem(
      id: '${prefix}_animal_identificado',
      category: ChecklistCategory.environmentalDamage,
      question: 'Animal caracterizado por especie, sexo, idade/porte e sinais?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_condicao_corporal_lesoes',
      category: ChecklistCategory.environmentalDamage,
      question:
          'Condicao corporal, lesoes e sinais de dor/sofrimento registrados?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_ambiente_manutencao',
      category: ChecklistCategory.environmentalScene,
      question:
          'Abrigo, agua, alimento, higiene, espaco e ventilacao avaliados?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_negligencia_crueldade',
      category: ChecklistCategory.environmentalDamage,
      question: 'Indicadores de negligencia, abuso ou crueldade avaliados?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_apoio_veterinario',
      category: ChecklistCategory.environmentalPlanning,
      question: 'Necessidade de medico veterinario/especialista registrada?',
    ),
    ChecklistItem(
      id: '${prefix}_cadaver_biologico',
      category: ChecklistCategory.environmentalSamples,
      question: 'Cadaver, partes ou material biologico avaliados/coletados?',
    ),
    ChecklistItem(
      id: '${prefix}_tutor_responsavel',
      category: ChecklistCategory.documentation,
      question: 'Tutor/responsavel, documentos e origem do animal registrados?',
    ),
  ];
}

List<ChecklistItem> _environmentalWaterPollutionChecklist() {
  const prefix = 'amb_poluicao_hidrica';
  return [
    ..._environmentalBaseChecklist(prefix),
    ChecklistItem(
      id: '${prefix}_corpo_hidrico',
      category: ChecklistCategory.environmentalScene,
      question: 'Corpo hidrico/receptor identificado e caracterizado?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_ponto_lancamento',
      category: ChecklistCategory.environmentalDamage,
      question: 'Ponto de descarte/lancamento ou fonte potencial localizado?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_montante_jusante',
      category: ChecklistCategory.environmentalSamples,
      question: 'Pontos a montante, jusante e efluente planejados/registrados?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_organoleptica',
      category: ChecklistCategory.environmentalDamage,
      question: 'Cor, odor, espuma, oleo/iridescencia ou turbidez observados?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_amostras_preservadas',
      category: ChecklistCategory.environmentalSamples,
      question:
          'Amostras de agua, sedimento ou efluente coletadas/preservadas?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_parametros_campo',
      category: ChecklistCategory.environmentalSamples,
      question: 'Parametros de campo medidos quando possivel?',
    ),
    ChecklistItem(
      id: '${prefix}_fauna_flora_afetada',
      category: ChecklistCategory.environmentalDamage,
      question:
          'Fauna, flora ou vegetacao afetadas verificadas e fotografadas?',
    ),
    ChecklistItem(
      id: '${prefix}_licenca_fispq',
      category: ChecklistCategory.documentation,
      question:
          'Licenca, condicionantes, FISPQ ou automonitoramento avaliados?',
    ),
  ];
}

List<ChecklistItem> _environmentalForestFireChecklist() {
  const prefix = 'amb_incendio_florestal';
  return [
    ..._environmentalBaseChecklist(prefix),
    ChecklistItem(
      id: '${prefix}_perimetro_area',
      category: ChecklistCategory.environmentalDamage,
      question: 'Perimetro ou area queimada delimitada?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_direcao_intensidade',
      category: ChecklistCategory.fire,
      question: 'Indicadores de direcao/intensidade do fogo registrados?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_origem_foco',
      category: ChecklistCategory.fire,
      question: 'Zona de origem/confusao e foco inicial avaliados?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_vestigios_autoria',
      category: ChecklistCategory.traces,
      question:
          'Pegadas, pneus, fogueira, latas/garrafas ou outros vestigios buscados?',
    ),
    ChecklistItem(
      id: '${prefix}_agente_igneo',
      category: ChecklistCategory.fire,
      question: 'Agente igneo e causa provavel investigados?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_danos_caracterizados',
      category: ChecklistCategory.environmentalDamage,
      question:
          'Danos a fauna, vegetacao, patrimonio ou area protegida caracterizados?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_combate_relacao_desmatamento',
      category: ChecklistCategory.environmentalPlanning,
      question:
          'Medidas de combate e possivel relacao com desmatamento registradas?',
    ),
  ];
}

List<ChecklistItem> _environmentalVeterinaryNecropsyChecklist() {
  const prefix = 'amb_necropsia_veterinaria';
  return [
    ..._environmentalBaseChecklist(prefix),
    ChecklistItem(
      id: '${prefix}_recepcao_cadeia',
      category: ChecklistCategory.chainOfCustody,
      question:
          'Recepcao do cadaver/material e cadeia de custodia registradas?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_estado_conservacao',
      category: ChecklistCategory.environmentalDamage,
      question: 'Estado de conservacao descrito?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_identificacao_zoologica',
      category: ChecklistCategory.environmentalDamage,
      question: 'Identificacao zoologica e individualizadores registrados?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_medidas_peso_marcas',
      category: ChecklistCategory.environmentalDamage,
      question:
          'Medidas, peso, porte, cor, marcas, microchip/tatuagem registrados?',
    ),
    ChecklistItem(
      id: '${prefix}_fenomenos_cadavericos',
      category: ChecklistCategory.environmentalDamage,
      question: 'Fenomenos cadavericos descritos?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_lesoes_fotografadas',
      category: ChecklistCategory.photographicRecord,
      question: 'Lesoes externas/internas documentadas fotograficamente?',
      required: true,
    ),
    ChecklistItem(
      id: '${prefix}_amostras_exames',
      category: ChecklistCategory.environmentalSamples,
      question: 'Amostras para exames complementares coletadas/preservadas?',
    ),
    ChecklistItem(
      id: '${prefix}_biosseguranca',
      category: ChecklistCategory.environmentalPlanning,
      question: 'Biosseguranca, EPI e descarte/limpeza observados?',
      required: true,
    ),
  ];
}
