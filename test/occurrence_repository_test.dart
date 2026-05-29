import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sicro_campo/core/data/occurrence_repository.dart';
import 'package:sicro_campo/core/data/occurrence_storage.dart';
import 'package:sicro_campo/core/data/operational_statistics_service.dart';
import 'package:sicro_campo/core/data/photo_file_storage.dart';
import 'package:sicro_campo/domain/models/case_data.dart';
import 'package:sicro_campo/domain/models/checklist_item.dart';
import 'package:sicro_campo/domain/models/field_note.dart';
import 'package:sicro_campo/domain/models/field_photo.dart';
import 'package:sicro_campo/domain/models/forensic_case_metadata.dart';
import 'package:sicro_campo/domain/models/location_record.dart';
import 'package:sicro_campo/domain/models/measurement_record.dart';
import 'package:sicro_campo/domain/models/occurrence.dart';
import 'package:sicro_campo/domain/models/trace_record.dart';
import 'package:sicro_campo/domain/models/vehicle_record.dart';
import 'package:sicro_campo/domain/models/victim_record.dart';

void main() {
  test('persists created and edited occurrence to local JSON file', () async {
    final tempDir = await Directory.systemTemp.createTemp('sicro_campo_test_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final storage = FileOccurrenceStorage(
      directoryProvider: () async => tempDir,
    );
    final repository = OccurrenceRepository(storage: storage);
    await repository.load();

    final occurrence = await repository.createOccurrence(
      const CaseData(bo: '123/2026', municipality: 'Macapa', street: 'Av. FAB'),
      metadata: const ForensicCaseMetadata(
        trafficNature: TrafficNature.collision,
        trafficInvolved: [TrafficInvolved.car, TrafficInvolved.pedestrian],
        result: OccurrenceResult.injuredVictim,
      ),
    );
    expect(
      occurrence.effectiveTimeline.map((event) => event.type),
      contains(OccurrenceTimelineEventType.created),
    );
    expect(
      occurrence.effectiveTimeline.map((event) => event.type),
      contains(OccurrenceTimelineEventType.gpsStarted),
    );
    expect(
      occurrence.checklist.map((item) => item.id),
      containsAll([
        'metodo_croqui_registrado',
        'levantamento_drone_realizado',
        'croqui_manual_trena',
      ]),
    );

    await repository.updateCaseData(
      occurrence.id,
      const CaseData(
        bo: '123/2026',
        requisition: 'REQ-01',
        municipality: 'Santana',
        street: 'Rua Claudio Lucio Monteiro',
      ),
    );

    await repository.updateLocation(
      occurrence.id,
      LocationRecord(
        latitude: 0.0349,
        longitude: -51.0694,
        accuracyMeters: 4.8,
        capturedAt: DateTime(2026, 5, 19, 13, 10),
      ),
    );

    await repository.addPhoto(
      occurrence.id,
      FieldPhoto(
        id: 'foto_1',
        filePath: 'local/foto_1.jpg',
        category: PhotoCategory.overview,
        capturedAt: DateTime(2026, 5, 19, 14, 30),
        sha256: 'abc123hash',
      ),
    );

    await repository.updateChecklistItem(
      occurrence.id,
      'local_preservado',
      answer: ChecklistAnswer.yes,
      note: 'Local preservado pela equipe de apoio.',
    );

    final vehicle = await repository.createVehicle(occurrence.id);
    await repository.updateVehicle(
      occurrence.id,
      VehicleRecord(
        id: vehicle!.id,
        identifier: vehicle.identifier,
        plate: 'ABC1D23',
        model: 'SUV',
        color: 'Prata',
        finalPosition: 'Faixa direita',
        damage: 'Danos frontais',
        photoIds: const ['foto_1'],
      ),
    );

    final victim = await repository.createVictim(occurrence.id);
    await repository.updateVictim(
      occurrence.id,
      VictimRecord(
        id: victim!.id,
        identifier: victim.identifier,
        name: 'Fulano de Tal',
        condition: VictimCondition.injured,
        type: VictimType.driver,
        removalStatus: VictimRemovalStatus.yes,
        rescuedBy: 'SAMU',
        destination: 'Hospital de Emergencia',
        removedAt: DateTime(2026, 5, 19, 14, 45),
        bodyPosition: 'Decubito dorsal na faixa direita.',
        protectiveEquipment: 'Capacete informado.',
        note: 'Removida antes da chegada da equipe.',
        photoIds: const ['foto_1'],
      ),
    );

    final trace = await repository.createTrace(occurrence.id);
    await repository.updateTrace(
      occurrence.id,
      trace!.copyWith(
        type: TraceType.braking,
        description: 'Marca de frenagem sobre a faixa direita.',
        length: 12.4,
        width: 0.22,
        direction: 'Centro-bairro',
        locationDescription: 'Faixa direita, antes do ponto de impacto.',
        note: 'Vestigio fotografado em detalhe.',
        photoIds: const ['foto_1'],
      ),
    );

    final measurement = await repository.createMeasurement(occurrence.id);
    await repository.updateMeasurement(
      occurrence.id,
      MeasurementRecord(
        id: measurement!.id,
        label: measurement.label,
        pointA: 'V1',
        pointB: 'Ponto de impacto',
        value: 8.6,
        unit: 'm',
        method: 'trena_laser',
        note: 'Medicao coletada no eixo da faixa.',
        photoIds: const ['foto_1'],
      ),
    );

    final note = await repository.createNote(occurrence.id);
    await repository.updateNote(
      occurrence.id,
      note!.copyWith(
        text: 'Retornar ao local para conferir iluminacao noturna.',
        category: NoteCategory.pending,
        priority: NotePriority.important,
      ),
    );

    final restored = OccurrenceRepository(storage: storage);
    await restored.load();

    expect(restored.occurrences, hasLength(1));
    expect(restored.occurrences.first.status, OccurrenceStatus.inProgress);
    expect(restored.occurrences.first.caseData.bo, '123/2026');
    expect(
      restored.occurrences.first.metadata.trafficNature,
      TrafficNature.collision,
    );
    expect(restored.occurrences.first.metadata.trafficInvolved, [
      TrafficInvolved.car,
      TrafficInvolved.pedestrian,
    ]);
    expect(
      restored.occurrences.first.metadata.result,
      OccurrenceResult.injuredVictim,
    );
    expect(restored.occurrences.first.caseData.requisition, 'REQ-01');
    expect(restored.occurrences.first.caseData.municipality, 'Santana');
    expect(restored.occurrences.first.checklist, isNotEmpty);
    expect(restored.occurrences.first.answeredChecklistItems, 1);
    expect(restored.occurrences.first.checklistProgress, greaterThan(0));
    final restoredChecklistItem = restored.occurrences.first.checklist
        .firstWhere((item) => item.id == 'local_preservado');
    expect(restoredChecklistItem.category, ChecklistCategory.preservation);
    expect(restoredChecklistItem.answer, ChecklistAnswer.yes);
    expect(
      restoredChecklistItem.note,
      'Local preservado pela equipe de apoio.',
    );
    expect(restored.occurrences.first.location.hasCoordinates, isTrue);
    expect(restored.occurrences.first.location.accuracyMeters, 4.8);
    expect(restored.occurrences.first.startedAt, isNotNull);
    expect(restored.occurrences.first.gpsTrack, hasLength(1));
    expect(restored.occurrences.first.gpsReadingsCount, 1);
    expect(restored.occurrences.first.photos, hasLength(1));
    expect(
      restored.occurrences.first.effectiveTimeline.map((event) => event.type),
      containsAll([
        OccurrenceTimelineEventType.gpsCaptured,
        OccurrenceTimelineEventType.firstPhoto,
      ]),
    );
    expect(
      restored.occurrences.first.photos.first.category,
      PhotoCategory.overview,
    );
    expect(restored.occurrences.first.vehicles, hasLength(1));
    final restoredVehicle = restored.occurrences.first.vehicles.first;
    expect(restoredVehicle.identifier, 'V1');
    expect(restoredVehicle.plate, 'ABC1D23');
    expect(restoredVehicle.photoIds, ['foto_1']);
    expect(restored.occurrences.first.victims, hasLength(1));
    final restoredVictim = restored.occurrences.first.victims.first;
    expect(restoredVictim.identifier, 'P1');
    expect(restoredVictim.name, 'Fulano de Tal');
    expect(restoredVictim.condition, VictimCondition.injured);
    expect(restoredVictim.type, VictimType.driver);
    expect(restoredVictim.removalStatus, VictimRemovalStatus.yes);
    expect(restoredVictim.rescuedBy, 'SAMU');
    expect(restoredVictim.destination, 'Hospital de Emergencia');
    expect(restoredVictim.removedAt, DateTime(2026, 5, 19, 14, 45));
    expect(restoredVictim.bodyPosition, 'Decubito dorsal na faixa direita.');
    expect(restoredVictim.protectiveEquipment, 'Capacete informado.');
    expect(restoredVictim.note, 'Removida antes da chegada da equipe.');
    expect(restoredVictim.photoIds, ['foto_1']);
    expect(restored.occurrences.first.traces, hasLength(1));
    final restoredTrace = restored.occurrences.first.traces.first;
    expect(restoredTrace.identifier, 'V1');
    expect(restoredTrace.type, TraceType.braking);
    expect(
      restoredTrace.description,
      'Marca de frenagem sobre a faixa direita.',
    );
    expect(restoredTrace.length, 12.4);
    expect(restoredTrace.width, 0.22);
    expect(restoredTrace.direction, 'Centro-bairro');
    expect(
      restoredTrace.locationDescription,
      'Faixa direita, antes do ponto de impacto.',
    );
    expect(restoredTrace.note, 'Vestigio fotografado em detalhe.');
    expect(restoredTrace.photoIds, ['foto_1']);
    expect(restored.occurrences.first.measurements, hasLength(1));
    final restoredMeasurement = restored.occurrences.first.measurements.first;
    expect(restoredMeasurement.label, 'M1');
    expect(restoredMeasurement.pointA, 'V1');
    expect(restoredMeasurement.pointB, 'Ponto de impacto');
    expect(restoredMeasurement.value, 8.6);
    expect(restoredMeasurement.unit, 'm');
    expect(restoredMeasurement.method, 'trena_laser');
    expect(restoredMeasurement.note, 'Medicao coletada no eixo da faixa.');
    expect(restoredMeasurement.photoIds, ['foto_1']);
    expect(restored.occurrences.first.notes, hasLength(1));
    final restoredNote = restored.occurrences.first.notes.first;
    expect(
      restoredNote.text,
      'Retornar ao local para conferir iluminacao noturna.',
    );
    expect(restoredNote.category, NoteCategory.pending);
    expect(restoredNote.priority, NotePriority.important);
    expect(restoredNote.updatedAt, isNotNull);
    final progress = restored.occurrences.first.operationalProgress;
    expect(progress.percent, 70);
    expect(progress.stateFor('gps'), OperationalItemState.completed);
    expect(progress.stateFor('photos'), OperationalItemState.partial);
    expect(progress.stateFor('trace_photos'), OperationalItemState.pending);
    expect(progress.stateFor('vehicles'), OperationalItemState.completed);
    expect(progress.stateFor('victims'), OperationalItemState.completed);
    expect(progress.pendingItems, contains('Nenhuma foto de vestigio'));
    expect(progress.pendingItems, contains('Ocorrencia ainda nao exportada'));

    await restored.setOperationalItemNotApplicable(
      restored.occurrences.first.id,
      OperationalItemIds.tracePhotos,
      true,
    );
    final afterNotApplicable = restored.findById(
      restored.occurrences.first.id,
    )!;
    expect(afterNotApplicable.notApplicableItems, [
      OperationalItemIds.tracePhotos,
    ]);
    expect(
      afterNotApplicable.operationalProgress.stateFor('trace_photos'),
      OperationalItemState.notApplicable,
    );
    expect(
      afterNotApplicable.operationalProgress.pendingItems,
      isNot(contains('Nenhuma foto de vestigio')),
    );
    expect(afterNotApplicable.operationalProgress.percent, 80);

    await restored.markExported(
      restored.occurrences.first.id,
      exportedAt: DateTime(2026, 5, 19, 16),
      packageName: 'SICRO_OPERACIONAL_TESTE.sicroapp',
      sha256: 'sha_package',
    );
    final afterExport = restored.findById(restored.occurrences.first.id)!;
    expect(afterExport.status, OccurrenceStatus.exported);
    expect(afterExport.exportedAt, DateTime(2026, 5, 19, 16));
    expect(afterExport.finishedAt, DateTime(2026, 5, 19, 16));
    expect(afterExport.exportedPackageName, 'SICRO_OPERACIONAL_TESTE.sicroapp');
    expect(afterExport.exportedPackageSha256, 'sha_package');
    expect(
      afterExport.effectiveTimeline.map((event) => event.type),
      contains(OccurrenceTimelineEventType.exported),
    );
    expect(
      afterExport.operationalProgress.stateFor('export'),
      OperationalItemState.completed,
    );
    expect(afterExport.operationalProgress.percent, 90);
    final stats = afterExport.stats;
    expect(stats.forensicType, 'transito');
    expect(stats.nature, 'colisao');
    expect(stats.result, 'vitima_lesionada');
    expect(stats.operationalStatus, 'exportada');
    expect(stats.municipality, 'Santana');
    expect(stats.address, contains('Rua Claudio Lucio Monteiro'));
    expect(stats.bestGpsAccuracyMeters, 4.8);
    expect(stats.photosCount, 1);
    expect(stats.vehiclesCount, 1);
    expect(stats.victimsCount, 1);
    expect(stats.tracesCount, 1);
    expect(stats.measurementsCount, 1);
    expect(stats.notesCount, 1);
    expect(stats.answeredChecklistItemsCount, 1);
    expect(stats.notApplicableItemsCount, 1);
    expect(stats.exported, isTrue);
    expect(stats.exportedAt, DateTime(2026, 5, 19, 16));
    expect(stats.toJson()['exportada'], isTrue);
    expect(stats.toJson()['coordenada_principal'], isA<Map<String, Object?>>());

    await restored.completeOccurrence(
      restored.occurrences.first.id,
      finishedAt: DateTime(2026, 5, 19, 17),
    );
    final afterComplete = restored.findById(restored.occurrences.first.id)!;
    expect(afterComplete.status, OccurrenceStatus.completed);
    expect(afterComplete.finishedAt, DateTime(2026, 5, 19, 17));
    expect(afterComplete.durationSeconds, greaterThanOrEqualTo(0));
    expect(
      afterComplete.effectiveTimeline.map((event) => event.type),
      contains(OccurrenceTimelineEventType.completed),
    );

    await restored.updateStatus(
      restored.occurrences.first.id,
      OccurrenceStatus.inProgress,
    );
    final afterReopen = restored.findById(restored.occurrences.first.id)!;
    expect(afterReopen.status, OccurrenceStatus.inProgress);
    expect(afterReopen.finishedAt, isNull);
    expect(
      afterReopen.effectiveTimeline.map((event) => event.type),
      contains(OccurrenceTimelineEventType.reopened),
    );

    final removed = await restored.removePhoto(
      restored.occurrences.first.id,
      'foto_1',
    );
    expect(removed?.id, 'foto_1');
    final afterPhotoRemoval = restored.findById(restored.occurrences.first.id)!;
    expect(afterPhotoRemoval.vehicles.first.photoIds, isEmpty);
    expect(afterPhotoRemoval.victims.first.photoIds, isEmpty);
    expect(afterPhotoRemoval.traces.first.photoIds, isEmpty);
    expect(afterPhotoRemoval.measurements.first.photoIds, isEmpty);
    final removedTrace = await restored.removeTrace(
      restored.occurrences.first.id,
      restoredTrace.id,
    );
    expect(removedTrace?.id, restoredTrace.id);
    final removedVehicle = await restored.removeVehicle(
      restored.occurrences.first.id,
      restoredVehicle.id,
    );
    expect(removedVehicle?.id, restoredVehicle.id);
    final removedVictim = await restored.removeVictim(
      restored.occurrences.first.id,
      restoredVictim.id,
    );
    expect(removedVictim?.id, restoredVictim.id);
    final removedMeasurement = await restored.removeMeasurement(
      restored.occurrences.first.id,
      restoredMeasurement.id,
    );
    expect(removedMeasurement?.id, restoredMeasurement.id);
    final removedNote = await restored.removeNote(
      restored.occurrences.first.id,
      restoredNote.id,
    );
    expect(removedNote?.id, restoredNote.id);

    final restoredAfterRemoval = OccurrenceRepository(storage: storage);
    await restoredAfterRemoval.load();
    expect(restoredAfterRemoval.occurrences.first.photos, isEmpty);
    expect(restoredAfterRemoval.occurrences.first.vehicles, isEmpty);
    expect(restoredAfterRemoval.occurrences.first.victims, isEmpty);
    expect(restoredAfterRemoval.occurrences.first.traces, isEmpty);
    expect(restoredAfterRemoval.occurrences.first.measurements, isEmpty);
    expect(restoredAfterRemoval.occurrences.first.notes, isEmpty);

    final deleted = await restoredAfterRemoval.deleteOccurrence(
      restoredAfterRemoval.occurrences.first.id,
    );
    expect(deleted, isNotNull);

    final restoredAfterDelete = OccurrenceRepository(storage: storage);
    await restoredAfterDelete.load();
    expect(restoredAfterDelete.occurrences, isEmpty);
  });

  test('deletes occurrence and local photo artifacts', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'sicro_delete_occurrence_test_',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final storage = FileOccurrenceStorage(
      directoryProvider: () async => tempDir,
    );
    final repository = OccurrenceRepository(storage: storage);
    await repository.load();

    final occurrence = await repository.createOccurrence(
      const CaseData(bo: 'DEL-01/2026', municipality: 'Macapa'),
    );
    final photoDir = Directory(
      '${tempDir.path}${Platform.pathSeparator}sicro_campo'
      '${Platform.pathSeparator}photos'
      '${Platform.pathSeparator}${occurrence.id}',
    );
    await photoDir.create(recursive: true);
    final photoFile = File('${photoDir.path}${Platform.pathSeparator}foto.jpg');
    await photoFile.writeAsBytes([1, 2, 3]);

    await repository.addPhoto(
      occurrence.id,
      FieldPhoto(
        id: 'foto_1',
        filePath: photoFile.path,
        category: PhotoCategory.detail,
        capturedAt: DateTime(2026, 5, 21, 12),
        sha256: 'hash_foto',
      ),
    );

    final removed = await repository.deleteOccurrence(occurrence.id);
    expect(removed, isNotNull);

    final photoStorage = PhotoFileStorage(
      directoryProvider: () async => tempDir,
    );
    await photoStorage.deleteOccurrencePhotos(
      occurrenceId: removed!.id,
      photos: removed.photos,
    );

    expect(await photoFile.exists(), isFalse);
    expect(await photoDir.exists(), isFalse);

    final restored = OccurrenceRepository(storage: storage);
    await restored.load();
    expect(restored.occurrences, isEmpty);
  });

  test('persists editable checklist changes per occurrence', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'sicro_editable_checklist_test_',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final storage = FileOccurrenceStorage(
      directoryProvider: () async => tempDir,
    );
    final repository = OccurrenceRepository(storage: storage);
    await repository.load();

    final occurrence = await repository.createOccurrence(
      const CaseData(bo: 'CHK-01/2026', municipality: 'Macapa'),
      metadata: const ForensicCaseMetadata(
        type: ForensicCaseType.property,
        propertyNature: PropertyNature.burglary,
      ),
    );
    final baseItem = occurrence.checklist.first;
    final removableItem = occurrence.checklist[1];

    await repository.updateChecklistQuestion(
      occurrence.id,
      baseItem.copyWith(
        question: 'Local preservado sem alteracoes antes da pericia?',
        required: false,
        defaultNote: 'Registrar quem preservou o local.',
      ),
    );
    final added = await repository.addChecklistItem(
      occurrence.id,
      category: ChecklistCategory.burglary,
      question: 'Marcas de ferramenta fotografadas em detalhe?',
      required: true,
      defaultNote: 'Priorizar portas, janelas, fechaduras e batentes.',
    );
    await repository.updateChecklistItem(
      occurrence.id,
      added!.id,
      answer: ChecklistAnswer.yes,
      note: 'Fotos F3 e F4 vinculadas ao ponto de acesso.',
    );
    final removed = await repository.removeChecklistItem(
      occurrence.id,
      removableItem.id,
    );
    expect(removed?.id, removableItem.id);

    final restored = OccurrenceRepository(storage: storage);
    await restored.load();
    final checklist = restored.occurrences.first.checklist;

    expect(checklist.where((item) => item.id == removableItem.id), isEmpty);
    final editedBase = checklist.firstWhere((item) => item.id == baseItem.id);
    expect(
      editedBase.question,
      'Local preservado sem alteracoes antes da pericia?',
    );
    expect(editedBase.required, isFalse);
    expect(editedBase.defaultNote, 'Registrar quem preservou o local.');
    expect(editedBase.origin, ChecklistItemOrigin.base);

    final custom = checklist.firstWhere((item) => item.id == added.id);
    expect(custom.category, ChecklistCategory.burglary);
    expect(custom.question, 'Marcas de ferramenta fotografadas em detalhe?');
    expect(custom.required, isTrue);
    expect(
      custom.defaultNote,
      'Priorizar portas, janelas, fechaduras e batentes.',
    );
    expect(custom.origin, ChecklistItemOrigin.added);
    expect(custom.answer, ChecklistAnswer.yes);
    expect(custom.note, 'Fotos F3 e F4 vinculadas ao ponto de acesso.');
  });

  test('persists violent death metadata to local JSON file', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'sicro_campo_mv_test_',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final storage = FileOccurrenceStorage(
      directoryProvider: () async => tempDir,
    );
    final repository = OccurrenceRepository(storage: storage);
    await repository.load();

    await repository.createOccurrence(
      const CaseData(bo: 'MV-02/2026', municipality: 'Macapa'),
      metadata: const ForensicCaseMetadata(
        type: ForensicCaseType.violentDeath,
        violentDeathNature: ViolentDeathNature.homicide,
        bodyState: BodyState.present,
        victimCount: VictimCount.one,
        sceneEnvironment: SceneEnvironment.publicRoad,
        expectedViolentDeathTraces: [
          ExpectedViolentDeathTrace.bloodBiologicalStain,
          ExpectedViolentDeathTrace.cases,
          ExpectedViolentDeathTrace.projectiles,
        ],
      ),
    );

    final restored = OccurrenceRepository(storage: storage);
    await restored.load();

    final metadata = restored.occurrences.first.metadata;
    expect(metadata.type, ForensicCaseType.violentDeath);
    expect(restored.occurrences.first.checklist, isNotEmpty);
    expect(restored.occurrences.first.checklist.first.id, startsWith('mv_'));
    expect(
      restored.occurrences.first.checklist.where(
        (item) => item.category == ChecklistCategory.bodyVictim,
      ),
      isNotEmpty,
    );
    expect(metadata.primaryNatureCode, 'homicidio');
    expect(metadata.violentDeathNature, ViolentDeathNature.homicide);
    expect(metadata.bodyState, BodyState.present);
    expect(metadata.victimCount, VictimCount.one);
    expect(metadata.sceneEnvironment, SceneEnvironment.publicRoad);
    expect(metadata.expectedViolentDeathTraces, [
      ExpectedViolentDeathTrace.bloodBiologicalStain,
      ExpectedViolentDeathTrace.cases,
      ExpectedViolentDeathTrace.projectiles,
    ]);
  });

  test('persists property metadata and checklist to local JSON file', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'sicro_campo_property_test_',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final storage = FileOccurrenceStorage(
      directoryProvider: () async => tempDir,
    );
    final repository = OccurrenceRepository(storage: storage);
    await repository.load();

    await repository.createOccurrence(
      const CaseData(bo: 'PAT-02/2026', municipality: 'Macapa'),
      metadata: const ForensicCaseMetadata(
        type: ForensicCaseType.property,
        propertyNature: PropertyNature.fire,
      ),
    );

    final restored = OccurrenceRepository(storage: storage);
    await restored.load();

    final occurrence = restored.occurrences.first;
    expect(occurrence.metadata.type, ForensicCaseType.property);
    expect(occurrence.metadata.primaryNatureCode, 'incendio');
    expect(occurrence.metadata.propertyNature, PropertyNature.fire);
    expect(occurrence.checklist, isNotEmpty);
    expect(occurrence.checklist.first.id, startsWith('pat_incendio'));
    expect(
      occurrence.checklist.where(
        (item) => item.category == ChecklistCategory.fire,
      ),
      isNotEmpty,
    );
    expect(
      occurrence.operationalProgress.pendingItems,
      contains('Nenhum vestigio patrimonial cadastrado'),
    );
  });

  test('aggregates local occurrence statistics for current month', () {
    final now = DateTime(2026, 5, 21, 12);
    final occurrences = [
      _statsOccurrence(
        id: 'occ_transito',
        startedAt: DateTime(2026, 5, 10, 8),
        finishedAt: DateTime(2026, 5, 10, 10),
        status: OccurrenceStatus.completed,
        metadata: const ForensicCaseMetadata(
          trafficNature: TrafficNature.collision,
          result: OccurrenceResult.injuredVictim,
        ),
        municipality: 'Macapa',
        district: 'Centro',
        photos: 2,
        vehicles: 1,
        victims: 1,
        traces: 2,
        measurements: 1,
        notes: 1,
        answeredChecklist: 2,
      ),
      _statsOccurrence(
        id: 'occ_mv',
        startedAt: DateTime(2026, 5, 20, 14),
        finishedAt: DateTime(2026, 5, 20, 15),
        status: OccurrenceStatus.exported,
        exportedAt: DateTime(2026, 5, 20, 16),
        metadata: const ForensicCaseMetadata(
          type: ForensicCaseType.violentDeath,
          violentDeathNature: ViolentDeathNature.homicide,
        ),
        municipality: 'Santana',
        district: 'Fonte Nova',
        photos: 1,
        victims: 1,
        traces: 1,
        answeredChecklist: 1,
      ),
      _statsOccurrence(
        id: 'occ_antiga',
        startedAt: DateTime(2026, 4, 30, 9),
        finishedAt: DateTime(2026, 4, 30, 10),
        status: OccurrenceStatus.completed,
        metadata: const ForensicCaseMetadata(
          type: ForensicCaseType.property,
          propertyNature: PropertyNature.damages,
        ),
        municipality: 'Macapa',
        district: 'Buritizal',
        photos: 4,
      ),
    ];

    final snapshot = const OperationalStatisticsService().aggregate(
      occurrences,
      const StatisticsFilter(period: StatisticsPeriodPreset.currentMonth),
      now: now,
    );

    expect(snapshot.totalOccurrences, 2);
    expect(snapshot.completedOccurrences, 1);
    expect(snapshot.exportedOccurrences, 1);
    expect(snapshot.totalDurationSeconds, 10800);
    expect(snapshot.averageDurationSeconds, 5400);
    expect(snapshot.totalPhotos, 3);
    expect(snapshot.totalTraces, 3);
    expect(snapshot.totalMeasurements, 1);
    expect(snapshot.totalVictims, 2);
    expect(snapshot.totalVehicles, 1);
    expect(snapshot.totalNotes, 1);
    expect(snapshot.averagePhotosPerOccurrence, 1.5);
    expect(snapshot.firstOccurrenceAt, DateTime(2026, 5, 10, 8));
    expect(snapshot.lastOccurrenceAt, DateTime(2026, 5, 20, 14));
    expect(_distributionLabels(snapshot.byType), [
      'Local de crime',
      'Transito',
    ]);
    expect(snapshot.byNature.first.label, 'Colisao');
    expect(snapshot.byMonth.single.label, '05/2026');
    expect(snapshot.byMunicipality.map((entry) => entry.label), [
      'Macapa',
      'Santana',
    ]);
  });

  test('filters statistics by type, status and custom period', () {
    final occurrences = [
      _statsOccurrence(
        id: 'occ_exportada',
        startedAt: DateTime(2026, 5, 20, 14),
        finishedAt: DateTime(2026, 5, 20, 15),
        status: OccurrenceStatus.exported,
        exportedAt: DateTime(2026, 5, 20, 16),
        metadata: const ForensicCaseMetadata(
          type: ForensicCaseType.violentDeath,
          violentDeathNature: ViolentDeathNature.suspiciousDeath,
        ),
      ),
      _statsOccurrence(
        id: 'occ_concluida',
        startedAt: DateTime(2026, 5, 20, 18),
        finishedAt: DateTime(2026, 5, 20, 19),
        status: OccurrenceStatus.completed,
        metadata: const ForensicCaseMetadata(
          type: ForensicCaseType.violentDeath,
          violentDeathNature: ViolentDeathNature.homicide,
        ),
      ),
      _statsOccurrence(
        id: 'occ_transito',
        startedAt: DateTime(2026, 5, 21, 8),
        finishedAt: DateTime(2026, 5, 21, 9),
        status: OccurrenceStatus.exported,
        metadata: const ForensicCaseMetadata(
          trafficNature: TrafficNature.collision,
        ),
      ),
    ];

    final snapshot = const OperationalStatisticsService().aggregate(
      occurrences,
      StatisticsFilter(
        period: StatisticsPeriodPreset.custom,
        customStart: DateTime(2026, 5, 20),
        customEnd: DateTime(2026, 5, 20),
        type: ForensicCaseType.violentDeath,
        status: OccurrenceStatus.exported,
      ),
      now: DateTime(2026, 5, 21, 12),
    );

    expect(snapshot.totalOccurrences, 1);
    expect(snapshot.stats.single.occurrenceId, 'occ_exportada');
    expect(snapshot.byNature.single.label, 'Morte suspeita');
    expect(snapshot.exportedOccurrences, 1);
  });
}

