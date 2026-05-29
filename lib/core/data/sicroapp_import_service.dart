import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

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
import '../services/external_package_channel.dart';
import 'occurrence_repository.dart';
import 'photo_file_storage.dart';
import 'sicrocampo_package_contract.dart';

class SicroAppPackageSummary {
  const SicroAppPackageSummary({
    required this.format,
    required this.packageVersion,
    required this.generatedAt,
    required this.occurrenceId,
    required this.status,
    required this.caseType,
    required this.nature,
    required this.result,
    required this.bo,
    required this.protocol,
    required this.municipality,
    required this.district,
    required this.street,
    required this.photosCount,
    required this.tracesCount,
    required this.vehiclesCount,
    required this.victimsCount,
    required this.measurementsCount,
    required this.notesCount,
    required this.gpsReadingsCount,
    required this.durationSeconds,
    required this.hashesPresent,
  });

  final String format;
  final String packageVersion;
  final DateTime? generatedAt;
  final String occurrenceId;
  final String status;
  final String caseType;
  final String nature;
  final String result;
  final String bo;
  final String protocol;
  final String municipality;
  final String district;
  final String street;
  final int photosCount;
  final int tracesCount;
  final int vehiclesCount;
  final int victimsCount;
  final int measurementsCount;
  final int notesCount;
  final int gpsReadingsCount;
  final int? durationSeconds;
  final bool hashesPresent;

  String get locationLabel {
    final parts = [
      street,
      district,
      municipality,
    ].where((part) => part.trim().isNotEmpty).toList();
    return parts.isEmpty ? 'Local nao informado' : parts.join(' - ');
  }
}

class SicroAppPackageImportResult {
  const SicroAppPackageImportResult({
    required this.packageFile,
    required this.validZip,
    required this.validManifest,
    required this.errors,
    required this.warnings,
    this.summary,
  });

  final ExternalPackageFile packageFile;
  final bool validZip;
  final bool validManifest;
  final List<String> errors;
  final List<String> warnings;
  final SicroAppPackageSummary? summary;

  bool get isValid => errors.isEmpty && validZip && validManifest;
}

class SicroAppFullImportResult {
  const SicroAppFullImportResult({
    required this.errors,
    required this.warnings,
    this.occurrence,
  });

  final FieldOccurrence? occurrence;
  final List<String> errors;
  final List<String> warnings;

  bool get imported => occurrence != null && errors.isEmpty;
}

class SicroAppImportService {
  SicroAppImportService({PhotoFileStorage? photoStorage})
    : _photoStorage = photoStorage ?? PhotoFileStorage();

  final PhotoFileStorage _photoStorage;

