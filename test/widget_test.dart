import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sicro_campo/app/sicro_campo_app.dart';
import 'package:sicro_campo/core/data/app_settings_repository.dart';
import 'package:sicro_campo/core/data/app_settings_storage.dart';
import 'package:sicro_campo/core/data/duty_shift_repository.dart';
import 'package:sicro_campo/core/data/official_document_repository.dart';
import 'package:sicro_campo/core/data/occurrence_repository.dart';
import 'package:sicro_campo/domain/models/app_settings.dart';
import 'package:sicro_campo/domain/models/case_data.dart';
import 'package:sicro_campo/domain/models/field_note.dart';
import 'package:sicro_campo/domain/models/field_photo.dart';
import 'package:sicro_campo/domain/models/forensic_case_metadata.dart';
import 'package:sicro_campo/domain/models/location_record.dart';
import 'package:sicro_campo/domain/models/measurement_record.dart';
import 'package:sicro_campo/domain/models/occurrence.dart';
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
        officialDocumentRepository: await _officialDocumentRepository(),
        settingsRepository: settingsRepository,
        dutyShiftRepository: await _dutyShiftRepository(),
      ),
    );

    expect(find.text('SICRO Operacional'), findsWidgets);
    expect(find.text('Iniciar pericia'), findsOneWidget);
    expect(find.text('Gerar relatorio de plantao'), findsOneWidget);
    expect(find.text('Estatisticas'), findsOneWidget);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Diario operacional vazio'), findsOneWidget);
  });

  testWidgets('duty report filters occurrences by duty period with grace', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final now = DateTime.now();
    final dutyStart = DateTime(now.year, now.month, now.day, 7, 30);
    final dutyEnd = dutyStart.add(const Duration(hours: 24));
    final repository = OccurrenceRepository();
    await repository.load();
    await repository.importOccurrence(
      _reportOccurrence(
        id: 'occ_inside_duty',
        bo: 'IN-01/2026',
        startedAt: dutyStart.add(const Duration(hours: 1)),
      ),
    );
    await repository.importOccurrence(
      _reportOccurrence(
        id: 'occ_grace_duty',
        bo: 'GRACE-01/2026',
        startedAt: dutyEnd.add(const Duration(minutes: 90)),
      ),
    );
    await repository.importOccurrence(
      _reportOccurrence(
        id: 'occ_before_duty',
        bo: 'BEFORE-01/2026',
        startedAt: dutyStart.subtract(const Duration(hours: 1)),
      ),
    );
    await repository.importOccurrence(
      _reportOccurrence(
        id: 'occ_after_grace',
        bo: 'AFTER-01/2026',
        startedAt: dutyEnd.add(const Duration(hours: 3)),
      ),
    );

    final settingsRepository = await _settingsRepository();
    await tester.pumpWidget(
      SicroCampoApp(
        repository: repository,
        officialDocumentRepository: await _officialDocumentRepository(),
        settingsRepository: settingsRepository,
        dutyShiftRepository: await _dutyShiftRepository(),
      ),
    );

    await tester.tap(find.text('Gerar relatorio de plantao'));
    await tester.pumpAndSettle();

    expect(find.text('BO IN-01/2026'), findsOneWidget);
    expect(find.text('BO GRACE-01/2026'), findsOneWidget);
    expect(find.text('BO BEFORE-01/2026'), findsNothing);
    expect(find.text('BO AFTER-01/2026'), findsNothing);
    expect(find.text('Fora da janela (+2h)'), findsOneWidget);
    expect(
      find.textContaining('1 fora da janela, iniciada(s) ate 2h'),
      findsOneWidget,
    );
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
        officialDocumentRepository: await _officialDocumentRepository(),
        settingsRepository: settingsRepository,
        dutyShiftRepository: await _dutyShiftRepository(),
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

  testWidgets('marks traffic occurrence with official vehicle flag', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2600);
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
        officialDocumentRepository: await _officialDocumentRepository(),
        settingsRepository: settingsRepository,
        dutyShiftRepository: await _dutyShiftRepository(),
      ),
    );

    await tester.tap(find.text('Iniciar pericia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Carro'));
    await tester.tap(find.text('Sem vitima'));
    await tester.tap(find.text('Carro oficial envolvido'));
    await tester.enterText(find.bySemanticsLabel('BO'), 'OF-01/2026');
    await tester.tap(find.text('Criar ocorrencia'));
    await tester.pumpAndSettle();

    final metadata = repository.occurrences.first.metadata;
    expect(metadata.officialVehicleInvolved, isTrue);
    expect(
      find.text('Transito - Colisao - Carro - Carro oficial - Sem vitima'),
      findsOneWidget,
    );
  });

  testWidgets('creates local crime occurrence from setup flow', (
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
        officialDocumentRepository: await _officialDocumentRepository(),
        settingsRepository: settingsRepository,
        dutyShiftRepository: await _dutyShiftRepository(),
      ),
    );

    await tester.tap(find.text('Iniciar pericia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Local de crime'));
    await tester.pumpAndSettle();
    expect(find.text('Transito'), findsWidgets);
    expect(find.text('Local de crime'), findsWidgets);
    await tester.tap(find.text('Configurar local de crime'));
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
        'Local de crime - Morte suspeita - Corpo presente no local - 1 vitima - Via publica',
      ),
      findsOneWidget,
    );
    expect(find.text('Checklist de local de crime'), findsWidgets);
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
        officialDocumentRepository: await _officialDocumentRepository(),
        settingsRepository: settingsRepository,
        dutyShiftRepository: await _dutyShiftRepository(),
      ),
    );

    await tester.tap(find.text('Iniciar pericia'));
    await tester.pumpAndSettle();
    expect(find.text('Transito'), findsWidgets);
    expect(find.text('Local de crime'), findsOneWidget);
    expect(find.text('Patrimonio'), findsOneWidget);
    expect(find.text('Ambiental'), findsOneWidget);
    expect(find.text('Balistica Forense'), findsOneWidget);
    expect(find.text('Audio e Imagem'), findsOneWidget);
    expect(find.text('Papiloscopia'), findsOneWidget);

    await tester.tap(find.text('Local de crime'));
    await tester.pumpAndSettle();
    expect(find.text('Transito'), findsWidgets);
    expect(find.text('Local de crime'), findsWidgets);
    expect(find.text('Patrimonio'), findsOneWidget);
    expect(find.text('Ambiental'), findsOneWidget);
    expect(find.text('Balistica Forense'), findsOneWidget);
    expect(find.text('Audio e Imagem'), findsOneWidget);
    expect(find.text('Papiloscopia'), findsOneWidget);
    expect(find.text('Configurar local de crime'), findsOneWidget);

    await tester.tap(find.text('Patrimonio'));
    await tester.pumpAndSettle();
    expect(find.text('Transito'), findsWidgets);
    expect(find.text('Local de crime'), findsOneWidget);
    expect(find.text('Patrimonio'), findsWidgets);
    expect(find.text('Ambiental'), findsOneWidget);
    expect(find.text('Balistica Forense'), findsOneWidget);
    expect(find.text('Audio e Imagem'), findsOneWidget);
    expect(find.text('Papiloscopia'), findsOneWidget);
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
        officialDocumentRepository: await _officialDocumentRepository(),
        settingsRepository: settingsRepository,
        dutyShiftRepository: await _dutyShiftRepository(),
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

  testWidgets('creates environmental occurrence from POP-guided setup flow', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 4200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repository = OccurrenceRepository();
    await repository.load();
    final settingsRepository = await _settingsRepository(
      activeAreas: const [ForensicArea.traffic, ForensicArea.environmental],
    );
    await tester.pumpWidget(
      SicroCampoApp(
        repository: repository,
        officialDocumentRepository: await _officialDocumentRepository(),
        settingsRepository: settingsRepository,
        dutyShiftRepository: await _dutyShiftRepository(),
      ),
    );

    await tester.tap(find.text('Iniciar pericia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ambiental'));
    await tester.pumpAndSettle();
    expect(find.text('Transito'), findsWidgets);
    expect(find.text('Ambiental'), findsWidgets);
    expect(find.text('Configurar ambiental'), findsOneWidget);

    await tester.tap(find.text('Configurar ambiental'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Poluicao hidrica'));
    await tester.enterText(find.bySemanticsLabel('BO'), 'AMB-01/2026');
    await tester.tap(find.text('Criar ocorrencia'));
    await tester.pumpAndSettle();

    final metadata = repository.occurrences.first.metadata;
    expect(find.text('Dossie operacional'), findsOneWidget);
    expect(find.text('BO AMB-01/2026'), findsOneWidget);
    expect(
      find.text('Pericia ambiental - Poluicao hidrica - Corpo hidrico'),
      findsOneWidget,
    );
    expect(find.text('Checklist ambiental'), findsWidgets);
    expect(find.text('Vestigios ambientais'), findsWidgets);
    expect(find.text('Vitimas'), findsNothing);
    expect(find.text('Veiculos'), findsNothing);
    expect(metadata.type, ForensicCaseType.environmental);
    expect(metadata.environmentalNature, EnvironmentalNature.waterPollution);
    expect(metadata.environmentalContext, EnvironmentalSceneContext.waterBody);
    expect(metadata.expectedEnvironmentalEvidences, [
      ExpectedEnvironmentalEvidence.waterBodyImpact,
      ExpectedEnvironmentalEvidence.effluentContaminant,
      ExpectedEnvironmentalEvidence.samples,
      ExpectedEnvironmentalEvidence.protectedAreaImpact,
    ]);
  });

  testWidgets('creates ballistics occurrence from POP-guided setup flow', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 5200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repository = OccurrenceRepository();
    await repository.load();
    final settingsRepository = await _settingsRepository(
      activeAreas: const [ForensicArea.traffic, ForensicArea.ballistics],
    );
    await tester.pumpWidget(
      SicroCampoApp(
        repository: repository,
        officialDocumentRepository: await _officialDocumentRepository(),
        settingsRepository: settingsRepository,
        dutyShiftRepository: await _dutyShiftRepository(),
      ),
    );

    await tester.tap(find.text('Iniciar pericia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Balistica Forense'));
    await tester.pumpAndSettle();
    expect(find.text('Transito'), findsWidgets);
    expect(find.text('Balistica Forense'), findsWidgets);
    expect(find.text('Configurar balistica'), findsOneWidget);

    await tester.tap(find.text('Configurar balistica'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coleta GSR MEV/EDS'));
    await tester.pumpAndSettle();
    await tester.enterText(find.bySemanticsLabel('BO'), 'BAL-01/2026');
    await tester.ensureVisible(find.text('Criar ocorrencia'));
    await tester.tap(find.text('Criar ocorrencia'));
    await tester.pumpAndSettle();

    final metadata = repository.occurrences.first.metadata;
    expect(find.text('Dossie operacional'), findsOneWidget);
    expect(find.text('BO BAL-01/2026'), findsOneWidget);
    expect(
      find.text('Balistica Forense - Coleta GSR MEV/EDS - Pessoa suspeita'),
      findsOneWidget,
    );
    expect(find.text('Checklist de balistica'), findsWidgets);
    expect(find.text('Material balistico'), findsWidgets);
    expect(find.text('Vitimas'), findsNothing);
    expect(find.text('Veiculos'), findsNothing);
    expect(metadata.type, ForensicCaseType.ballistics);
    expect(metadata.ballisticsNature, BallisticsNature.gsrCollection);
    expect(metadata.ballisticsContext, BallisticsContext.suspect);
    expect(metadata.expectedBallisticEvidences, [
      ExpectedBallisticEvidence.gsr,
      ExpectedBallisticEvidence.clothing,
      ExpectedBallisticEvidence.vehicleSurface,
      ExpectedBallisticEvidence.packagesSeals,
      ExpectedBallisticEvidence.documents,
    ]);
  });

  testWidgets('creates audio and image occurrence from POP-guided setup flow', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 5600);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repository = OccurrenceRepository();
    await repository.load();
    final settingsRepository = await _settingsRepository(
      activeAreas: const [ForensicArea.traffic, ForensicArea.audioImage],
    );
    await tester.pumpWidget(
      SicroCampoApp(
        repository: repository,
        officialDocumentRepository: await _officialDocumentRepository(),
        settingsRepository: settingsRepository,
        dutyShiftRepository: await _dutyShiftRepository(),
      ),
    );

    await tester.tap(find.text('Iniciar pericia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Audio e Imagem'));
    await tester.pumpAndSettle();
    expect(find.text('Transito'), findsWidgets);
    expect(find.text('Audio e Imagem'), findsWidgets);
    expect(find.text('Configurar audio/imagem'), findsOneWidget);

    await tester.tap(find.text('Configurar audio/imagem'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Preservacao/coleta de CFTV'));
    await tester.pumpAndSettle();
    await tester.enterText(find.bySemanticsLabel('BO'), 'AI-01/2026');
    await tester.ensureVisible(find.text('Criar ocorrencia'));
    await tester.tap(find.text('Criar ocorrencia'));
    await tester.pumpAndSettle();

    final metadata = repository.occurrences.first.metadata;
    expect(find.text('Dossie operacional'), findsOneWidget);
    expect(find.text('BO AI-01/2026'), findsOneWidget);
    expect(
      find.text('Audio e Imagem - Preservacao/coleta de CFTV - Sistema CFTV'),
      findsOneWidget,
    );
    expect(find.text('Checklist de audio e imagem'), findsWidgets);
    expect(find.text('Midias e arquivos'), findsWidgets);
    expect(find.text('Vitimas'), findsNothing);
    expect(find.text('Veiculos'), findsNothing);
    expect(metadata.type, ForensicCaseType.audioImage);
    expect(metadata.audioImageNature, AudioImageNature.cctvPreservation);
    expect(metadata.audioImageContext, AudioImageContext.cctvSystem);
    expect(metadata.expectedAudioImageEvidences, [
      ExpectedAudioImageEvidence.cctvDvrNvr,
      ExpectedAudioImageEvidence.cameraSystem,
      ExpectedAudioImageEvidence.storageDevice,
      ExpectedAudioImageEvidence.videos,
      ExpectedAudioImageEvidence.accessCredentials,
      ExpectedAudioImageEvidence.hashes,
    ]);
  });

  testWidgets('creates papiloscopy occurrence from POP-guided setup flow', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 6200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repository = OccurrenceRepository();
    await repository.load();
    final settingsRepository = await _settingsRepository(
      activeAreas: const [ForensicArea.traffic, ForensicArea.papiloscopy],
    );
    await tester.pumpWidget(
      SicroCampoApp(
        repository: repository,
        officialDocumentRepository: await _officialDocumentRepository(),
        settingsRepository: settingsRepository,
        dutyShiftRepository: await _dutyShiftRepository(),
      ),
    );

    await tester.tap(find.text('Iniciar pericia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Papiloscopia'));
    await tester.pumpAndSettle();
    expect(find.text('Transito'), findsWidgets);
    expect(find.text('Papiloscopia'), findsWidgets);
    expect(find.text('Configurar papiloscopia'), findsOneWidget);

    await tester.tap(find.text('Configurar papiloscopia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Levantamento em local de crime').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.bySemanticsLabel('BO'), 'PAP-01/2026');
    await tester.ensureVisible(find.text('Criar ocorrencia'));
    await tester.tap(find.text('Criar ocorrencia'));
    await tester.pumpAndSettle();

    final metadata = repository.occurrences.first.metadata;
    expect(find.text('Dossie operacional'), findsOneWidget);
    expect(find.text('BO PAP-01/2026'), findsOneWidget);
    expect(
      find.text(
        'Papiloscopia - Levantamento em local de crime - Local de crime',
      ),
      findsOneWidget,
    );
    expect(find.text('Checklist de papiloscopia'), findsWidgets);
    expect(find.text('Vestigios papiloscopicos'), findsWidgets);
    expect(find.text('Vitimas'), findsNothing);
    expect(find.text('Veiculos'), findsNothing);
    expect(metadata.type, ForensicCaseType.papiloscopy);
    expect(metadata.papiloscopyNature, PapiloscopyNature.crimeScenePrints);
    expect(metadata.papiloscopyContext, PapiloscopyContext.crimeScene);
    expect(metadata.expectedPapiloscopyEvidences, [
      ExpectedPapiloscopyEvidence.latentPrints,
      ExpectedPapiloscopyEvidence.patentPrints,
      ExpectedPapiloscopyEvidence.plasticPrints,
      ExpectedPapiloscopyEvidence.questionedObjects,
      ExpectedPapiloscopyEvidence.adhesiveLifts,
      ExpectedPapiloscopyEvidence.photographs,
    ]);
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
        officialDocumentRepository: await _officialDocumentRepository(),
        settingsRepository: settingsRepository,
        dutyShiftRepository: await _dutyShiftRepository(),
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
      find.text('0/29 respondidos - 9 obrigatorios pendentes'),
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

FieldOccurrence _reportOccurrence({
  required String id,
  required String bo,
  required DateTime startedAt,
}) {
  return FieldOccurrence(
    id: id,
    createdAt: startedAt,
    updatedAt: startedAt,
    startedAt: startedAt,
    metadata: const ForensicCaseMetadata(
      trafficNature: TrafficNature.collision,
    ),
    caseData: CaseData(
      bo: bo,
      municipality: 'Macapa',
      street: 'Av. Teste',
      arrivedAt: startedAt,
    ),
  );
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

Future<OfficialDocumentRepository> _officialDocumentRepository() async {
  final repository = OfficialDocumentRepository();
  await repository.load();
  return repository;
}

Future<DutyShiftRepository> _dutyShiftRepository() async {
  final repository = DutyShiftRepository();
  await repository.load();
  return repository;
}
