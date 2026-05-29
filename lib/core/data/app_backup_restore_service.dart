import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/models/app_settings.dart';
import '../../domain/models/duty_shift.dart';
import '../../domain/models/official_document.dart';
import '../../domain/models/occurrence.dart';

class AppBackupSummary {
  const AppBackupSummary({
    required this.format,
    required this.version,
    required this.generatedAt,
    required this.appName,
    required this.appVersion,
    required this.operatorName,
    required this.occurrenceCount,
    required this.officialDocumentCount,
    required this.dutyShiftCount,
    required this.mediaCount,
    required this.reportCount,
    required this.hashesPresent,
  });

  final String format;
  final String version;
  final DateTime? generatedAt;
  final String appName;
  final String appVersion;
  final String operatorName;
  final int occurrenceCount;
  final int officialDocumentCount;
  final int dutyShiftCount;
  final int mediaCount;
  final int reportCount;
  final bool hashesPresent;
}

class AppBackupValidationResult {
  const AppBackupValidationResult({
    required this.file,
    required this.fileName,
    required this.validZip,
    required this.validManifest,
    required this.errors,
    required this.warnings,
    this.summary,
  });

  final File file;
  final String fileName;
  final bool validZip;
  final bool validManifest;
  final List<String> errors;
  final List<String> warnings;
  final AppBackupSummary? summary;

  bool get isValid => errors.isEmpty && validZip && validManifest;
}

class AppBackupRestoreResult {
  const AppBackupRestoreResult({
    required this.settings,
    required this.occurrences,
    required this.officialDocuments,
    required this.dutyShifts,
    required this.mediaRestored,
    required this.mediaMissing,
    required this.reportsRestored,
    required this.warnings,
  });

  final AppSettings settings;
  final List<FieldOccurrence> occurrences;
  final List<OfficialDocument> officialDocuments;
  final List<DutyShift> dutyShifts;
  final int mediaRestored;
  final int mediaMissing;
  final int reportsRestored;
  final List<String> warnings;
}

class AppBackupRestoreService {
  AppBackupRestoreService({
    Future<Directory> Function()? directoryProvider,
    DateTime Function()? clock,
  }) : _directoryProvider =
           directoryProvider ?? getApplicationDocumentsDirectory,
       _clock = clock ?? DateTime.now;

  final Future<Directory> Function() _directoryProvider;
  final DateTime Function() _clock;

  Future<AppBackupValidationResult> validate(
    File file, {
    String? fileName,
  }) async {
    final errors = <String>[];
    final warnings = <String>[];
    final displayName = fileName ?? file.uri.pathSegments.last;

    if (!await file.exists()) {
      return AppBackupValidationResult(
        file: file,
        fileName: displayName,
        validZip: false,
        validManifest: false,
        errors: const ['Arquivo de backup nao encontrado.'],
        warnings: const [],
      );
    }

    Archive archive;
    try {
      archive = await _decodeArchive(file);
    } catch (_) {
      return AppBackupValidationResult(
        file: file,
        fileName: displayName,
        validZip: false,
        validManifest: false,
        errors: const ['O arquivo selecionado nao e um ZIP valido.'],
        warnings: const [],
      );
    }

    final manifest = _jsonMap(archive, 'manifest.json');
    if (manifest == null) {
      return AppBackupValidationResult(
        file: file,
        fileName: displayName,
        validZip: true,
        validManifest: false,
        errors: const ['manifest.json nao encontrado ou invalido.'],
        warnings: warnings,
      );
    }

    final format = _string(manifest['formato']);
    if (format != 'sicro_operacional_backup') {
      errors.add(
        'Formato nao reconhecido: ${format.isEmpty ? 'vazio' : format}.',
      );
    }
    final version = _string(manifest['versao']);
    if (version.isEmpty) {
      warnings.add('Versao do backup nao informada no manifest.');
    } else if (version != '0.1') {
      warnings.add(
        'Versao do backup nao homologada nesta versao do app: $version.',
      );
    }

    _validateHashes(archive, errors: errors, warnings: warnings);

    final counts = _map(manifest['contagens']);
    final profile = _map(manifest['perfil_perito']);
    final summary = AppBackupSummary(
      format: format,
      version: version,
      generatedAt: _date(manifest['gerado_em']),
      appName: _string(manifest['app_nome']),
      appVersion: _string(manifest['app_versao']),
      operatorName: _string(profile['nome']),
      occurrenceCount: _count(
        counts['ocorrencias'],
        archive,
        'ocorrencias.json',
      ),
      officialDocumentCount: _count(counts['oficios'], archive, 'oficios.json'),
      dutyShiftCount: _count(counts['plantoes'], archive, 'plantoes.json'),
      mediaCount:
          _nullableInt(counts['midias_total']) ??
          _jsonList(archive, 'media_index.json').length,
      reportCount:
          _nullableInt(counts['relatorios_pdf']) ??
          _jsonList(archive, 'relatorios_index.json').length,
      hashesPresent: archive.findFile('hashes.json') != null,
    );

    return AppBackupValidationResult(
      file: file,
      fileName: displayName,
      validZip: true,
      validManifest: errors.isEmpty,
      errors: errors,
      warnings: warnings,
      summary: summary,
    );
  }