FieldOccurrence _statsOccurrence({
  required String id,
  required DateTime startedAt,
  DateTime? finishedAt,
  DateTime? exportedAt,
  OccurrenceStatus status = OccurrenceStatus.inProgress,
  ForensicCaseMetadata metadata = const ForensicCaseMetadata(),
  String municipality = '',
  String district = '',
  int photos = 0,
  int vehicles = 0,
  int victims = 0,
  int traces = 0,
  int measurements = 0,
  int notes = 0,
  int answeredChecklist = 0,
}) {
  return FieldOccurrence(
    id: id,
    createdAt: startedAt,
    updatedAt: finishedAt ?? startedAt,
    startedAt: startedAt,
    finishedAt: finishedAt,
    exportedAt: exportedAt,
    status: status,
    metadata: metadata,
    caseData: CaseData(
      municipality: municipality,
      district: district,
      street: municipality.isEmpty ? '' : 'Rua Teste',
    ),
    photos: List.generate(
      photos,
      (index) => FieldPhoto(
        id: 'foto_${id}_$index',
        filePath: 'foto_$index.jpg',
        category: PhotoCategory.overview,
        capturedAt: startedAt,
      ),
    ),
    vehicles: List.generate(
      vehicles,
      (index) => VehicleRecord(id: 'veiculo_$index', identifier: 'V$index'),
    ),
    victims: List.generate(
      victims,
      (index) => VictimRecord(id: 'vitima_$index', identifier: 'P$index'),
    ),
    traces: List.generate(
      traces,
      (index) => TraceRecord(
        id: 'vestigio_$index',
        identifier: 'E$index',
        type: TraceType.other,
      ),
    ),
    measurements: List.generate(
      measurements,
      (index) => MeasurementRecord(
        id: 'medicao_$index',
        label: 'M$index',
        value: index + 1,
      ),
    ),
    notes: List.generate(
      notes,
      (index) => FieldNote(
        id: 'nota_$index',
        createdAt: startedAt,
        text: 'Observacao $index',
      ),
    ),
    checklist: List.generate(
      answeredChecklist,
      (index) => ChecklistItem(
        id: 'check_$index',
        category: ChecklistCategory.preservation,
        question: 'Item $index',
        answer: ChecklistAnswer.yes,
      ),
    ),
  );
}

List<String> _distributionLabels(List<DistributionEntry> entries) {
  return entries.map((entry) => entry.label).toList();
}