  Future<SicroAppPackageImportResult> validatePackage(
    ExternalPackageFile packageFile,
  ) async {
    final errors = <String>[];
    final warnings = <String>[];

    if (!packageFile.ok) {
      errors.add(packageFile.nativeError ?? 'Falha ao receber o pacote.');
      return SicroAppPackageImportResult(
        packageFile: packageFile,
        validZip: false,
        validManifest: false,
        errors: errors,
        warnings: warnings,
      );
    }

    final file = File(packageFile.filePath);
    if (!await file.exists()) {
      errors.add('A copia interna do pacote nao foi encontrada.');
      return SicroAppPackageImportResult(
        packageFile: packageFile,
        validZip: false,
        validManifest: false,
        errors: errors,
        warnings: warnings,
      );
    }

    Archive archive;
    try {
      archive = await _decodeArchive(file);
    } catch (_) {
      errors.add('O arquivo recebido nao e um ZIP valido.');
      return SicroAppPackageImportResult(
        packageFile: packageFile,
        validZip: false,
        validManifest: false,
        errors: errors,
        warnings: warnings,
      );
    }

    final manifest = _jsonMap(archive, SicroCampoPackageContract.manifest);
    if (manifest == null) {
      errors.add('manifest.json nao encontrado ou invalido.');
      return SicroAppPackageImportResult(
        packageFile: packageFile,
        validZip: true,
        validManifest: false,
        errors: errors,
        warnings: warnings,
      );
    }

    final format = _string(manifest['formato']);
    if (format != SicroCampoPackageContract.format &&
        format != SicroCampoPackageContract.legacyFormat) {
      errors.add(
        'Formato nao reconhecido: ${format.isEmpty ? 'vazio' : format}.',
      );
    }
    final version = _string(manifest['versao']);
    if (version.isEmpty) {
      warnings.add('Versao do pacote nao informada no manifest.');
    } else if (!SicroCampoPackageContract.compatibleVersions.contains(
      version,
    )) {
      warnings.add(
        'Versao do pacote nao homologada neste app: $version. '
        'A importacao sera tentada em modo tolerante.',
      );
    }

    _validateHashes(archive, errors: errors, warnings: warnings);

    final caseData = _jsonMap(archive, SicroCampoPackageContract.caseData);
    if (caseData == null) {
      warnings.add('caso.json nao encontrado; resumo do caso limitado.');
    }

    final metadata = _jsonMap(archive, SicroCampoPackageContract.metadata);
    if (metadata == null) {
      warnings.add('metadados.json nao encontrado; classificacao limitada.');
    }

    final occurrence = _map(manifest['ocorrencia']);
    final counts = _map(manifest['contagens']);
    final statistics = _jsonMap(archive, SicroCampoPackageContract.statistics);
    final typeCode = _firstText([
      metadata?['tipo_pericia'],
      occurrence['tipo_pericia'],
    ]);
    final natureCode = _firstText([
      metadata?['natureza'],
      occurrence['natureza'],
    ]);
    final resultCode = _firstText([
      metadata?['resultado'],
      occurrence['resultado'],
    ]);
    final type = ForensicCaseType.fromCode(typeCode);

    final summary = SicroAppPackageSummary(
      format: format,
      packageVersion: version,
      generatedAt: _date(manifest['gerado_em']),
      occurrenceId: _string(occurrence['id']),
      status: _string(occurrence['status']),
      caseType: type.label,
      nature: _natureLabel(type, natureCode),
      result: OccurrenceResult.fromCode(resultCode).label,
      bo: _string(caseData?['bo']),
      protocol: _string(caseData?['protocolo']),
      municipality: _string(caseData?['municipio']),
      district: _string(caseData?['bairro']),
      street: _string(caseData?['logradouro']),
      photosCount: _count(
        counts['fotos'],
        archive,
        SicroCampoPackageContract.photos,
      ),
      tracesCount: _count(
        counts['vestigios'],
        archive,
        SicroCampoPackageContract.traces,
      ),
      vehiclesCount: _count(
        counts['veiculos'],
        archive,
        SicroCampoPackageContract.vehicles,
      ),
      victimsCount: _count(
        counts['vitimas'],
        archive,
        SicroCampoPackageContract.victims,
      ),
      measurementsCount: _count(
        counts['medicoes'],
        archive,
        SicroCampoPackageContract.measurements,
      ),
      notesCount: _count(
        counts['observacoes'],
        archive,
        SicroCampoPackageContract.notes,
      ),
      gpsReadingsCount: _count(
        counts['leituras_gps'],
        archive,
        SicroCampoPackageContract.gpsTrack,
      ),
      durationSeconds:
          _nullableInt(occurrence['duracao_segundos']) ??
          _nullableInt(statistics?['duracao_segundos']),
      hashesPresent: archive.findFile(SicroCampoPackageContract.hashes) != null,
    );

    return SicroAppPackageImportResult(
      packageFile: packageFile,
      validZip: true,
      validManifest: errors.isEmpty,
      errors: errors,
      warnings: warnings,
      summary: summary,
    );
  }

