import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sicro_campo/core/data/duty_report_pdf_service.dart';
import 'package:sicro_campo/core/data/operational_statistics_service.dart';
import 'package:sicro_campo/core/data/statistical_report_pdf_service.dart';
import 'package:sicro_campo/domain/models/app_settings.dart';
import 'package:sicro_campo/domain/models/case_data.dart';
import 'package:sicro_campo/domain/models/field_photo.dart';
import 'package:sicro_campo/domain/models/forensic_case_metadata.dart';
import 'package:sicro_campo/domain/models/location_record.dart';
import 'package:sicro_campo/domain/models/occurrence.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('generates duty report PDF with selected occurrences', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'sicro_duty_report_test_',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final service = DutyReportPdfService(
      outputDirectoryProvider: () async => tempDir,
      clock: () => DateTime(2026, 5, 21, 19, 30),
    );

    final result = await service.generate(
      DutyReportData(
        expertName: 'Andre Ricardo Barroso',
        role: 'Perito Criminal',
        dutyScale: 'Transito I',
        startedAt: DateTime(2026, 5, 21, 7, 30),
        finishedAt: DateTime(2026, 5, 22, 7, 30),
        observations: 'Plantao sem intercorrencias administrativas.',
        occurrences: [
          FieldOccurrence(
            id: 'occ_report_1',
            createdAt: DateTime(2026, 5, 21, 19, 20),
            updatedAt: DateTime(2026, 5, 21, 19, 40),
            metadata: const ForensicCaseMetadata(
              trafficNature: TrafficNature.collision,
            ),
            caseData: CaseData(
              bo: '123/2026',
              requisition: 'OF-01',
              protocol: '30941/2026',
              policeUnit: 'DECCOTRAN',
              municipality: 'Macapa',
              street: 'Av. Adilson Jose Pinto Pereira',
              arrivedAt: DateTime(2026, 5, 21, 19, 20),
            ),
          ),
        ],
      ),
    );

    expect(result.fileName, 'Relatorio_Plantao_20260521.pdf');
    expect(result.template, DutyReportTemplate.classic);
    expect(result.occurrenceCount, 1);
    expect(result.generatedAt, DateTime(2026, 5, 21, 19, 30));
    expect(await result.file.exists(), isTrue);
    expect(result.sizeBytes, greaterThan(1000));

    final bytes = await result.file.readAsBytes();
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('generates operational SICRO duty report PDF', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'sicro_operational_duty_report_test_',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final service = DutyReportPdfService(
      outputDirectoryProvider: () async => tempDir,
      clock: () => DateTime(2026, 5, 25, 21),
    );
    final photoFile = File('assets/launcher/app_icon.png');

    final result = await service.generate(
      DutyReportData(
        expertName: 'Andre Ricardo Barroso',
        role: 'Perito Criminal',
        dutyScale: 'Transito I',
        startedAt: DateTime(2026, 5, 25, 7, 30),
        finishedAt: DateTime(2026, 5, 26, 7, 30),
        observations: 'Plantao consolidado pelo ecossistema SICRO.',
        template: DutyReportTemplate.operational,
        occurrences: [
          FieldOccurrence(
            id: 'occ_operational_report_1',
            createdAt: DateTime(2026, 5, 25, 20, 4),
            updatedAt: DateTime(2026, 5, 25, 20, 26),
            startedAt: DateTime(2026, 5, 25, 20, 4),
            finishedAt: DateTime(2026, 5, 25, 20, 26),
            status: OccurrenceStatus.completed,
            metadata: const ForensicCaseMetadata(
              trafficNature: TrafficNature.collision,
              trafficInvolved: [
                TrafficInvolved.car,
                TrafficInvolved.motorcycle,
              ],
              result: OccurrenceResult.injuredVictim,
              officialVehicleInvolved: true,
            ),
            caseData: CaseData(
              bo: '123/2026',
              protocol: '30941/2026',
              municipality: 'Macapa',
              street: 'Av. FAB',
              arrivedAt: DateTime(2026, 5, 25, 20, 4),
            ),
            location: LocationRecord(
              latitude: 0.0656487,
              longitude: -51.0521516,
              accuracyMeters: 4.3,
              capturedAt: DateTime(2026, 5, 25, 20, 8),
            ),
            photos: [
              FieldPhoto(
                id: 'foto_local_1',
                filePath: photoFile.path,
                category: PhotoCategory.overview,
                capturedAt: DateTime(2026, 5, 25, 20, 6),
              ),
            ],
          ),
        ],
      ),
    );

    expect(result.fileName, 'Relatorio_Plantao_SICRO_20260525.pdf');
    expect(result.template, DutyReportTemplate.operational);
    expect(result.occurrenceCount, 1);
    expect(await result.file.exists(), isTrue);
    expect(result.sizeBytes, greaterThan(1000));

    final bytes = await result.file.readAsBytes();
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('generates statistical report PDF from filtered snapshot', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'sicro_statistical_report_test_',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final snapshot = const OperationalStatisticsService().aggregate(
      [
        FieldOccurrence(
          id: 'occ_stats_1',
          createdAt: DateTime(2026, 5, 21, 8),
          updatedAt: DateTime(2026, 5, 21, 10),
          startedAt: DateTime(2026, 5, 21, 8),
          finishedAt: DateTime(2026, 5, 21, 10),
          status: OccurrenceStatus.completed,
          metadata: ForensicCaseMetadata(
            trafficNature: TrafficNature.collision,
            result: OccurrenceResult.injuredVictim,
          ),
          caseData: CaseData(municipality: 'Macapa', district: 'Centro'),
        ),
      ],
      const StatisticsFilter(period: StatisticsPeriodPreset.today),
      now: DateTime(2026, 5, 21, 12),
    );

    final service = StatisticalReportPdfService(
      outputDirectoryProvider: () async => tempDir,
      clock: () => DateTime(2026, 5, 21, 19, 45),
    );

    final result = await service.generate(
      snapshot: snapshot,
      profile: const ExpertProfile(
        name: 'Andre Ricardo Barroso',
        role: 'Perito Criminal',
        organization: 'Policia Cientifica do Amapa',
        unit: 'Criminalistica',
      ),
    );

    expect(result.fileName, 'Relatorio_Estatistico_20260521_1945.pdf');
    expect(result.occurrenceCount, 1);
    expect(result.generatedAt, DateTime(2026, 5, 21, 19, 45));
    expect(await result.file.exists(), isTrue);
    expect(result.sizeBytes, greaterThan(1000));

    final bytes = await result.file.readAsBytes();
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
