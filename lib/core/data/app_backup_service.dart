import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import '../../app/app_info.dart';
import '../../domain/models/app_settings.dart';
import '../../domain/models/duty_shift.dart';
import '../../domain/models/field_photo.dart';
import '../../domain/models/official_document.dart';
import '../../domain/models/occurrence.dart';

class AppBackupInventory {
  const AppBackupInventory({
    required this.occurrenceCount,
    required this.officialDocumentCount,
    required this.dutyShiftCount,
    required this.photoCount,
    required this.officialDocumentImageCount,
    required this.reportCount,
  });

  final int occurrenceCount;
  final int officialDocumentCount;
  final int dutyShiftCount;
  final int photoCount;
  final int officialDocumentImageCount;
  final int reportCount;

  int get mediaCount => photoCount + officialDocumentImageCount;

  Map<String, Object?> toJson() {
    return {
      'ocorrencias': occurrenceCount,
      'oficios': officialDocumentCount,
      'plantoes': dutyShiftCount,
      'fotos_ocorrencias': photoCount,
      'imagens_oficios': officialDocumentImageCount,
      'midias_total': mediaCount,
      'relatorios_pdf': reportCount,
    };
  }
}

class AppBackupResult {
  const AppBackupResult({
    required this.file,
    required this.fileName,
    required this.sizeBytes,
    required this.sha256,
    required this.entryCount,
    required this.hashCount,
    required this.inventory,
    required this.mediaIncluded,
    required this.mediaMissing,
    required this.reportsIncluded,
    required this.warnings,
    required this.generatedAt,
  });

  final File file;
  final String fileName;
  final int sizeBytes;
  final String sha256;
  final int entryCount;
  final int hashCount;
  final AppBackupInventory inventory;
  final int mediaIncluded;
  final int mediaMissing;
  final int reportsIncluded;
  final List<String> warnings;
  final DateTime generatedAt;

  bool get hasWarnings => warnings.isNotEmpty;
}

class AppBackupService {
  AppBackupService({
    Future<Directory> Function()? outputDirectoryProvider,
    DateTime Function()? clock,
  }) : _outputDirectoryProvider =
           outputDirectoryProvider ?? getApplicationDocumentsDirectory,
       _clock = clock ?? DateTime.now;

  final Future<Directory> Function() _outputDirectoryProvider;
  final DateTime Function() _clock;
  final JsonEncoder _encoder = const JsonEncoder.withIndent('  ');

  Future<AppBackupInventory> inventory({
    required List<FieldOccurrence> occurrences,
    required List<OfficialDocument> officialDocuments,
    required List<DutyShift> dutyShifts,
  }) async {
    final reports = await _reportFiles();
    return AppBackupInventory(
      occurrenceCount: occurrences.length,
      officialDocumentCount: officialDocuments.length,
      dutyShiftCount: dutyShifts.length,
      photoCount: occurrences.fold<int>(
        0,
        (total, occurrence) => total + occurrence.photos.length,
      ),
      officialDocumentImageCount: officialDocuments
          .where((document) => document.imagePath.trim().isNotEmpty)
          .length,
      reportCount: reports.length,
    );
  }

