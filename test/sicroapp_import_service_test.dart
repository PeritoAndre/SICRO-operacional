import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sicro_campo/core/data/occurrence_repository.dart';
import 'package:sicro_campo/core/data/photo_file_storage.dart';
import 'package:sicro_campo/core/data/sicroapp_import_service.dart';
import 'package:sicro_campo/core/data/sicrocampo_package_contract.dart';
import 'package:sicro_campo/core/services/external_package_channel.dart';
import 'package:sicro_campo/domain/models/occurrence.dart';

void main() {
  test('validates received .sicroapp package and extracts summary', () async {
    final tempDir = await Directory.systemTemp.createTemp('sicro_import_test');
    addTearDown(() => tempDir.delete(recursive: true));

    final archive = Archive()
      ..addFile(
        ArchiveFile.bytes(
          SicroCampoPackageContract.manifest,
          utf8.encode(
            jsonEncode({
              'formato': 'sicroapp',
              'versao': '0.1',
              'gerado_em': '2026-05-22T10:30:00.000',
              'ocorrencia': {
                'id': 'occ_1',
                'status': 'exportada',
                'tipo_pericia': 'morte_violenta',
                'natureza': 'homicidio',
                'resultado': 'vitima_fatal',
                'duracao_segundos': 3600,
              },
              'contagens': {
                'fotos': 3,
                'vestigios': 2,
                'veiculos': 0,
                'vitimas': 1,
                'medicoes': 4,
                'observacoes': 2,
                'leituras_gps': 8,
              },
            }),
          ),
        ),
      )
      ..addFile(
        ArchiveFile.bytes(
          SicroCampoPackageContract.metadata,
          utf8.encode(
            jsonEncode({
              'tipo_pericia': 'morte_violenta',
              'natureza': 'homicidio',
              'resultado': 'vitima_fatal',
            }),
          ),
        ),
      )
      ..addFile(
        ArchiveFile.bytes(
          SicroCampoPackageContract.caseData,
          utf8.encode(
            jsonEncode({
              'bo': '123/2026',
              'protocolo': 'P-1',
              'municipio': 'Macapa',
              'bairro': 'Centro',
              'logradouro': 'Av. Teste',
            }),
          ),
        ),
      )
      ..addFile(
        ArchiveFile.bytes(
          SicroCampoPackageContract.hashes,
          utf8.encode(jsonEncode({'algoritmo': 'SHA-256', 'arquivos': []})),
        ),
      );

    final file = File('${tempDir.path}${Platform.pathSeparator}caso.sicroapp');
    await file.writeAsBytes(ZipEncoder().encodeBytes(archive));

    final result = await SicroAppImportService().validatePackage(
      ExternalPackageFile(
        ok: true,
        filePath: file.path,
        fileName: 'caso.sicroapp',
        originalName: 'caso.sicroapp',
        sourceUri: 'content://teste/caso.sicroapp',
        mimeType: 'application/octet-stream',
        sizeBytes: await file.length(),
        receivedAt: DateTime(2026, 5, 22, 10, 31),
      ),
    );

    expect(result.isValid, isTrue);
    expect(result.summary?.caseType, 'Local de crime');
    expect(result.summary?.nature, 'Homicidio');
    expect(result.summary?.result, 'Com vitima fatal');
    expect(result.summary?.bo, '123/2026');
    expect(result.summary?.photosCount, 3);
    expect(result.summary?.tracesCount, 2);
    expect(result.summary?.hashesPresent, isTrue);
  });

  test('rejects received package without manifest', () async {
    final tempDir = await Directory.systemTemp.createTemp('sicro_import_test');
    addTearDown(() => tempDir.delete(recursive: true));

    final archive = Archive()
      ..addFile(ArchiveFile.bytes('caso.json', utf8.encode('{}')));
    final file = File(
      '${tempDir.path}${Platform.pathSeparator}sem_manifest.sicroapp',
    );
    await file.writeAsBytes(ZipEncoder().encodeBytes(archive));

    final result = await SicroAppImportService().validatePackage(
      ExternalPackageFile(
        ok: true,
        filePath: file.path,
        fileName: 'sem_manifest.sicroapp',
        originalName: 'sem_manifest.sicroapp',
        sourceUri: 'content://teste/sem_manifest.sicroapp',
        mimeType: 'application/octet-stream',
        sizeBytes: await file.length(),
        receivedAt: DateTime(2026, 5, 22, 10, 31),
      ),
    );

    expect(result.isValid, isFalse);
    expect(result.validZip, isTrue);
    expect(result.validManifest, isFalse);
    expect(
      result.errors,
      contains('manifest.json nao encontrado ou invalido.'),
    );
  });

  test(
    'imports valid .sicroapp package as editable local occurrence',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'sicro_import_test',
      );
      addTearDown(() => tempDir.delete(recursive: true));

      final archive = Archive();
      final hashes = <String, String>{};

      void addBytes(String path, List<int> bytes) {
        archive.addFile(ArchiveFile.bytes(path, bytes));
        hashes[path] = sha256.convert(bytes).toString();
      }

      void addJson(String path, Object? data) {
        addBytes(path, utf8.encode(jsonEncode(data)));
      }

      addJson(SicroCampoPackageContract.manifest, {
        'formato': 'sicroapp',
        'versao': '0.1',
        'gerado_em': '2026-05-22T10:30:00.000',
        'ocorrencia': {
          'id': 'occ_original',
          'status': 'exportada',
          'tipo_pericia': 'transito',
          'natureza': 'colisao',
          'resultado': 'vitima_lesionada',
          'criado_em': '2026-05-22T09:00:00.000',
          'iniciado_em': '2026-05-22T09:05:00.000',
          'concluido_em': '2026-05-22T10:00:00.000',
          'duracao_segundos': 3300,
        },
        'contagens': {
          'fotos': 1,
          'vestigios': 1,
          'veiculos': 1,
          'vitimas': 0,
          'medicoes': 0,
          'observacoes': 1,
          'leituras_gps': 1,
        },
      });
      addJson(SicroCampoPackageContract.metadata, {
        'tipo_pericia': 'transito',
        'natureza': 'colisao',
        'envolvidos': ['carro', 'moto'],
        'resultado': 'vitima_lesionada',
      });
      addJson(SicroCampoPackageContract.caseData, {
        'bo': '321/2026',
        'protocolo': 'PROTO-321',
        'municipio': 'Macapa',
        'bairro': 'Centro',
        'logradouro': 'Rua Importada',
      });
      addJson(SicroCampoPackageContract.location, {
        'latitude': 0.065,
        'longitude': -51.05,
        'precisao_m': 4.2,
        'capturada_em': '2026-05-22T09:10:00.000',
        'fonte': 'gps',
      });
      addJson(SicroCampoPackageContract.gpsTrack, [
        {
          'latitude': 0.065,
          'longitude': -51.05,
          'precisao_m': 4.2,
          'capturada_em': '2026-05-22T09:10:00.000',
          'fonte': 'gps',
        },
      ]);
      addJson(SicroCampoPackageContract.checklist, [
        {
          'id': 'local_preservado',
          'categoria': 'preservacao_isolamento',
          'pergunta': 'Local preservado?',
          'obrigatorio': true,
          'resposta': 'sim',
        },
      ]);
      final photoBytes = utf8.encode('fake image bytes');
      final photoHash = sha256.convert(photoBytes).toString();
      addBytes('fotos/foto_1.jpg', photoBytes);
      addJson(SicroCampoPackageContract.photos, [
        {
          'id': 'foto_1',
          'arquivo': 'fotos/foto_1.jpg',
          'categoria': 'visao_geral',
          'capturada_em': '2026-05-22T09:12:00.000',
          'sha256': photoHash,
          'arquivo_disponivel': true,
        },
      ]);
      addJson(SicroCampoPackageContract.vehicles, [
        {
          'id': 'vehicle_1',
          'identificador': 'V1',
          'placa': 'ABC1D23',
          'tipo': 'carro',
          'fotos': ['foto_1'],
        },
      ]);
      addJson(SicroCampoPackageContract.victims, []);
      addJson(SicroCampoPackageContract.traces, [
        {
          'id': 'trace_1',
          'identificador': 'V1',
          'tipo': 'frenagem',
          'descricao': 'Marca de frenagem',
          'fotos': ['foto_1'],
        },
      ]);
      addJson(SicroCampoPackageContract.measurements, []);
      addJson(SicroCampoPackageContract.notes, [
        {
          'id': 'note_1',
          'texto': 'Observacao importada',
          'categoria': 'geral',
          'prioridade': 'normal',
          'criada_em': '2026-05-22T09:20:00.000',
          'editada_em': '2026-05-22T09:20:00.000',
        },
      ]);
      addJson(SicroCampoPackageContract.timeline, [
        {
          'id': 'timeline_1',
          'tipo': 'ocorrencia_criada',
          'descricao': 'Original criada.',
          'ocorrido_em': '2026-05-22T09:00:00.000',
        },
      ]);
      addJson(SicroCampoPackageContract.operational, {
        'nao_aplicavel': ['victims'],
      });
      addJson(SicroCampoPackageContract.statistics, {'duracao_segundos': 3300});
      addJson(SicroCampoPackageContract.hashes, {
        'algoritmo': 'SHA-256',
        'arquivos': hashes.entries
            .map((entry) => {'caminho': entry.key, 'sha256': entry.value})
            .toList(),
      });

      final packageFile = File(
        '${tempDir.path}${Platform.pathSeparator}pacote.sicroapp',
      );
      await packageFile.writeAsBytes(ZipEncoder().encodeBytes(archive));

      final service = SicroAppImportService(
        photoStorage: PhotoFileStorage(directoryProvider: () async => tempDir),
      );
      final validation = await service.validatePackage(
        _externalPackage(packageFile),
      );
      final repository = OccurrenceRepository();

      final imported = await service.importPackage(
        validation: validation,
        repository: repository,
      );

      expect(imported.imported, isTrue);
      expect(repository.occurrences, hasLength(1));
      final occurrence = imported.occurrence!;
      expect(occurrence.id, isNot('occ_original'));
      expect(occurrence.status, OccurrenceStatus.exported);
      expect(occurrence.caseData.bo, '321/2026');
      expect(occurrence.metadata.trafficNature?.label, 'Colisao');
      expect(occurrence.photos, hasLength(1));
      expect(occurrence.photos.first.id, 'foto_1');
      expect(await File(occurrence.photos.first.filePath).exists(), isTrue);
      expect(occurrence.vehicles.single.photoIds, contains('foto_1'));
      expect(occurrence.traces.single.photoIds, contains('foto_1'));
      expect(occurrence.notes.single.text, 'Observacao importada');
      expect(
        occurrence.effectiveTimeline.map((event) => event.type),
        contains(OccurrenceTimelineEventType.imported),
      );
    },
  );
}

ExternalPackageFile _externalPackage(File file) {
  return ExternalPackageFile(
    ok: true,
    filePath: file.path,
    fileName: file.uri.pathSegments.last,
    originalName: file.uri.pathSegments.last,
    sourceUri: 'content://teste/${file.uri.pathSegments.last}',
    mimeType: 'application/octet-stream',
    sizeBytes: file.lengthSync(),
    receivedAt: DateTime(2026, 5, 22, 10, 31),
  );
}
