import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sicro_campo/core/data/app_backup_restore_service.dart';
import 'package:sicro_campo/core/data/app_backup_service.dart';
import 'package:sicro_campo/domain/models/app_settings.dart';
import 'package:sicro_campo/domain/models/case_data.dart';
import 'package:sicro_campo/domain/models/duty_shift.dart';
import 'package:sicro_campo/domain/models/field_photo.dart';
import 'package:sicro_campo/domain/models/official_document.dart';
import 'package:sicro_campo/domain/models/occurrence.dart';

void main() {
  test('exports full app backup with core JSONs, media and hashes', () async {
    final tempDir = await Directory.systemTemp.createTemp('sicro_backup_test_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final photoFile = File('${tempDir.path}${Platform.pathSeparator}foto.jpg');
    await photoFile.writeAsBytes([1, 2, 3, 4]);
    final officialImage = File(
      '${tempDir.path}${Platform.pathSeparator}oficio.jpg',
    );
    await officialImage.writeAsBytes([5, 6, 7, 8]);
    final reportsDir = Directory(
      '${tempDir.path}${Platform.pathSeparator}sicro_operacional'
      '${Platform.pathSeparator}reports',
    );
    await reportsDir.create(recursive: true);
    await File(
      '${reportsDir.path}${Platform.pathSeparator}relatorio.pdf',
    ).writeAsBytes([9, 10, 11]);

    final now = DateTime(2026, 5, 27, 4);
    final service = AppBackupService(
      outputDirectoryProvider: () async => tempDir,
      clock: () => now,
    );
    final occurrence = FieldOccurrence(
      id: 'occ_1',
      createdAt: now,
      updatedAt: now,
      caseData: const CaseData(bo: '123/2026', municipality: 'Macapa'),
      photos: [
        FieldPhoto(
          id: 'foto_1',
          filePath: photoFile.path,
          category: PhotoCategory.overview,
          capturedAt: now,
        ),
      ],
    );
    final document = OfficialDocument(
      id: 'oficio_1',
      createdAt: now,
      updatedAt: now,
      imagePath: officialImage.path,
      documentNumber: '8971/2026',
    );
    final shift = DutyShift(
      id: 'plantao_1',
      createdAt: now,
      updatedAt: now,
      startsAt: now,
      endsAt: now.add(const Duration(hours: 12)),
    );

    final result = await service.exportFullBackup(
      settings: const AppSettings(
        profile: ExpertProfile(name: 'Andre', role: 'Perito Criminal'),
      ),
      occurrences: [occurrence],
      officialDocuments: [document],
      dutyShifts: [shift],
    );

    expect(result.fileName, endsWith('.sicrobackup'));
    expect(result.inventory.occurrenceCount, 1);
    expect(result.inventory.officialDocumentCount, 1);
    expect(result.inventory.dutyShiftCount, 1);
    expect(result.mediaIncluded, 2);
    expect(result.reportsIncluded, 1);
    expect(result.hashCount, greaterThan(0));

    final archive = ZipDecoder().decodeBytes(await result.file.readAsBytes());
    final names = archive.files.map((file) => file.name).toSet();
    expect(names, contains('manifest.json'));
    expect(names, contains('configuracoes.json'));
    expect(names, contains('ocorrencias.json'));
    expect(names, contains('oficios.json'));
    expect(names, contains('plantoes.json'));
    expect(names, contains('media_index.json'));
    expect(names, contains('relatorios_index.json'));
    expect(names, contains('hashes.json'));
    expect(
      names.any((name) => name.startsWith('media/fotos/occ_1/foto_1')),
      isTrue,
    );
    expect(
      names.any((name) => name.startsWith('media/oficios/oficio_1')),
      isTrue,
    );
    expect(names, contains('relatorios/relatorio.pdf'));

    final manifest = _jsonFromArchive(archive, 'manifest.json');
    expect(manifest['formato'], 'sicro_operacional_backup');
    expect(manifest['extensao'], '.sicrobackup');
    expect(manifest['gerado_em'], now.toIso8601String());
  });

  test('restores full backup with private media paths', () async {
    final sourceDir = await Directory.systemTemp.createTemp(
      'sicro_backup_source_',
    );
    final restoreDir = await Directory.systemTemp.createTemp(
      'sicro_backup_restore_',
    );
    addTearDown(() async {
      if (await sourceDir.exists()) {
        await sourceDir.delete(recursive: true);
      }
      if (await restoreDir.exists()) {
        await restoreDir.delete(recursive: true);
      }
    });

    final photoFile = File(
      '${sourceDir.path}${Platform.pathSeparator}foto.jpg',
    );
    await photoFile.writeAsBytes([1, 2, 3, 4]);
    final officialImage = File(
      '${sourceDir.path}${Platform.pathSeparator}oficio.jpg',
    );
    await officialImage.writeAsBytes([5, 6, 7, 8]);
    final now = DateTime(2026, 5, 27, 4);
    final backupService = AppBackupService(
      outputDirectoryProvider: () async => sourceDir,
      clock: () => now,
    );
    final restoreService = AppBackupRestoreService(
      directoryProvider: () async => restoreDir,
      clock: () => now,
    );
    final occurrence = FieldOccurrence(
      id: 'occ_1',
      createdAt: now,
      updatedAt: now,
      caseData: const CaseData(bo: '123/2026'),
      photos: [
        FieldPhoto(
          id: 'foto_1',
          filePath: photoFile.path,
          category: PhotoCategory.overview,
          capturedAt: now,
        ),
      ],
    );
    final document = OfficialDocument(
      id: 'oficio_1',
      createdAt: now,
      updatedAt: now,
      imagePath: officialImage.path,
      documentNumber: '8971/2026',
    );

    final exported = await backupService.exportFullBackup(
      settings: const AppSettings(profile: ExpertProfile(name: 'Andre')),
      occurrences: [occurrence],
      officialDocuments: [document],
      dutyShifts: const [],
    );
    final validation = await restoreService.validate(exported.file);
    final restored = await restoreService.restore(validation);

    expect(restored.occurrences, hasLength(1));
    expect(restored.officialDocuments, hasLength(1));
    expect(restored.mediaRestored, 2);
    expect(
      restored.occurrences.first.photos.first.filePath,
      isNot(photoFile.path),
    );
    expect(
      await File(restored.occurrences.first.photos.first.filePath).exists(),
      isTrue,
    );
    expect(
      await File(restored.officialDocuments.first.imagePath).exists(),
      isTrue,
    );
    expect(restored.settings.profile.name, 'Andre');
    expect(restored.settings.onboardingCompleted, isTrue);
  });
}

Map<String, Object?> _jsonFromArchive(Archive archive, String path) {
  final file = archive.files.firstWhere((entry) => entry.name == path);
  return jsonDecode(utf8.decode(file.content as List<int>))
      as Map<String, Object?>;
}