  Future<AppBackupResult> exportFullBackup({
    required AppSettings settings,
    required List<FieldOccurrence> occurrences,
    required List<OfficialDocument> officialDocuments,
    required List<DutyShift> dutyShifts,
  }) async {
    final generatedAt = _clock();
    final archive = Archive();
    final hashes = <String, String>{};
    final entries = <String>[];
    final warnings = <String>[];
    final mediaIndex = <Map<String, Object?>>[];
    var mediaIncluded = 0;
    var mediaMissing = 0;
    var reportsIncluded = 0;

    void addBytes(String path, List<int> bytes) {
      archive.addFile(ArchiveFile.bytes(path, bytes));
      hashes[path] = sha256.convert(bytes).toString();
      entries.add(path);
    }

    void addJson(String path, Object? data) {
      final json = '${_encoder.convert(data)}\n';
      addBytes(path, utf8.encode(json));
    }

    for (final occurrence in occurrences) {
      for (final photo in occurrence.photos) {
        final entryPath =
            'media/fotos/${_safeName(occurrence.id)}/'
            '${_safeName(photo.id)}${_extensionFor(photo.filePath)}';
        final media = await _addMediaFile(
          addBytes: addBytes,
          sourcePath: photo.filePath,
          entryPath: entryPath,
          originalSha256: photo.sha256,
          sourceModule: 'ocorrencias',
          ownerId: occurrence.id,
          mediaId: photo.id,
          metadata: _photoMetadata(photo),
          warnings: warnings,
        );
        mediaIndex.add(media);
        if (media['arquivo_disponivel'] == true) {
          mediaIncluded++;
        } else {
          mediaMissing++;
        }
      }
    }

    for (final document in officialDocuments) {
      final imagePath = document.imagePath.trim();
      if (imagePath.isEmpty) {
        mediaIndex.add({
          'id': document.id,
          'modulo_origem': 'oficios',
          'dono_id': document.id,
          'tipo': 'imagem_oficio',
          'arquivo_original': '',
          'arquivo_backup': '',
          'arquivo_disponivel': false,
          'sha256_original': document.imageSha256,
          'sha256_backup': '',
          'metadados': {
            'oficio_numero': document.documentNumber,
            'bo': document.boNumber,
            'protocolo_pci': document.protocol,
          },
        });
        continue;
      }
      final entryPath =
          'media/oficios/${_safeName(document.id)}'
          '${_extensionFor(imagePath)}';
      final media = await _addMediaFile(
        addBytes: addBytes,
        sourcePath: imagePath,
        entryPath: entryPath,
        originalSha256: document.imageSha256,
        sourceModule: 'oficios',
        ownerId: document.id,
        mediaId: document.id,
        metadata: {
          'oficio_numero': document.documentNumber,
          'bo': document.boNumber,
          'protocolo_pci': document.protocol,
        },
        warnings: warnings,
      );
      mediaIndex.add(media);
      if (media['arquivo_disponivel'] == true) {
        mediaIncluded++;
      } else {
        mediaMissing++;
      }
    }

    final reportFiles = await _reportFiles();
    final reportsIndex = <Map<String, Object?>>[];
    for (final file in reportFiles) {
      final fileName = file.uri.pathSegments.last;
      final entryPath = 'relatorios/${_safeName(fileName)}';
      try {
        final bytes = await file.readAsBytes();
        addBytes(entryPath, bytes);
        reportsIncluded++;
        reportsIndex.add({
          'arquivo_original': file.path,
          'arquivo_backup': entryPath,
          'tamanho_bytes': bytes.length,
          'sha256': hashes[entryPath],
        });
      } catch (error) {
        warnings.add('Relatorio nao incluido no backup: $fileName');
      }
    }

    final inventory = AppBackupInventory(
      occurrenceCount: occurrences.length,
      officialDocumentCount: officialDocuments.length,
      dutyShiftCount: dutyShifts.length,
      photoCount: occurrences.fold<int>(
        0,
        (total, occurrence) => total + occurrence.photos.length,
      ),
      officialDocumentImageCount: officialDocuments
          .where((document) => document.imagePath.trim().isNotEmpty)
          .length,
      reportCount: reportFiles.length,
    );

    addJson('configuracoes.json', settings.toJson());
    addJson(
      'ocorrencias.json',
      occurrences.map((occurrence) => occurrence.toJson()).toList(),
    );
    addJson(
      'oficios.json',
      officialDocuments.map((document) => document.toJson()).toList(),
    );
    addJson(
      'plantoes.json',
      dutyShifts.map((shift) => shift.toJson()).toList(),
    );
    addJson('estatisticas_ocorrencias.json', {
      'gerado_em': generatedAt.toIso8601String(),
      'ocorrencias': occurrences
          .map((occurrence) => occurrence.stats.toJson())
          .toList(),
    });
    addJson('media_index.json', mediaIndex);
    addJson('relatorios_index.json', reportsIndex);

    final finalEntries = ['manifest.json', ...entries, 'hashes.json'];
    addJson(
      'manifest.json',
      _manifestJson(
        generatedAt: generatedAt,
        settings: settings,
        inventory: inventory,
        entries: finalEntries,
        warnings: warnings,
        mediaIncluded: mediaIncluded,
        mediaMissing: mediaMissing,
        reportsIncluded: reportsIncluded,
      ),
    );
    final hashCount = hashes.length;
    addJson('hashes.json', _hashesJson(hashes));

    final zipBytes = ZipEncoder().encodeBytes(archive);
    final outputDir = await _backupDirectory();
    final fileName = _backupFileName(generatedAt);
    final outputFile = File(
      '${outputDir.path}${Platform.pathSeparator}$fileName',
    );
    await outputFile.writeAsBytes(zipBytes, flush: true);

    return AppBackupResult(
      file: outputFile,
      fileName: fileName,
      sizeBytes: zipBytes.length,
      sha256: sha256.convert(zipBytes).toString(),
      entryCount: finalEntries.length,
      hashCount: hashCount,
      inventory: inventory,
      mediaIncluded: mediaIncluded,
      mediaMissing: mediaMissing,
      reportsIncluded: reportsIncluded,
      warnings: warnings,
      generatedAt: generatedAt,
    );
  }