  Future<AppBackupRestoreResult> restore(
    AppBackupValidationResult validation,
  ) async {
    final warnings = [...validation.warnings];
    if (!validation.isValid) {
      throw StateError(validation.errors.join('\n'));
    }

    final archive = await _decodeArchive(validation.file);
    final errors = <String>[];
    _validateHashes(archive, errors: errors, warnings: warnings);
    if (errors.isNotEmpty) {
      throw StateError(errors.join('\n'));
    }

    final settings = AppSettings.fromJson(
      _jsonMap(archive, 'configuracoes.json') ?? const {},
    ).copyWith(onboardingCompleted: true);

    final restoredMedia = await _restoreMedia(archive, warnings);
    final occurrences = _restoreOccurrences(archive, restoredMedia.photoPaths);
    final officialDocuments = _restoreOfficialDocuments(
      archive,
      restoredMedia.officialDocumentImagePaths,
    );
    final dutyShifts = _jsonList(archive, 'plantoes.json')
        .map((item) => DutyShift.fromJson(_map(item)))
        .where((shift) => shift.id.isNotEmpty)
        .toList();

    return AppBackupRestoreResult(
      settings: settings.copyWith(
        backup: settings.backup.copyWith(
          lastBackupAt: validation.summary?.generatedAt ?? _clock(),
          lastBackupFileName: validation.fileName,
          lastBackupSha256: await _fileSha256(validation.file),
          lastBackupSizeBytes: await validation.file.length(),
          lastBackupOccurrenceCount: occurrences.length,
          lastBackupOfficialDocumentCount: officialDocuments.length,
          lastBackupDutyShiftCount: dutyShifts.length,
          lastBackupPhotoCount: occurrences.fold<int>(
            0,
            (total, occurrence) => total + occurrence.photos.length,
          ),
        ),
      ),
      occurrences: occurrences,
      officialDocuments: officialDocuments,
      dutyShifts: dutyShifts,
      mediaRestored: restoredMedia.mediaRestored,
      mediaMissing: restoredMedia.mediaMissing,
      reportsRestored: restoredMedia.reportsRestored,
      warnings: warnings,
    );
  }

