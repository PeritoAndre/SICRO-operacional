import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/models/field_photo.dart';
import '../../domain/models/official_document.dart';
import '../../domain/models/occurrence.dart';
import 'sicrocampo_package_contract.dart';

class SicroCampoExportResult {
  const SicroCampoExportResult({
    required this.file,
    required this.fileName,
    required this.sizeBytes,
    required this.sha256,
    required this.entryCount,
    required this.hashCount,
    required this.photosTotal,
    required this.photosIncluded,
    required this.photosMissing,
    required this.officialDocumentsTotal,
    required this.officialDocumentsIncluded,
    required this.officialDocumentsMissing,
    required this.warnings,
    required this.generatedAt,
  });

  final File file;
  final String fileName;
  final int sizeBytes;
  final String sha256;
  final int entryCount;
  final int hashCount;
  final int photosTotal;
  final int photosIncluded;
  final int photosMissing;
  final int officialDocumentsTotal;
  final int officialDocumentsIncluded;
  final int officialDocumentsMissing;
  final List<String> warnings;
  final DateTime generatedAt;

  bool get hashesReady => hashCount > 0;
}

class SicroCampoExportService {
  SicroCampoExportService({
    Future<Directory> Function()? outputDirectoryProvider,
    DateTime Function()? clock,
  }) : _outputDirectoryProvider =
           outputDirectoryProvider ?? getApplicationDocumentsDirectory,
       _clock = clock ?? DateTime.now;

  final Future<Directory> Function() _outputDirectoryProvider;
  final DateTime Function() _clock;
  final JsonEncoder _encoder = const JsonEncoder.withIndent('  ');