  Future<SicroAppFullImportResult> importPackage({
    required SicroAppPackageImportResult validation,
    required OccurrenceRepository repository,
  }) async {
    final errors = [...validation.errors];
    final warnings = [...validation.warnings];
    if (!validation.validZip ||
        !validation.validManifest ||
        errors.isNotEmpty) {
      return SicroAppFullImportResult(errors: errors, warnings: warnings);
    }

    final file = File(validation.packageFile.filePath);
    if (!await file.exists()) {
      return SicroAppFullImportResult(
        errors: ['A copia interna do pacote nao foi encontrada.'],
        warnings: warnings,
      );
    }

    late final Archive archive;
    try {
      archive = await _decodeArchive(file);
    } catch (_) {
      return SicroAppFullImportResult(
        errors: ['O arquivo recebido nao e um ZIP valido.'],
        warnings: warnings,
      );
    }

    _validateHashes(archive, errors: errors, warnings: warnings);
    if (errors.isNotEmpty) {
      return SicroAppFullImportResult(errors: errors, warnings: warnings);
    }

    final manifest = _jsonMap(archive, SicroCampoPackageContract.manifest);
    if (manifest == null) {
      return SicroAppFullImportResult(
        errors: ['manifest.json nao encontrado ou invalido.'],
        warnings: warnings,
      );
    }

    final now = DateTime.now();
    final occurrenceId = 'occ_import_${now.microsecondsSinceEpoch}';
    final occurrenceInfo = _map(manifest['ocorrencia']);
    final operational =
        _jsonMap(archive, SicroCampoPackageContract.operational) ?? const {};
    final metadata = ForensicCaseMetadata.fromJson(
      _metadataForImport(
        _jsonMap(archive, SicroCampoPackageContract.metadata),
        occurrenceInfo,
      ),
    );
    final photos = await _importPhotos(
      archive: archive,
      occurrenceId: occurrenceId,
      warnings: warnings,
    );

    final occurrence = FieldOccurrence(
      id: occurrenceId,
      status: OccurrenceStatus.fromCode(occurrenceInfo['status']),
      createdAt:
          _date(occurrenceInfo['criado_em']) ??
          validation.summary?.generatedAt ??
          now,
      updatedAt: now,
      startedAt:
          _date(occurrenceInfo['iniciado_em']) ??
          _date(occurrenceInfo['criado_em']) ??
          validation.summary?.generatedAt,
      finishedAt: _date(occurrenceInfo['concluido_em']),
      exportedAt: validation.summary?.generatedAt,
      exportedPackageName: validation.packageFile.originalName,
      exportedPackageSha256: await _fileSha256(file),
      notApplicableItems: _stringList(operational['nao_aplicavel']),
      metadata: metadata,
      caseData: CaseData.fromJson(
        _jsonMap(archive, SicroCampoPackageContract.caseData) ?? const {},
      ),
      location: LocationRecord.fromJson(
        _jsonMap(archive, SicroCampoPackageContract.location) ?? const {},
      ),
      gpsTrack: _jsonList(
        archive,
        SicroCampoPackageContract.gpsTrack,
      ).map((item) => LocationRecord.fromJson(_map(item))).toList(),
      checklist: _importChecklist(archive, metadata),
      photos: photos,
      vehicles: _jsonList(
        archive,
        SicroCampoPackageContract.vehicles,
      ).map((item) => VehicleRecord.fromJson(_map(item))).toList(),
      victims: _jsonList(
        archive,
        SicroCampoPackageContract.victims,
      ).map((item) => VictimRecord.fromJson(_map(item))).toList(),
      traces: _jsonList(
        archive,
        SicroCampoPackageContract.traces,
      ).map((item) => TraceRecord.fromJson(_map(item))).toList(),
      measurements: _jsonList(
        archive,
        SicroCampoPackageContract.measurements,
      ).map((item) => MeasurementRecord.fromJson(_map(item))).toList(),
      notes: _jsonList(
        archive,
        SicroCampoPackageContract.notes,
      ).map((item) => FieldNote.fromJson(_map(item))).toList(),
      timeline: _jsonList(
        archive,
        SicroCampoPackageContract.timeline,
      ).map((item) => OccurrenceTimelineEvent.fromJson(_map(item))).toList(),
    );

    final imported = await repository.importOccurrence(occurrence);
    return SicroAppFullImportResult(
      occurrence: imported,
      errors: const [],
      warnings: warnings,
    );
  }

  Future<Archive> _decodeArchive(File file) async {
    return ZipDecoder().decodeBytes(await file.readAsBytes());
  }

  Future<List<FieldPhoto>> _importPhotos({
    required Archive archive,
    required String occurrenceId,
    required List<String> warnings,
  }) async {
    final photosJson = _jsonList(archive, SicroCampoPackageContract.photos);
    final imported = <FieldPhoto>[];
    for (final item in photosJson) {
      final photoMap = _map(item);
      final originalPhoto = FieldPhoto.fromJson(photoMap);
      final entryPath = _string(photoMap['arquivo']);
      if (entryPath.isEmpty) {
        warnings.add('Foto sem caminho no pacote: ${originalPhoto.id}.');
        continue;
      }
      if (photoMap['arquivo_disponivel'] == false) {
        warnings.add('Foto indisponivel no pacote: ${originalPhoto.id}.');
        continue;
      }
      final archiveFile = archive.findFile(entryPath);
      final bytes = archiveFile?.readBytes();
      if (bytes == null) {
        warnings.add('Arquivo de foto ausente no pacote: $entryPath.');
        continue;
      }
      imported.add(
        await _photoStorage.saveImportedPhoto(
          occurrenceId: occurrenceId,
          photo: originalPhoto,
          bytes: bytes,
          sourcePath: entryPath,
        ),
      );
    }
    return imported;
  }