  Future<void> cleanupReplacedLocalFiles({
    required List<FieldOccurrence> oldOccurrences,
    required List<OfficialDocument> oldOfficialDocuments,
    required AppBackupRestoreResult restored,
  }) async {
    final restoredPaths = <String>{
      for (final occurrence in restored.occurrences)
        for (final photo in occurrence.photos)
          if (photo.filePath.trim().isNotEmpty) photo.filePath,
      for (final document in restored.officialDocuments)
        if (document.imagePath.trim().isNotEmpty) document.imagePath,
    };
    final oldPaths = <String>{
      for (final occurrence in oldOccurrences)
        for (final photo in occurrence.photos)
          if (photo.filePath.trim().isNotEmpty) photo.filePath,
      for (final document in oldOfficialDocuments)
        if (document.imagePath.trim().isNotEmpty) document.imagePath,
    };

    for (final path in oldPaths) {
      if (restoredPaths.contains(path)) {
        continue;
      }
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  List<FieldOccurrence> _restoreOccurrences(
    Archive archive,
    Map<String, String> photoPaths,
  ) {
    return _jsonList(archive, 'ocorrencias.json')
        .map((item) {
          final occurrenceMap = _deepMap(item);
          final occurrenceId = _string(occurrenceMap['id']);
          final photos = _list(occurrenceMap['fotos']).map((photo) {
            final photoMap = _deepMap(photo);
            final photoId = _string(photoMap['id']);
            final restoredPath =
                photoPaths[_mediaKey('ocorrencias', occurrenceId, photoId)];
            if (restoredPath != null) {
              photoMap['arquivo'] = restoredPath;
            }
            return photoMap;
          }).toList();
          occurrenceMap['fotos'] = photos;
          return FieldOccurrence.fromJson(occurrenceMap);
        })
        .where((occurrence) => occurrence.id.isNotEmpty)
        .toList();
  }

  List<OfficialDocument> _restoreOfficialDocuments(
    Archive archive,
    Map<String, String> imagePaths,
  ) {
    return _jsonList(archive, 'oficios.json')
        .map((item) {
          final documentMap = _deepMap(item);
          final documentId = _string(documentMap['id']);
          final restoredPath =
              imagePaths[_mediaKey('oficios', documentId, documentId)];
          if (restoredPath != null) {
            documentMap['imagem_arquivo'] = restoredPath;
          }
          return OfficialDocument.fromJson(documentMap);
        })
        .where((document) => document.id.isNotEmpty)
        .toList();
  }

  Future<_RestoredMedia> _restoreMedia(
    Archive archive,
    List<String> warnings,
  ) async {
    final base = await _directoryProvider();
    final photoPaths = <String, String>{};
    final officialDocumentImagePaths = <String, String>{};
    var mediaRestored = 0;
    var mediaMissing = 0;

    for (final item in _jsonList(archive, 'media_index.json')) {
      final media = _map(item);
      final module = _string(media['modulo_origem']);
      final ownerId = _string(media['dono_id']);
      final mediaId = _string(media['id']);
      final entryPath = _string(media['arquivo_backup']);
      if (entryPath.isEmpty || media['arquivo_disponivel'] == false) {
        mediaMissing++;
        continue;
      }
      final archiveFile = archive.findFile(entryPath);
      final bytes = archiveFile?.readBytes();
      if (bytes == null) {
        mediaMissing++;
        warnings.add('Midia ausente no backup: $entryPath.');
        continue;
      }

      final destination = _mediaDestination(
        base: base,
        module: module,
        ownerId: ownerId,
        mediaId: mediaId,
        entryPath: entryPath,
      );
      if (!await destination.parent.exists()) {
        await destination.parent.create(recursive: true);
      }
      await destination.writeAsBytes(bytes, flush: true);
      final key = _mediaKey(module, ownerId, mediaId);
      if (module == 'ocorrencias') {
        photoPaths[key] = destination.path;
      } else if (module == 'oficios') {
        officialDocumentImagePaths[key] = destination.path;
      }
      mediaRestored++;
    }

    var reportsRestored = 0;
    for (final item in _jsonList(archive, 'relatorios_index.json')) {
      final report = _map(item);
      final entryPath = _string(report['arquivo_backup']);
      if (entryPath.isEmpty) {
        continue;
      }
      final archiveFile = archive.findFile(entryPath);
      final bytes = archiveFile?.readBytes();
      if (bytes == null) {
        warnings.add('Relatorio ausente no backup: $entryPath.');
        continue;
      }
      final destination = File(
        '${base.path}${Platform.pathSeparator}sicro_operacional'
        '${Platform.pathSeparator}reports'
        '${Platform.pathSeparator}${_safeName(entryPath.split('/').last)}',
      );
      if (!await destination.parent.exists()) {
        await destination.parent.create(recursive: true);
      }
      await destination.writeAsBytes(bytes, flush: true);
      reportsRestored++;
    }

    return _RestoredMedia(
      photoPaths: photoPaths,
      officialDocumentImagePaths: officialDocumentImagePaths,
      mediaRestored: mediaRestored,
      mediaMissing: mediaMissing,
      reportsRestored: reportsRestored,
    );
  }

  File _mediaDestination({
    required Directory base,
    required String module,
    required String ownerId,
    required String mediaId,
    required String entryPath,
  }) {
    final extension = _extensionFor(entryPath);
    if (module == 'oficios') {
      return File(
        '${base.path}${Platform.pathSeparator}sicro_campo'
        '${Platform.pathSeparator}oficios'
        '${Platform.pathSeparator}${_safeName(mediaId)}$extension',
      );
    }
    return File(
      '${base.path}${Platform.pathSeparator}sicro_campo'
      '${Platform.pathSeparator}photos'
      '${Platform.pathSeparator}${_safeName(ownerId)}'
      '${Platform.pathSeparator}${_safeName(mediaId)}$extension',
    );
  }

  void _validateHashes(
    Archive archive, {
    required List<String> errors,
    required List<String> warnings,
  }) {
    final hashes = _jsonMap(archive, 'hashes.json');
    if (hashes == null) {
      warnings.add('hashes.json nao encontrado; integridade nao verificada.');
      return;
    }
    for (final item in _list(hashes['arquivos'])) {
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

  Future<Archive> _decodeArchive(File file) async {
    return ZipDecoder().decodeBytes(await file.readAsBytes());
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
    return _nullableInt(rawCount) ?? _jsonList(archive, listPath).length;
  }
}

class _RestoredMedia {
  const _RestoredMedia({
    required this.photoPaths,
    required this.officialDocumentImagePaths,
    required this.mediaRestored,
    required this.mediaMissing,
    required this.reportsRestored,
  });

  final Map<String, String> photoPaths;
  final Map<String, String> officialDocumentImagePaths;
  final int mediaRestored;
  final int mediaMissing;
  final int reportsRestored;
}

Map<String, Object?> _map(Object? value) {
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  return const {};
}

Map<String, Object?> _deepMap(Object? value) {
  return _map(_deepCopy(value));
}

Object? _deepCopy(Object? value) {
  if (value is Map) {
    return value.map(
      (key, value) => MapEntry(key.toString(), _deepCopy(value)),
    );
  }
  if (value is List) {
    return value.map(_deepCopy).toList();
  }
  return value;
}

List<Object?> _list(Object? value) => value is List ? value : const [];

String _string(Object? value) => value is String ? value : '';

int? _nullableInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is double) {
    return value.round();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

DateTime? _date(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}

String _mediaKey(String module, String ownerId, String mediaId) {
  return '$module|$ownerId|$mediaId';
}

String _safeName(String value) {
  final safe = value
      .trim()
      .replaceAll(RegExp(r'[^a-zA-Z0-9_.-]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  return safe.isEmpty ? 'registro' : safe;
}

String _extensionFor(String path) {
  final fileName = path.split(RegExp(r'[\\/]')).last;
  final dot = fileName.lastIndexOf('.');
  if (dot == -1 || dot == fileName.length - 1) {
    return '.jpg';
  }
  final extension = fileName.substring(dot).toLowerCase();
  if (extension.length > 12 || extension.contains(RegExp(r'[^a-z0-9.]'))) {
    return '.jpg';
  }
  return extension;
}

Future<String> _fileSha256(File file) async {
  final digest = await sha256.bind(file.openRead()).first;
  return digest.toString();
}
