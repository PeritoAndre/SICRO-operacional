import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sicro_campo/app/sicro_campo_app.dart';
import 'package:sicro_campo/core/data/app_settings_repository.dart';
import 'package:sicro_campo/core/data/app_settings_storage.dart';
import 'package:sicro_campo/core/data/occurrence_repository.dart';
import 'package:sicro_campo/domain/models/app_settings.dart';
import 'package:sicro_campo/domain/models/case_data.dart';
import 'package:sicro_campo/domain/models/field_note.dart';
import 'package:sicro_campo/domain/models/field_photo.dart';
import 'package:sicro_campo/domain/models/forensic_case_metadata.dart';
import 'package:sicro_campo/domain/models/location_record.dart';
import 'package:sicro_campo/domain/models/measurement_record.dart';
import 'package:sicro_campo/domain/models/vehicle_record.dart';
import 'package:sicro_campo/domain/models/victim_record.dart';

void main() {
  testWidgets('renders app home shell after onboarding', (
    WidgetTester tester,
  ) async {
    final repository = OccurrenceRepository();
    await repository.load();
    final settingsRepository = await _settingsRepository();
    await tester.pumpWidget(
      SicroCampoApp(
        repository: repository,
        settingsRepository: settingsRepository,
      ),
    );

    expect(find.text('SICRO Operacional'), findsWidgets);
    expect(find.text('Iniciar pericia'), findsOneWidget);
    expect(find.text('Gerar relatorio de plantao'), findsOneWidget);
    expect(find.text('Estatisticas'), findsOneWidget);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Recentes'), findsOneWidget);
  });

  testWidgets('creates traffic occurrence from guided start flow', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repository = OccurrenceRepository();
    await repository.load();
    final settingsRepository = await _settingsRepository();
    await tester.pumpWidget(
      SicroCampoApp(
        repository: repository,
        settingsRepository: settingsRepository,
      ),
    );

    await tester.tap(find.text('Iniciar pericia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pedestre'));
    await tester.tap(find.text('Com vitima lesionada'));
    await tester.enterText(find.bySemanticsLabel('BO'), '123/2026');
    await tester.tap(find.text('Criar ocorrencia'));
    await tester.pumpAndSettle();

    expect(find.text('Dossie operacional'), findsOneWidget);
    expect(find.text('BO 123/2026'), findsOneWidget);
    expect(
      find.text('Transito - Colisao - Pedestre - Com vitima lesionada'),
      findsOneWidget,
    );
    expect(
      repository.occurrences.first.metadata.trafficInvolved.first.label,
      'Pedestre',
    );
  });

  testWidgets('creates violent death occurrence from setup flow', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 3600);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repository = OccurrenceRepository();
    await repository.load();
    final settingsRepository = await _settingsRepository(
      activeAreas: const [ForensicArea.traffic, ForensicArea.violentDeath],
    );
    await tester.pumpWidget(
      SicroCampoApp(
        repository: repository,
        settingsRepository: settingsRepository,
      ),
    );

    await tester.tap(find.text('Iniciar pericia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Morte violenta'));
    await tester.pumpAndSettle();
    expect(find.text('Transito'), findsWidgets);
    expect(find.text('Morte violenta'), findsWidgets);
    await tester.tap(find.text('Configurar morte violenta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Morte suspeita'));
    await tester.tap(find.text('Corpo presente no local'));
    await tester.tap(find.text('1 vitima'));
    await tester.tap(find.text('Via publica'));
    await tester.tap(find.text('Sangue/mancha biologica'));
    await tester.tap(find.text('Capsulas/estojos'));
    await tester.enterText(find.bySemanticsLabel('BO'), 'MV-01/2026');
    await tester.tap(find.text('Criar ocorrencia'));
    await tester.pumpAndSettle();

    final metadata = repository.occurrences.first.metadata;
    expect(find.text('Dossie operacional'), findsOneWidget);
    expect(find.text('BO MV-01/2026'), findsOneWidget);
    expect(
      find.text(
        'Morte violenta - Morte suspeita - Corpo presente no local - 1 vitima - Via publica',
      ),
      findsOneWidget,
    );
    expect(find.text('Checklist de morte violenta'), findsWidgets);
    expect(find.text('Vitimas/Corpos'), findsWidgets);
    expect(find.text('Vestigios biologicos'), findsWidgets);
    expect(find.text('Vestigios balisticos'), findsWidgets);
    expect(find.text('Armas/objetos'), findsWidgets);
    expect(find.text('Veiculos'), findsNothing);
    expect(metadata.type, ForensicCaseType.violentDeath);
    expect(metadata.violentDeathNature, ViolentDeathNature.suspiciousDeath);
    expect(metadata.bodyState, BodyState.present);
    expect(metadata.victimCount, VictimCount.one);
    expect(metadata.sceneEnvironment, SceneEnvironment.publicRoad);
    expect(metadata.expectedViolentDeathTraces, [
      ExpectedViolentDeathTrace.bloodBiologicalStain,
      ExpectedViolentDeathTrace.cases,
    ]);
  });

  testWidgets('start flow keeps forensic area selector persistent', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repository = OccurrenceRepository();
    await repository.load();
    final settingsRepository = await _settingsRepository(
      activeAreas: const [
        ForensicArea.traffic,
        ForensicArea.violentDeath,
        ForensicArea.property,
      ],
    );
    await tester.pumpWidget(
      SicroCampoApp(
        repository: repository,
        settingsRepository: settingsRepository,
      ),
    );

    await tester.tap(find.text('Iniciar pericia'));
    await tester.pumpAndSettle();
    expect(find.text('Transito'), findsWidgets);
    expect(find.text('Morte violenta'), findsOneWidget);
    expect(find.text('Patrimonio'), findsOneWidget);

    await tester.tap(find.text('Morte violenta'));
    await tester.pumpAndSettle();
    expect(find.text('Transito'), findsWidgets);
    expect(find.text('Morte violenta'), findsWidgets);
    expect(find.text('Patrimonio'), findsOneWidget);
    expect(find.text('Configurar morte violenta'), findsOneWidget);

    await tester.tap(find.text('Patrimonio'));
    await tester.pumpAndSettle();
    expect(find.text('Transito'), findsWidgets);
    expect(find.text('Morte violenta'), findsOneWidget);
    expect(find.text('Patrimonio'), findsWidgets);
    expect(find.text('Configurar patrimonio'), findsOneWidget);

    await tester.tap(find.text('Transito').first);
    await tester.pumpAndSettle();
    expect(find.text('Natureza'), findsOneWidget);
    expect(find.text('Criar ocorrencia'), findsOneWidget);
  });

  testWidgets('creates property occurrence from simplified setup flow', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repository = OccurrenceRepository();
    await repository.load();
    final settingsRepository = await _settingsRepository(
      activeAreas: const [ForensicArea.traffic, ForensicArea.property],
    );
    await tester.pumpWidget(
      SicroCampoApp(
        repository: repository,
        settingsRepository: settingsRepository,
      ),
    );

    await tester.tap(find.text('Iniciar pericia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Patrimonio'));
    await tester.pumpAndSettle();
    expect(find.text('Transito'), findsWidgets);
    expect(find.text('Patrimonio'), findsWidgets);
    await tester.tap(find.text('Configurar patrimonio'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Arrombamento'));
    await tester.enterText(find.bySemanticsLabel('BO'), 'PAT-01/2026');
    await tester.tap(find.text('Criar ocorrencia'));
    await tester.pumpAndSettle();

    final metadata = repository.occurrences.first.metadata;
    expect(find.text('Dossie operacional'), findsOneWidget);
    expect(find.text('BO PAT-01/2026'), findsOneWidget);
    expect(find.text('Patrimonio - Arrombamento'), findsOneWidget);
    expect(find.text('Checklist de patrimonio'), findsWidgets);
    expect(find.text('Vestigios patrimoniais'), findsWidgets);
    expect(find.text('Vitimas'), findsNothing);
    expect(find.text('Veiculos'), findsNothing);
    expect(metadata.type, ForensicCaseType.property);
    expect(metadata.propertyNature, PropertyNature.burglary);
  });

  testWidgets('dashboard shows consolidated MVP module status', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 3600);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repository = OccurrenceRepository();
    await repository.load();
    final occurrence = await repository.createOccurrence(
      const CaseData(bo: '999/2026', municipality: 'Macapa', street: 'Av. FAB'),
    );
    await repository.updateLocation(
      occurrence.id,
      LocationRecord(
        latitude: 0.0349,
        longitude: -51.0694,
        accuracyMeters: 4.2,
        capturedAt: DateTime(2026, 5, 19, 10, 30),
      ),
    );
    await repository.addPhoto(
      occurrence.id,
      FieldPhoto(
        id: 'foto_1',
        filePath: 'local/foto_1.jpg',
        category: PhotoCategory.overview,
        capturedAt: DateTime(2026, 5, 19, 10, 35),
        sha256: 'abc123',
      ),
    );
    final vehicle = await repository.createVehicle(occurrence.id);
    await repository.updateVehicle(
      occurrence.id,
      VehicleRecord(
        id: vehicle!.id,
        identifier: vehicle.identifier,
        plate: 'ABC1D23',
        photoIds: const ['foto_1'],
      ),
    );
    final victim = await repository.createVictim(occurrence.id);
    await repository.updateVictim(
      occurrence.id,
      VictimRecord(
        id: victim!.id,
        identifier: victim.identifier,
        condition: VictimCondition.injured,
        photoIds: const ['foto_1'],
      ),
    );
    final trace = await repository.createTrace(occurrence.id);
    await repository.updateTrace(
      occurrence.id,
      trace!.copyWith(photoIds: const ['foto_1']),
    );
    final measurement = await repository.createMeasurement(occurrence.id);
    await repository.updateMeasurement(
      occurrence.id,
      MeasurementRecord(
        id: measurement!.id,
        label: measurement.label,
        value: 5,
        unit: 'm',
        method: 'trena',
        photoIds: const ['foto_1'],
      ),
    );
    final note = await repository.createNote(occurrence.id);
    await repository.updateNote(
      occurrence.id,
      note!.copyWith(
        text: 'Conferir iluminacao publica.',
        priority: NotePriority.important,
      ),
    );

    final settingsRepository = await _settingsRepository();
    await tester.pumpWidget(
      SicroCampoApp(
        repository: repository,
        settingsRepository: settingsRepository,
      ),
    );
    await tester.tap(find.text('BO 999/2026'));
    await tester.pumpAndSettle();

    expect(find.text('Dossie operacional'), findsOneWidget);
    expect(find.text('Proxima acao'), findsOneWidget);
    expect(find.text('Checklist'), findsOneWidget);
    expect(find.text('3 pendencia(s) operacional(is)'), findsOneWidget);
    expect(find.text('70%'), findsOneWidget);
    expect(find.text('Progresso operacional'), findsNothing);
    expect(find.text('Resumo estatistico'), findsNothing);
    expect(find.text('Fluxo sugerido'), findsNothing);

    await tester.tap(find.text('Ver'));
    await tester.pumpAndSettle();
    expect(find.text('Pendencias operacionais'), findsOneWidget);
    expect(find.text('Nenhuma foto de vestigio'), findsOneWidget);
    expect(find.text('Ocorrencia ainda nao exportada'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    final scrollable = find.byType(Scrollable).last;
    await tester.dragUntilVisible(
      find.text('GPS / localizacao'),
      scrollable,
      const Offset(0, -360),
    );
    expect(find.text('GPS / localizacao'), findsOneWidget);
    expect(find.text('4.2 m - 19/05 10:30 - 1 leitura(s)'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('Checklist de transito'),
      scrollable,
      const Offset(0, -260),
    );
    expect(find.text('Checklist de transito'), findsOneWidget);
    expect(
      find.text('0/22 respondidos - 8 obrigatorios pendentes'),
      findsOneWidget,
    );
    await tester.dragUntilVisible(
      find.text('Fotos categorizadas'),
      scrollable,
      const Offset(0, -260),
    );
    expect(find.text('Fotos categorizadas'), findsOneWidget);
    expect(find.text('1 foto(s) - 1 visao geral'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('1 registrado(s) - 1 foto(s) vinculada(s)'),
      260,
      scrollable: scrollable,
    );
    expect(find.text('Veiculos'), findsWidgets);
    expect(
      find.text('1 registrado(s) - 1 foto(s) vinculada(s)'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('1 registrada(s) - 1 lesionada(s)/obito - 1 foto(s)'),
      260,
      scrollable: scrollable,
    );
    expect(find.text('Vitimas'), findsWidgets);
    expect(
      find.text('1 registrada(s) - 1 lesionada(s)/obito - 1 foto(s)'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('1 registrado(s) - 1 frenagem'),
      260,
      scrollable: scrollable,
    );
    expect(find.text('Vestigios'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('1 registrada(s) - M1 5 m'),
      260,
      scrollable: scrollable,
    );
    expect(find.text('Medicoes'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('1 registrada(s) - 1 importante(s)/critica(s)'),
      260,
      scrollable: scrollable,
    );
    expect(find.text('Observacoes'), findsWidgets);
    expect(
      find.text('1 registrada(s) - 1 importante(s)/critica(s)'),
      findsOneWidget,
    );
  });
}

Future<AppSettingsRepository> _settingsRepository({
  List<ForensicArea> activeAreas = const [ForensicArea.traffic],
}) async {
  final settingsRepository = AppSettingsRepository(
    storage: MemoryAppSettingsStorage(
      AppSettings(onboardingCompleted: true, activeAreas: activeAreas),
    ),
  );
  await settingsRepository.load();
  return settingsRepository;
}