  List<ChecklistItem> _importChecklist(
    Archive archive,
    ForensicCaseMetadata metadata,
  ) {
    final checklist = _jsonList(
      archive,
      SicroCampoPackageContract.checklist,
    ).map((item) => ChecklistItem.fromJson(_map(item))).toList();
    return checklist.isEmpty ? defaultChecklistFor(metadata) : checklist;
  }

  Map<String, Object?> _metadataForImport(
    Map<String, Object?>? metadata,
    Map<String, Object?> occurrenceInfo,
  ) {
    if (metadata != null && metadata.isNotEmpty) {
      return metadata;
    }
    return {
      'tipo_pericia': occurrenceInfo['tipo_pericia'],
      'natureza': occurrenceInfo['natureza'],
      'resultado': occurrenceInfo['resultado'],
    };
  }

  void _validateHashes(
    Archive archive, {
    required List<String> errors,
    required List<String> warnings,
  }) {
    final hashes = _jsonMap(archive, SicroCampoPackageContract.hashes);
    if (hashes == null) {
      warnings.add('hashes.json nao encontrado; integridade nao verificada.');
      return;
    }
    final files = _list(hashes['arquivos']);
    if (files.isEmpty) {
      warnings.add('hashes.json nao contem arquivos para verificacao.');
      return;
    }
    for (final item in files) {
      final entry = _map(item);
      final path = _string(entry['caminho']);
      final expected = _string(entry['sha256']).toLowerCase();
      if (path.isEmpty || expected.isEmpty) {
        warnings.add('Entrada de hash incompleta ignorada.');
        continue;
      }
      final archiveFile = archive.findFile(path);
      final bytes = archiveFile?.readBytes();
      if (bytes == null) {
        errors.add('Arquivo declarado em hashes.json ausente: $path.');
        continue;
      }
      final actual = sha256.convert(bytes).toString().toLowerCase();
      if (actual != expected) {
        errors.add('Hash divergente para $path.');
      }
    }
  }

  Map<String, Object?>? _jsonMap(Archive archive, String path) {
    final file = archive.findFile(path);
    final bytes = file?.readBytes();
    if (bytes == null) {
      return null;
    }
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  List<Object?> _jsonList(Archive archive, String path) {
    final file = archive.findFile(path);
    final bytes = file?.readBytes();
    if (bytes == null) {
      return const [];
    }
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is List) {
        return decoded;
      }
    } catch (_) {
      return const [];
    }
    return const [];
  }

  int _count(Object? rawCount, Archive archive, String listPath) {
    final count = _nullableInt(rawCount);
    if (count != null) {
      return count;
    }
    return _jsonList(archive, listPath).length;
  }
}

String _natureLabel(ForensicCaseType type, String code) {
  return switch (type) {
    ForensicCaseType.traffic =>
      TrafficNature.fromCode(code)?.label ?? _fallbackLabel(code),
    ForensicCaseType.violentDeath =>
      ViolentDeathNature.fromCode(code)?.label ?? _fallbackLabel(code),
    ForensicCaseType.property =>
      PropertyNature.fromCode(code)?.label ?? _fallbackLabel(code),
    ForensicCaseType.environmental =>
      EnvironmentalNature.fromCode(code)?.label ?? _fallbackLabel(code),
    ForensicCaseType.ballistics =>
      BallisticsNature.fromCode(code)?.label ?? _fallbackLabel(code),
    ForensicCaseType.audioImage =>
      AudioImageNature.fromCode(code)?.label ?? _fallbackLabel(code),
    ForensicCaseType.papiloscopy =>
      PapiloscopyNature.fromCode(code)?.label ?? _fallbackLabel(code),
  };
}

String _fallbackLabel(String code) {
  if (code.trim().isEmpty) {
    return 'Nao informado';
  }
  return code.replaceAll('_', ' ');
}

Map<String, Object?> _map(Object? value) {
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  return const {};
}

List<Object?> _list(Object? value) => value is List ? value : const [];

String _firstText(List<Object?> values) {
  for (final value in values) {
    final text = _string(value);
    if (text.isNotEmpty) {
      return text;
    }
  }
  return '';
}

String _string(Object? value) => value is String ? value : '';

List<String> _stringList(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value.whereType<String>().toList();
}

int? _nullableInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is double) {
    return value.round();
  }
  return null;
}

DateTime? _date(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}

Future<String> _fileSha256(File file) async {
  final digest = await sha256.bind(file.openRead()).first;
  return digest.toString();
}