  Future<Map<String, Object?>> _addMediaFile({
    required void Function(String path, List<int> bytes) addBytes,
    required String sourcePath,
    required String entryPath,
    required String originalSha256,
    required String sourceModule,
    required String ownerId,
    required String mediaId,
    required Map<String, Object?> metadata,
    required List<String> warnings,
  }) async {
    final file = File(sourcePath);
    if (!await file.exists()) {
      warnings.add('Midia nao encontrada no aparelho: $mediaId');
      return {
        'id': mediaId,
        'modulo_origem': sourceModule,
        'dono_id': ownerId,
        'arquivo_original': sourcePath,
        'arquivo_backup': entryPath,
        'arquivo_disponivel': false,
        'sha256_original': originalSha256,
        'sha256_backup': '',
        'metadados': metadata,
      };
    }

    final bytes = await file.readAsBytes();
    addBytes(entryPath, bytes);
    return {
      'id': mediaId,
      'modulo_origem': sourceModule,
      'dono_id': ownerId,
      'arquivo_original': sourcePath,
      'arquivo_backup': entryPath,
      'arquivo_disponivel': true,
      'tamanho_bytes': bytes.length,
      'sha256_original': originalSha256,
      'sha256_backup': sha256.convert(bytes).toString(),
      'metadados': metadata,
    };
  }

  Map<String, Object?> _photoMetadata(FieldPhoto photo) {
    return {
      'categoria': photo.category.code,
      'capturada_em': photo.capturedAt.toIso8601String(),
      'legenda': photo.caption,
      'entidade_vinculada': photo.linkedEntityId,
    };
  }

  Future<List<File>> _reportFiles() async {
    final base = await _outputDirectoryProvider();
    final reportsDir = Directory(
      '${base.path}${Platform.pathSeparator}sicro_operacional'
      '${Platform.pathSeparator}reports',
    );
    if (!await reportsDir.exists()) {
      return const [];
    }
    final files = <File>[];
    await for (final entity in reportsDir.list(recursive: true)) {
      if (entity is! File) {
        continue;
      }
      final fileName = entity.uri.pathSegments.last.toLowerCase();
      if (fileName.endsWith('.pdf')) {
        files.add(entity);
      }
    }
    files.sort((a, b) => a.path.compareTo(b.path));
    return files;
  }

  Future<Directory> _backupDirectory() async {
    final base = await _outputDirectoryProvider();
    final dir = Directory(
      '${base.path}${Platform.pathSeparator}sicro_operacional'
      '${Platform.pathSeparator}backups',
    );
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Map<String, Object?> _manifestJson({
    required DateTime generatedAt,
    required AppSettings settings,
    required AppBackupInventory inventory,
    required List<String> entries,
    required List<String> warnings,
    required int mediaIncluded,
    required int mediaMissing,
    required int reportsIncluded,
  }) {
    return {
      'formato': 'sicro_operacional_backup',
      'extensao': '.sicrobackup',
      'versao': '0.1',
      'app_nome': AppInfo.name,
      'app_versao': AppInfo.version,
      'app_build': AppInfo.buildNumber,
      'app_canal': AppInfo.channel,
      'gerado_em': generatedAt.toIso8601String(),
      'tipo': 'backup_total_local',
      'perfil_perito': settings.profile.toJson(),
      'politica': {
        'recomendacao': 'backup mensal',
        'hora_preferida': settings.backup.preferredHour,
        'intervalo_dias': settings.backup.reminderIntervalDays,
        'observacao':
            'Backup completo do aparelho. Exportacoes .sicroapp individuais nao sao duplicadas para reduzir redundancia.',
      },
      'contagens': {
        ...inventory.toJson(),
        'midias_incluidas': mediaIncluded,
        'midias_ausentes': mediaMissing,
        'relatorios_incluidos': reportsIncluded,
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

  String _backupFileName(DateTime generatedAt) {
    return 'SICRO_BACKUP_${_timestamp(generatedAt)}.sicrobackup';
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
}