  Future<SicroCampoExportResult> exportOccurrence(
    FieldOccurrence occurrence, {
    List<OfficialDocument> officialDocuments = const [],
  }) async {
    final generatedAt = _clock();
    final exportedOccurrence = occurrence.copyWith(
      status: OccurrenceStatus.exported,
      exportedAt: generatedAt,
    );
    final archive = Archive();
    final hashes = <String, String>{};
    final warnings = <String>[];
    final entries = <String>[];
    var photosIncluded = 0;
    var photosMissing = 0;
    var officialDocumentsIncluded = 0;
    var officialDocumentsMissing = 0;

    void addBytes(String path, List<int> bytes) {
      archive.addFile(ArchiveFile.bytes(path, bytes));
      hashes[path] = sha256.convert(bytes).toString();
      entries.add(path);
    }

    void addJson(String path, Object? data) {
      final json = '${_encoder.convert(data)}\n';
      addBytes(path, utf8.encode(json));
    }

    archive.addFile(
      ArchiveFile.directory(SicroCampoPackageContract.photosDirectory),
    );
    archive.addFile(
      ArchiveFile.directory(
        SicroCampoPackageContract.officialDocumentsDirectory,
      ),
    );

    final packagedPhotos = <Map<String, Object?>>[];
    for (final photo in exportedOccurrence.photos) {
      final file = File(photo.filePath);
      final entryPath =
          '${SicroCampoPackageContract.photosDirectory}'
          '${_safeName(photo.id)}${_extensionFor(photo.filePath)}';

      if (!await file.exists()) {
        photosMissing++;
        warnings.add('Foto nao encontrada no aparelho: ${photo.id}');
        packagedPhotos.add(_photoJson(photo, entryPath, available: false));
        continue;
      }

      final bytes = await file.readAsBytes();
      addBytes(entryPath, bytes);
      photosIncluded++;
      packagedPhotos.add(
        _photoJson(
          photo,
          entryPath,
          available: true,
          packagedSha256: hashes[entryPath],
        ),
      );
    }

    final packagedOfficialDocuments = <Map<String, Object?>>[];
    for (final document in officialDocuments) {
      final imagePath = document.imagePath.trim();
      final entryPath = imagePath.isEmpty
          ? ''
          : '${SicroCampoPackageContract.officialDocumentsDirectory}'
                '${_safeName(document.id)}${_extensionFor(imagePath)}';

      if (imagePath.isEmpty) {
        officialDocumentsMissing++;
        warnings.add('Oficio sem imagem vinculada: ${document.id}');
        packagedOfficialDocuments.add(
          _officialDocumentJson(document, entryPath, available: false),
        );
        continue;
      }

      final file = File(imagePath);
      if (!await file.exists()) {
        officialDocumentsMissing++;
        warnings.add('Imagem do oficio nao encontrada: ${document.id}');
        packagedOfficialDocuments.add(
          _officialDocumentJson(document, entryPath, available: false),
        );
        continue;
      }

      final bytes = await file.readAsBytes();
      addBytes(entryPath, bytes);
      officialDocumentsIncluded++;
      packagedOfficialDocuments.add(
        _officialDocumentJson(
          document,
          entryPath,
          available: true,
          packagedSha256: hashes[entryPath],
        ),
      );
    }

    addJson(
      SicroCampoPackageContract.metadata,
      exportedOccurrence.metadata.toJson(),
    );
    addJson(
      SicroCampoPackageContract.caseData,
      exportedOccurrence.caseData.toJson(),
    );
    addJson(
      SicroCampoPackageContract.location,
      exportedOccurrence.location.toJson(),
    );
    addJson(
      SicroCampoPackageContract.gpsTrack,
      exportedOccurrence.gpsTrack.map((reading) => reading.toJson()).toList(),
    );
    addJson(
      SicroCampoPackageContract.statistics,
      exportedOccurrence.operationalStatisticsToJson(),
    );
    addJson(
      SicroCampoPackageContract.timeline,
      exportedOccurrence.effectiveTimeline
          .map((event) => event.toJson())
          .toList(),
    );
    addJson(
      SicroCampoPackageContract.checklist,
      exportedOccurrence.checklist.map((item) => item.toJson()).toList(),
    );
    addJson(SicroCampoPackageContract.photos, packagedPhotos);
    addJson(
      SicroCampoPackageContract.vehicles,
      exportedOccurrence.vehicles.map((vehicle) => vehicle.toJson()).toList(),
    );
    addJson(
      SicroCampoPackageContract.victims,
      exportedOccurrence.victims.map((victim) => victim.toJson()).toList(),
    );
    addJson(
      SicroCampoPackageContract.traces,
      exportedOccurrence.traces.map((trace) => trace.toJson()).toList(),
    );
    addJson(
      SicroCampoPackageContract.measurements,
      exportedOccurrence.measurements
          .map((measurement) => measurement.toJson())
          .toList(),
    );
    addJson(
      SicroCampoPackageContract.notes,
      exportedOccurrence.notes.map((note) => note.toJson()).toList(),
    );
    addJson(
      SicroCampoPackageContract.officialDocuments,
      packagedOfficialDocuments,
    );
    addJson(SicroCampoPackageContract.operational, {
      ...exportedOccurrence.operationalProgress.toJson(),
      'sessao': exportedOccurrence.operationalSessionToJson(),
    });

    final finalEntries = [
      SicroCampoPackageContract.manifest,
      ...entries,
      SicroCampoPackageContract.hashes,
    ];
    addJson(
      SicroCampoPackageContract.manifest,
      _manifestJson(
        exportedOccurrence,
        generatedAt,
        finalEntries,
        warnings,
        officialDocuments.length,
      ),
    );
    final hashCount = hashes.length;
    addJson(SicroCampoPackageContract.hashes, _hashesJson(hashes));

    final zipBytes = ZipEncoder().encodeBytes(archive);
    final outputDir = await _exportsDirectory();
    final fileName = _exportFileName(exportedOccurrence, generatedAt);
    final outputFile = File(
      '${outputDir.path}${Platform.pathSeparator}$fileName',
    );
    await outputFile.writeAsBytes(zipBytes, flush: true);

    return SicroCampoExportResult(
      file: outputFile,
      fileName: fileName,
      sizeBytes: zipBytes.length,
      sha256: sha256.convert(zipBytes).toString(),
      entryCount: finalEntries.length,
      hashCount: hashCount,
      photosTotal: exportedOccurrence.photos.length,
      photosIncluded: photosIncluded,
      photosMissing: photosMissing,
      officialDocumentsTotal: officialDocuments.length,
      officialDocumentsIncluded: officialDocumentsIncluded,
      officialDocumentsMissing: officialDocumentsMissing,
      warnings: warnings,
      generatedAt: generatedAt,
    );
  }

