import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sicro_campo/core/data/sicrocampo_export_service.dart';
import 'package:sicro_campo/core/data/sicrocampo_package_contract.dart';
import 'package:sicro_campo/domain/models/case_data.dart';
import 'package:sicro_campo/domain/models/checklist_item.dart';
import 'package:sicro_campo/domain/models/field_note.dart';
import 'package:sicro_campo/domain/models/field_photo.dart';
import 'package:sicro_campo/domain/models/forensic_case_metadata.dart';
import 'package:sicro_campo/domain/models/location_record.dart';
import 'package:sicro_campo/domain/models/measurement_record.dart';
import 'package:sicro_campo/domain/models/official_document.dart';
import 'package:sicro_campo/domain/models/occurrence.dart';
import 'package:sicro_campo/domain/models/trace_record.dart';
import 'package:sicro_campo/domain/models/vehicle_record.dart';
import 'package:sicro_campo/domain/models/victim_record.dart';

void main() {
  test(
    'exports occurrence as .sicroapp zip with JSONs, photos and hashes',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'sicro_export_test_',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final photoFile = File(
        '${tempDir.path}${Platform.pathSeparator}foto_1.jpg',
      );
      await photoFile.writeAsBytes([1, 2, 3, 4, 5]);
      final officialDocumentFile = File(
        '${tempDir.path}${Platform.pathSeparator}oficio_1.jpg',
      );
      await officialDocumentFile.writeAsBytes([9, 8, 7, 6]);

      final occurrence = FieldOccurrence(
        id: 'occ_1',
        createdAt: DateTime(2026, 5, 19, 10),
        updatedAt: DateTime(2026, 5, 19, 11),
        metadata: const ForensicCaseMetadata(
          trafficNature: TrafficNature.collision,
          trafficInvolved: [TrafficInvolved.car, TrafficInvolved.motorcycle],
          officialVehicleInvolved: true,
          result: OccurrenceResult.injuredVictim,
        ),
        notApplicableItems: const [OperationalItemIds.tracePhotos],
        caseData: const CaseData(
          bo: '123/2026',
          municipality: 'Macapa',
          supportTeam: 'Tecnico A',
          policeTeam: '2o BPM',
          policeCommander: 'Tenente Fulano',
        ),
        location: LocationRecord(
          latitude: 0.0349,
          longitude: -51.0694,
          accuracyMeters: 4.2,
          capturedAt: DateTime(2026, 5, 19, 10, 30),
        ),
        checklist: const [
          ChecklistItem(
            id: 'local_preservado',
            category: ChecklistCategory.preservation,
            question: 'Local preservado?',
            required: true,
            answer: ChecklistAnswer.yes,
            defaultNote: 'Registrar a equipe responsavel pela preservacao.',
            origin: ChecklistItemOrigin.added,
          ),
        ],
        photos: [
          FieldPhoto(
            id: 'foto_1',
            filePath: photoFile.path,
            category: PhotoCategory.overview,
            capturedAt: DateTime(2026, 5, 19, 10, 40),
            sha256: 'hash_original',
          ),
        ],
        vehicles: const [
          VehicleRecord(
            id: 'vehicle_1',
            identifier: 'V1',
            plate: 'ABC1D23',
            model: 'SUV',
            impactPoint: 'Frontal direita',
            photoIds: ['foto_1'],
          ),
        ],
        victims: [
          VictimRecord(
            id: 'victim_1',
            identifier: 'P1',
            name: 'Pessoa envolvida',
            condition: VictimCondition.injured,
            type: VictimType.driver,
            removalStatus: VictimRemovalStatus.yes,
            rescuedBy: 'SAMU',
            destination: 'Hospital de Emergencia',
            removedAt: DateTime(2026, 5, 19, 10, 45),
            bodyPosition: 'Decubito dorsal proximo ao veiculo.',
            protectiveEquipment: 'Capacete localizado ao lado.',
            note: 'Vinculada a foto geral do local.',
            photoIds: const ['foto_1'],
          ),
        ],
        traces: const [
          TraceRecord(
            id: 'trace_1',
            identifier: 'V1',
            type: TraceType.braking,
            description: 'Frenagem na faixa direita.',
            length: 12.4,
            photoIds: ['foto_1'],
          ),
        ],
        measurements: const [
          MeasurementRecord(
            id: 'measurement_1',
            label: 'M1',
            pointA: 'V1',
            pointB: 'Ponto de impacto',
            value: 8.6,
            method: 'trena_laser',
            photoIds: ['foto_1'],
          ),
        ],
        notes: [
          FieldNote(
            id: 'note_1',
            createdAt: DateTime(2026, 5, 19, 10, 50),
            updatedAt: DateTime(2026, 5, 19, 11, 5),
            text: 'Sem energia no semaforo no momento do exame.',
            category: NoteCategory.location,
            priority: NotePriority.critical,
          ),
        ],
      );

      final service = SicroCampoExportService(
        outputDirectoryProvider: () async => tempDir,
        clock: () => DateTime(2026, 5, 19, 12, 13, 14),
      );

      final result = await service.exportOccurrence(
        occurrence,
        officialDocuments: [
          OfficialDocument(
            id: 'oficio_1',
            createdAt: DateTime(2026, 5, 19, 9),
            updatedAt: DateTime(2026, 5, 19, 9, 10),
            status: OfficialDocumentStatus.linked,
            imagePath: officialDocumentFile.path,
            imageSha256: 'oficio_hash_original',
            documentNumber: '8971/2026',
            boNumber: '123/2026',
            linkedOccurrenceId: occurrence.id,
          ),
        ],
      );

      expect(result.fileName, endsWith(SicroCampoPackageContract.extension));
      expect(await result.file.exists(), isTrue);
      expect(result.sizeBytes, greaterThan(0));
      expect(
        result.sha256,
        sha256.convert(await result.file.readAsBytes()).toString(),
      );
      expect(result.photosTotal, 1);
      expect(result.photosIncluded, 1);
      expect(result.photosMissing, 0);
      expect(result.officialDocumentsTotal, 1);
      expect(result.officialDocumentsIncluded, 1);
      expect(result.officialDocumentsMissing, 0);
      expect(result.hashesReady, isTrue);
      expect(result.hashCount, greaterThan(0));
      expect(result.warnings, isEmpty);
      expect(result.generatedAt, DateTime(2026, 5, 19, 12, 13, 14));

      final archive = ZipDecoder().decodeBytes(await result.file.readAsBytes());

      Map<String, Object?> jsonObject(String path) {
        final file = archive.findFile(path);
        expect(file, isNotNull, reason: '$path deve existir no pacote');
        return jsonDecode(utf8.decode(file!.content)) as Map<String, Object?>;
      }

      List<Object?> jsonList(String path) {
        final file = archive.findFile(path);
        expect(file, isNotNull, reason: '$path deve existir no pacote');
        return jsonDecode(utf8.decode(file!.content)) as List<Object?>;
      }

      final manifest = jsonObject(SicroCampoPackageContract.manifest);
      expect(manifest['formato'], SicroCampoPackageContract.format);
      expect(manifest['formato'], 'sicroapp');
      expect(
        manifest['extensoes_compativeis'],
        contains(SicroCampoPackageContract.legacyExtension),
      );
      expect(manifest['versao'], SicroCampoPackageContract.version);
      expect(
        manifest['versoes_compativeis'],
        SicroCampoPackageContract.compatibleVersions,
      );
      expect(
        manifest['arquivos'],
        contains(SicroCampoPackageContract.metadata),
      );
      expect(
        manifest['arquivos'],
        contains(SicroCampoPackageContract.caseData),
      );
      expect(
        manifest['arquivos'],
        contains(SicroCampoPackageContract.location),
      );
      expect(
        manifest['arquivos'],
        contains(SicroCampoPackageContract.gpsTrack),
      );
      expect(
        manifest['arquivos'],
        contains(SicroCampoPackageContract.statistics),
      );
      expect(
        manifest['arquivos'],
        contains(SicroCampoPackageContract.timeline),
      );
      expect(
        manifest['arquivos'],
        contains(SicroCampoPackageContract.checklist),
      );
      expect(manifest['arquivos'], contains(SicroCampoPackageContract.photos));
      expect(
        manifest['arquivos'],
        contains(SicroCampoPackageContract.vehicles),
      );
      expect(manifest['arquivos'], contains(SicroCampoPackageContract.victims));
      expect(manifest['arquivos'], contains(SicroCampoPackageContract.traces));
      expect(
        manifest['arquivos'],
        contains(SicroCampoPackageContract.measurements),
      );
      expect(manifest['arquivos'], contains(SicroCampoPackageContract.notes));
      expect(
        manifest['arquivos'],
        contains(SicroCampoPackageContract.officialDocuments),
      );
      expect(
        manifest['arquivos'],
        contains(SicroCampoPackageContract.operational),
      );
      expect(manifest['arquivos'], contains(SicroCampoPackageContract.hashes));
      final occurrenceMeta = (manifest['ocorrencia'] as Map)
          .cast<String, Object?>();
      expect(occurrenceMeta['status'], 'exportada');
      expect(
        occurrenceMeta['iniciado_em'],
        DateTime(2026, 5, 19, 10).toIso8601String(),
      );
      expect(occurrenceMeta['duracao_segundos'], greaterThanOrEqualTo(0));
      expect(occurrenceMeta['tipo_pericia'], 'transito');
      expect(occurrenceMeta['natureza'], 'colisao');
      expect(occurrenceMeta['resultado'], 'vitima_lesionada');
      final counts = (manifest['contagens'] as Map).cast<String, Object?>();
      expect(counts['fotos'], 1);
      expect(counts['timeline'], greaterThan(0));
      expect(counts['leituras_gps'], 0);
      expect(counts['veiculos'], 1);
      expect(counts['vitimas'], 1);
      expect(counts['vestigios'], 1);
      expect(counts['medicoes'], 1);
      expect(counts['observacoes'], 1);
      expect(counts['oficios'], 1);

      final metadata = jsonObject(SicroCampoPackageContract.metadata);
      expect(metadata['tipo_pericia'], 'transito');
      expect(metadata['natureza'], 'colisao');
      expect(metadata['envolvidos'], ['carro', 'moto']);
      expect(metadata['veiculo_oficial'], isTrue);
      expect(metadata['resultado'], 'vitima_lesionada');
      final caseData = jsonObject(SicroCampoPackageContract.caseData);
      expect(caseData['bo'], '123/2026');
      expect(caseData['tecnico_pericial'], 'Tecnico A');
      expect(caseData['equipe_apoio'], 'Tecnico A');
      expect(caseData['equipe_policial'], '2o BPM');
      expect(caseData['comandante_policial'], 'Tenente Fulano');
      expect(jsonObject(SicroCampoPackageContract.location)['precisao_m'], 4.2);
      expect(jsonList(SicroCampoPackageContract.gpsTrack), isEmpty);
      final statistics = jsonObject(SicroCampoPackageContract.statistics);
      expect(statistics['tipo_pericia'], 'transito');
      expect(statistics['natureza'], 'colisao');
      expect(statistics['resultado'], 'vitima_lesionada');
      expect(statistics['status_operacional'], 'exportada');
      expect(statistics['municipio'], 'Macapa');
      expect(statistics['endereco'], contains('Macapa'));
      expect(statistics['total_fotos'], 1);
      expect(statistics['total_veiculos'], 1);
      expect(statistics['total_vitimas_corpos'], 1);
      expect(statistics['total_vestigios'], 1);
      expect(statistics['total_medicoes'], 1);
      expect(statistics['total_observacoes'], 1);
      expect(statistics['itens_checklist_respondidos'], 1);
      expect(statistics['itens_nao_aplicaveis'], 1);
      expect(statistics['exportada'], isTrue);
      expect(
        statistics['ultima_exportacao_em'],
        DateTime(2026, 5, 19, 12, 13, 14).toIso8601String(),
      );
      expect(statistics['melhor_precisao_gps_m'], 4.2);
      expect(statistics['coordenada_principal'], isA<Map<String, Object?>>());
      expect(statistics['pendencias_encerramento'], isA<List<Object?>>());
      final timeline = jsonList(SicroCampoPackageContract.timeline);
      expect(timeline, isNotEmpty);
      expect(
        (timeline.first as Map<String, Object?>)['tipo'],
        'ocorrencia_criada',
      );
      final operational = jsonObject(SicroCampoPackageContract.operational);
      expect(operational['sessao'], isA<Map>());
      expect(operational['percentual'], 100);
      expect(operational['nao_aplicavel'], [OperationalItemIds.tracePhotos]);
      expect(
        operational['pendencias'],
        isNot(contains('Nenhuma foto de vestigio')),
      );
      final flow = operational['fluxo_sugerido'] as List;
      final tracePhotoStep = flow.cast<Map>().firstWhere(
        (item) => item['id'] == OperationalItemIds.tracePhotos,
      );
      expect(tracePhotoStep['estado'], 'nao_aplicavel');
      final checklist = jsonList(SicroCampoPackageContract.checklist);
      expect(checklist, hasLength(1));
      final checklistItem = checklist.first as Map<String, Object?>;
      expect(checklistItem['origem'], 'adicionado');
      expect(
        checklistItem['observacao_padrao'],
        'Registrar a equipe responsavel pela preservacao.',
      );
      final vehicles = jsonList(SicroCampoPackageContract.vehicles);
      final victims = jsonList(SicroCampoPackageContract.victims);
      final traces = jsonList(SicroCampoPackageContract.traces);
      final measurements = jsonList(SicroCampoPackageContract.measurements);
      final notes = jsonList(SicroCampoPackageContract.notes);
      final officialDocuments = jsonList(
        SicroCampoPackageContract.officialDocuments,
      );
      expect(vehicles, hasLength(1));
      expect(victims, hasLength(1));
      expect(traces, hasLength(1));
      expect(measurements, hasLength(1));
      expect(notes, hasLength(1));
      expect(officialDocuments, hasLength(1));
      expect(
        (officialDocuments.first as Map<String, Object?>)['oficio_numero'],
        '8971/2026',
      );
      expect(
        (officialDocuments.first as Map<String, Object?>)['imagem_arquivo'],
        'oficios/oficio_1.jpg',
      );
      expect((vehicles.first as Map<String, Object?>)['fotos'], ['foto_1']);
      expect(
        (vehicles.first as Map<String, Object?>)['ponto_impacto'],
        'Frontal direita',
      );
      expect((victims.first as Map<String, Object?>)['fotos'], ['foto_1']);
      expect((victims.first as Map<String, Object?>)['removida'], 'sim');
      expect((victims.first as Map<String, Object?>)['condicao'], 'lesionada');
      expect((traces.first as Map<String, Object?>)['fotos'], ['foto_1']);
      expect((measurements.first as Map<String, Object?>)['fotos'], ['foto_1']);
      expect((notes.first as Map<String, Object?>)['categoria'], 'local');
      expect((notes.first as Map<String, Object?>)['prioridade'], 'critica');

      final photos = jsonList(SicroCampoPackageContract.photos);
      expect(photos, hasLength(1));
      final photo = photos.first as Map<String, Object?>;
      expect(photo['arquivo'], 'fotos/foto_1.jpg');
      expect(photo['arquivo_disponivel'], isTrue);
      expect(archive.findFile('fotos/foto_1.jpg'), isNotNull);

      final hashes = jsonObject(SicroCampoPackageContract.hashes);
      final hashFiles = (hashes['arquivos'] as List)
          .cast<Map>()
          .map((item) => item['caminho'])
          .toList();
      expect(hashFiles, contains(SicroCampoPackageContract.manifest));
      expect(hashFiles, contains('fotos/foto_1.jpg'));
      expect(hashFiles, contains('oficios/oficio_1.jpg'));
      expect(hashFiles, isNot(contains(SicroCampoPackageContract.hashes)));

      await service.deleteExportedPackage(result.fileName);
      expect(await result.file.exists(), isFalse);
    },
  );

  test('exports violent death metadata in metadados.json', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'sicro_export_mv_test_',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final occurrence = FieldOccurrence(
      id: 'occ_mv_1',
      createdAt: DateTime(2026, 5, 20, 9),
      updatedAt: DateTime(2026, 5, 20, 9, 30),
      metadata: const ForensicCaseMetadata(
        type: ForensicCaseType.violentDeath,
        violentDeathNature: ViolentDeathNature.suspiciousDeath,
        bodyState: BodyState.removed,
        victimCount: VictimCount.two,
        sceneEnvironment: SceneEnvironment.residence,
        expectedViolentDeathTraces: [
          ExpectedViolentDeathTrace.bloodBiologicalStain,
          ExpectedViolentDeathTrace.footprints,
        ],
      ),
      caseData: const CaseData(bo: 'MV-01/2026', municipality: 'Macapa'),
    );

    final service = SicroCampoExportService(
      outputDirectoryProvider: () async => tempDir,
      clock: () => DateTime(2026, 5, 20, 10),
    );

    final result = await service.exportOccurrence(occurrence);
    final archive = ZipDecoder().decodeBytes(await result.file.readAsBytes());

    Map<String, Object?> jsonObject(String path) {
      final file = archive.findFile(path);
      expect(file, isNotNull, reason: '$path deve existir no pacote');
      return jsonDecode(utf8.decode(file!.content)) as Map<String, Object?>;
    }

    final manifest = jsonObject(SicroCampoPackageContract.manifest);
    final occurrenceMeta = (manifest['ocorrencia'] as Map)
        .cast<String, Object?>();
    expect(occurrenceMeta['tipo_pericia'], 'morte_violenta');
    expect(occurrenceMeta['natureza'], 'morte_suspeita');

    final metadata = jsonObject(SicroCampoPackageContract.metadata);
    final violentDeath = (metadata['morte_violenta'] as Map)
        .cast<String, Object?>();
    expect(metadata['tipo_pericia'], 'morte_violenta');
    expect(metadata['natureza'], 'morte_suspeita');
    expect(violentDeath['estado_vitima_corpo'], 'corpo_removido');
    expect(violentDeath['quantidade_vitimas'], 'duas_vitimas');
    expect(violentDeath['ambiente_local'], 'residencia');
    expect(violentDeath['vestigios_esperados'], [
      'sangue_mancha_biologica',
      'pegadas',
    ]);
  });

  test('exports property metadata in metadados.json', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'sicro_export_property_test_',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final occurrence = FieldOccurrence(
      id: 'occ_pat_1',
      createdAt: DateTime(2026, 5, 21, 9),
      updatedAt: DateTime(2026, 5, 21, 9, 30),
      metadata: const ForensicCaseMetadata(
        type: ForensicCaseType.property,
        propertyNature: PropertyNature.burglary,
      ),
      caseData: const CaseData(bo: 'PAT-01/2026', municipality: 'Macapa'),
    );

    final service = SicroCampoExportService(
      outputDirectoryProvider: () async => tempDir,
      clock: () => DateTime(2026, 5, 21, 10),
    );

    final result = await service.exportOccurrence(occurrence);
    final archive = ZipDecoder().decodeBytes(await result.file.readAsBytes());

    Map<String, Object?> jsonObject(String path) {
      final file = archive.findFile(path);
      expect(file, isNotNull, reason: '$path deve existir no pacote');
      return jsonDecode(utf8.decode(file!.content)) as Map<String, Object?>;
    }

    final manifest = jsonObject(SicroCampoPackageContract.manifest);
    final occurrenceMeta = (manifest['ocorrencia'] as Map)
        .cast<String, Object?>();
    expect(occurrenceMeta['tipo_pericia'], 'patrimonio');
    expect(occurrenceMeta['natureza'], 'arrombamento');

    final metadata = jsonObject(SicroCampoPackageContract.metadata);
    final property = (metadata['patrimonio'] as Map).cast<String, Object?>();
    expect(metadata['tipo_pericia'], 'patrimonio');
    expect(metadata['natureza'], 'arrombamento');
    expect(property['natureza'], 'arrombamento');
  });

  test('exports environmental metadata in metadados.json', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'sicro_export_environmental_test_',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final occurrence = FieldOccurrence(
      id: 'occ_amb_1',
      createdAt: DateTime(2026, 5, 23, 9),
      updatedAt: DateTime(2026, 5, 23, 9, 30),
      metadata: const ForensicCaseMetadata(
        type: ForensicCaseType.environmental,
        environmentalNature: EnvironmentalNature.waterPollution,
        environmentalContext: EnvironmentalSceneContext.waterBody,
        expectedEnvironmentalEvidences: [
          ExpectedEnvironmentalEvidence.waterBodyImpact,
          ExpectedEnvironmentalEvidence.effluentContaminant,
          ExpectedEnvironmentalEvidence.samples,
        ],
      ),
      caseData: const CaseData(bo: 'AMB-01/2026', municipality: 'Macapa'),
    );

    final service = SicroCampoExportService(
      outputDirectoryProvider: () async => tempDir,
      clock: () => DateTime(2026, 5, 23, 10),
    );

    final result = await service.exportOccurrence(occurrence);
    final archive = ZipDecoder().decodeBytes(await result.file.readAsBytes());

    Map<String, Object?> jsonObject(String path) {
      final file = archive.findFile(path);
      expect(file, isNotNull, reason: '$path deve existir no pacote');
      return jsonDecode(utf8.decode(file!.content)) as Map<String, Object?>;
    }

    final manifest = jsonObject(SicroCampoPackageContract.manifest);
    final occurrenceMeta = (manifest['ocorrencia'] as Map)
        .cast<String, Object?>();
    expect(occurrenceMeta['tipo_pericia'], 'ambiental');
    expect(occurrenceMeta['natureza'], 'poluicao_hidrica');

    final metadata = jsonObject(SicroCampoPackageContract.metadata);
    final environmental = (metadata['ambiental'] as Map)
        .cast<String, Object?>();
    expect(metadata['tipo_pericia'], 'ambiental');
    expect(metadata['natureza'], 'poluicao_hidrica');
    expect(environmental['natureza'], 'poluicao_hidrica');
    expect(environmental['contexto_local'], 'corpo_hidrico');
    expect(environmental['vestigios_esperados'], [
      'corpo_hidrico_atingido',
      'efluente_contaminante',
      'amostras',
    ]);
  });

  test('exports ballistics metadata in metadados.json', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'sicro_export_ballistics_test_',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final occurrence = FieldOccurrence(
      id: 'occ_bal_1',
      createdAt: DateTime(2026, 5, 23, 11),
      updatedAt: DateTime(2026, 5, 23, 11, 30),
      metadata: const ForensicCaseMetadata(
        type: ForensicCaseType.ballistics,
        ballisticsNature: BallisticsNature.ballisticComparison,
        ballisticsContext: BallisticsContext.seizedMaterial,
        expectedBallisticEvidences: [
          ExpectedBallisticEvidence.firearm,
          ExpectedBallisticEvidence.cases,
          ExpectedBallisticEvidence.projectiles,
          ExpectedBallisticEvidence.ballisticStandards,
          ExpectedBallisticEvidence.packagesSeals,
          ExpectedBallisticEvidence.documents,
        ],
      ),
      caseData: const CaseData(bo: 'BAL-01/2026', municipality: 'Macapa'),
    );

    final service = SicroCampoExportService(
      outputDirectoryProvider: () async => tempDir,
      clock: () => DateTime(2026, 5, 23, 12),
    );

    final result = await service.exportOccurrence(occurrence);
    final archive = ZipDecoder().decodeBytes(await result.file.readAsBytes());

    Map<String, Object?> jsonObject(String path) {
      final file = archive.findFile(path);
      expect(file, isNotNull, reason: '$path deve existir no pacote');
      return jsonDecode(utf8.decode(file!.content)) as Map<String, Object?>;
    }

    final manifest = jsonObject(SicroCampoPackageContract.manifest);
    final occurrenceMeta = (manifest['ocorrencia'] as Map)
        .cast<String, Object?>();
    expect(occurrenceMeta['tipo_pericia'], 'balistica_forense');
    expect(occurrenceMeta['natureza'], 'confronto_balistico');

    final metadata = jsonObject(SicroCampoPackageContract.metadata);
    final ballistics = (metadata['balistica_forense'] as Map)
        .cast<String, Object?>();
    expect(metadata['tipo_pericia'], 'balistica_forense');
    expect(metadata['natureza'], 'confronto_balistico');
    expect(ballistics['natureza'], 'confronto_balistico');
    expect(ballistics['contexto'], 'material_apreendido');
    expect(ballistics['vestigios_esperados'], [
      'arma_fogo',
      'capsulas_estojos',
      'projeteis',
      'padroes_balisticos',
      'embalagens_lacres',
      'documentos_requisicao',
    ]);
  });

  test('exports audio and image metadata in metadados.json', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'sicro_export_audio_image_test_',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final occurrence = FieldOccurrence(
      id: 'occ_ai_1',
      createdAt: DateTime(2026, 5, 23, 13),
      updatedAt: DateTime(2026, 5, 23, 13, 30),
      metadata: const ForensicCaseMetadata(
        type: ForensicCaseType.audioImage,
        audioImageNature: AudioImageNature.cctvPreservation,
        audioImageContext: AudioImageContext.cctvSystem,
        expectedAudioImageEvidences: [
          ExpectedAudioImageEvidence.cctvDvrNvr,
          ExpectedAudioImageEvidence.cameraSystem,
          ExpectedAudioImageEvidence.storageDevice,
          ExpectedAudioImageEvidence.videos,
          ExpectedAudioImageEvidence.accessCredentials,
          ExpectedAudioImageEvidence.hashes,
        ],
      ),
      caseData: const CaseData(bo: 'AI-01/2026', municipality: 'Macapa'),
    );

    final service = SicroCampoExportService(
      outputDirectoryProvider: () async => tempDir,
      clock: () => DateTime(2026, 5, 23, 14),
    );

    final result = await service.exportOccurrence(occurrence);
    final archive = ZipDecoder().decodeBytes(await result.file.readAsBytes());

    Map<String, Object?> jsonObject(String path) {
      final file = archive.findFile(path);
      expect(file, isNotNull, reason: '$path deve existir no pacote');
      return jsonDecode(utf8.decode(file!.content)) as Map<String, Object?>;
    }

    final manifest = jsonObject(SicroCampoPackageContract.manifest);
    final occurrenceMeta = (manifest['ocorrencia'] as Map)
        .cast<String, Object?>();
    expect(occurrenceMeta['tipo_pericia'], 'audio_imagem');
    expect(occurrenceMeta['natureza'], 'preservacao_cftv');

    final metadata = jsonObject(SicroCampoPackageContract.metadata);
    final audioImage = (metadata['audio_imagem'] as Map)
        .cast<String, Object?>();
    expect(metadata['tipo_pericia'], 'audio_imagem');
    expect(metadata['natureza'], 'preservacao_cftv');
    expect(audioImage['natureza'], 'preservacao_cftv');
    expect(audioImage['contexto'], 'sistema_cftv');
    expect(audioImage['vestigios_esperados'], [
      'dvr_nvr_cftv',
      'sistema_camera',
      'dispositivo_armazenamento',
      'videos',
      'credenciais_acesso',
      'hashes',
    ]);
  });

  test('exports papiloscopy metadata in metadados.json', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'sicro_export_papiloscopy_test_',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final occurrence = FieldOccurrence(
      id: 'occ_pap_1',
      createdAt: DateTime(2026, 5, 23, 15),
      updatedAt: DateTime(2026, 5, 23, 15, 30),
      metadata: const ForensicCaseMetadata(
        type: ForensicCaseType.papiloscopy,
        papiloscopyNature: PapiloscopyNature.crimeScenePrints,
        papiloscopyContext: PapiloscopyContext.crimeScene,
        expectedPapiloscopyEvidences: [
          ExpectedPapiloscopyEvidence.latentPrints,
          ExpectedPapiloscopyEvidence.patentPrints,
          ExpectedPapiloscopyEvidence.plasticPrints,
          ExpectedPapiloscopyEvidence.questionedObjects,
          ExpectedPapiloscopyEvidence.adhesiveLifts,
          ExpectedPapiloscopyEvidence.photographs,
        ],
      ),
      caseData: const CaseData(bo: 'PAP-01/2026', municipality: 'Macapa'),
    );

    final service = SicroCampoExportService(
      outputDirectoryProvider: () async => tempDir,
      clock: () => DateTime(2026, 5, 23, 16),
    );

    final result = await service.exportOccurrence(occurrence);
    final archive = ZipDecoder().decodeBytes(await result.file.readAsBytes());

    Map<String, Object?> jsonObject(String path) {
      final file = archive.findFile(path);
      expect(file, isNotNull, reason: '$path deve existir no pacote');
      return jsonDecode(utf8.decode(file!.content)) as Map<String, Object?>;
    }

    final manifest = jsonObject(SicroCampoPackageContract.manifest);
    final occurrenceMeta = (manifest['ocorrencia'] as Map)
        .cast<String, Object?>();
    expect(occurrenceMeta['tipo_pericia'], 'papiloscopia');
    expect(occurrenceMeta['natureza'], 'levantamento_local');

    final metadata = jsonObject(SicroCampoPackageContract.metadata);
    final papiloscopy = (metadata['papiloscopia'] as Map)
        .cast<String, Object?>();
    expect(metadata['tipo_pericia'], 'papiloscopia');
    expect(metadata['natureza'], 'levantamento_local');
    expect(papiloscopy['natureza'], 'levantamento_local');
    expect(papiloscopy['contexto'], 'local_crime');
    expect(papiloscopy['vestigios_esperados'], [
      'impressao_latente',
      'impressao_patente',
      'impressao_moldada',
      'objetos_questionados',
      'suportes_adesivos',
      'fotografias',
    ]);
  });
}