  Future<void> deleteExportedPackage(String? fileName) async {
    final safeFileName = fileName?.trim();
    if (safeFileName == null || safeFileName.isEmpty) {
      return;
    }

    final outputDir = await _exportsDirectory(create: false);
    final file = File(
      '${outputDir.path}${Platform.pathSeparator}$safeFileName',
    );
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<Directory> _exportsDirectory({bool create = true}) async {
    final base = await _outputDirectoryProvider();
    final dir = Directory(
      '${base.path}${Platform.pathSeparator}sicro_operacional'
      '${Platform.pathSeparator}exports',
    );
    if (create && !await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Map<String, Object?> _manifestJson(
    FieldOccurrence occurrence,
    DateTime generatedAt,
    List<String> entries,
    List<String> warnings,
    int officialDocumentsCount,
  ) {
    return {
      'formato': SicroCampoPackageContract.format,
      'formatos_compativeis': [
        SicroCampoPackageContract.format,
        SicroCampoPackageContract.legacyFormat,
      ],
      'extensoes_compativeis': SicroCampoPackageContract.compatibleExtensions,
      'versao': SicroCampoPackageContract.version,
      'versoes_compativeis': SicroCampoPackageContract.compatibleVersions,
      'gerado_em': generatedAt.toIso8601String(),
      'ocorrencia': {
        'id': occurrence.id,
        'status': occurrence.status.code,
        'status_operacional': occurrence.operationalSessionStatusCode,
        'iniciado_em': occurrence.effectiveStartedAt.toIso8601String(),
        'concluido_em': occurrence.finishedAt?.toIso8601String(),
        'duracao_segundos': occurrence.durationSeconds,
        'tipo_pericia': occurrence.metadata.type.code,
        'natureza': occurrence.metadata.primaryNatureCode,
        'resultado': occurrence.metadata.result.code,
        'criado_em': occurrence.createdAt.toIso8601String(),
        'atualizado_em': occurrence.updatedAt.toIso8601String(),
      },
      'contagens': {
        'checklist': occurrence.checklist.length,
        'timeline': occurrence.effectiveTimeline.length,
        'fotos': occurrence.photos.length,
        'leituras_gps': occurrence.gpsReadingsCount,
        'veiculos': occurrence.vehicles.length,
        'vitimas': occurrence.victims.length,
        'vestigios': occurrence.traces.length,
        'medicoes': occurrence.measurements.length,
        'observacoes': occurrence.notes.length,
        'oficios': officialDocumentsCount,
      },
      'arquivos': entries,
      'avisos': warnings,
    };
  }

  Map<String, Object?> _hashesJson(Map<String, String> hashes) {
    final files = hashes.entries
        .map((entry) => {'caminho': entry.key, 'sha256': entry.value})
        .toList();
    files.sort((a, b) => a['caminho']!.compareTo(b['caminho']!));
    return {
      'algoritmo': 'SHA-256',
      'arquivos': files,
      'observacao':
          'hashes.json nao inclui o proprio arquivo para evitar referencia circular.',
    };
  }

  Map<String, Object?> _photoJson(
    FieldPhoto photo,
    String entryPath, {
    required bool available,
    String? packagedSha256,
  }) {
    return {
      'id': photo.id,
      'arquivo': entryPath,
      'categoria': photo.category.code,
      'capturada_em': photo.capturedAt.toIso8601String(),
      'legenda': photo.caption,
      'sha256': packagedSha256 ?? photo.sha256,
      'sha256_original': photo.sha256,
      'entidade_vinculada': photo.linkedEntityId,
      'arquivo_disponivel': available,
    };
  }

  Map<String, Object?> _officialDocumentJson(
    OfficialDocument document,
    String entryPath, {
    required bool available,
    String? packagedSha256,
  }) {
    return {
      ...document.toJson(),
      'imagem_arquivo_original': document.imagePath,
      'imagem_arquivo': entryPath,
      'imagem_disponivel': available,
      'imagem_sha256': packagedSha256 ?? document.imageSha256,
      'imagem_sha256_original': document.imageSha256,
    };
  }

  String _exportFileName(FieldOccurrence occurrence, DateTime generatedAt) {
    final caseData = occurrence.caseData;
    final base = caseData.bo.trim().isNotEmpty
        ? 'BO_${caseData.bo}'
        : caseData.protocol.trim().isNotEmpty
        ? 'PROTOCOLO_${caseData.protocol}'
        : occurrence.id;
    return 'SICRO_OPERACIONAL_${_safeName(base)}_${_timestamp(generatedAt)}'
        '${SicroCampoPackageContract.extension}';
  }

  String _timestamp(DateTime value) {
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${local.year}${two(local.month)}${two(local.day)}_'
        '${two(local.hour)}${two(local.minute)}${two(local.second)}';
  }

  String _safeName(String value) {
    final safe = value
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return safe.isEmpty ? 'ocorrencia' : safe;
  }

  String _extensionFor(String path) {
    final fileName = path.split(RegExp(r'[\\/]')).last;
    final dot = fileName.lastIndexOf('.');
    if (dot == -1 || dot == fileName.length - 1) {
      return '.jpg';
    }
    final extension = fileName.substring(dot).toLowerCase();
    if (extension.length > 8 || extension.contains(RegExp(r'[^a-z0-9.]'))) {
      return '.jpg';
    }
    return extension;
  }
}
