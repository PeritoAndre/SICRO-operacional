enum ForensicCaseType {
  traffic('transito', 'Transito'),
  violentDeath('morte_violenta', 'Local de crime'),
  property('patrimonio', 'Patrimonio'),
  environmental('ambiental', 'Ambiental'),
  ballistics('balistica_forense', 'Balistica Forense'),
  audioImage('audio_imagem', 'Audio e Imagem'),
  papiloscopy('papiloscopia', 'Papiloscopia');

  const ForensicCaseType(this.code, this.label);

  final String code;
  final String label;

  static ForensicCaseType fromCode(Object? code) {
    for (final type in values) {
      if (type.code == code) {
        return type;
      }
    }
    return ForensicCaseType.traffic;
  }
}

enum TrafficNature {
  collision('colisao', 'Colisao'),
  rollover('capotamento', 'Capotamento'),
  tipping('tombamento', 'Tombamento'),
  runOffRoad('saida_pista', 'Saida de pista'),
  fixedObjectCrash('choque_objeto_fixo', 'Choque contra objeto fixo'),
  vehicleFire('incendio_veicular', 'Incendio veicular'),
  cargoSpill('derramamento_carga', 'Derramamento de carga'),
  other('outro', 'Outro');

  const TrafficNature(this.code, this.label);

  final String code;
  final String label;

  static TrafficNature? fromCode(Object? code) {
    for (final nature in values) {
      if (nature.code == code) {
        return nature;
      }
    }
    return null;
  }
}

enum TrafficInvolved {
  car('carro', 'Carro'),
  motorcycle('moto', 'Moto'),
  bicycle('bicicleta', 'Bicicleta'),
  truck('caminhao', 'Caminhao'),
  bus('onibus', 'Onibus'),
  pedestrian('pedestre', 'Pedestre'),
  fixedObject('objeto_fixo', 'Objeto fixo'),
  animal('animal', 'Animal'),
  other('outro', 'Outro');

  const TrafficInvolved(this.code, this.label);

  final String code;
  final String label;

  static TrafficInvolved fromCode(Object? code) {
    for (final involved in values) {
      if (involved.code == code) {
        return involved;
      }
    }
    return TrafficInvolved.other;
  }
}

enum OccurrenceResult {
  noVictim('sem_vitima', 'Sem vitima'),
  injuredVictim('vitima_lesionada', 'Com vitima lesionada'),
  fatalVictim('vitima_fatal', 'Com vitima fatal'),
  multipleVictims('multiplas_vitimas', 'Multiplas vitimas'),
  notInformed('nao_informado', 'Nao informado');

  const OccurrenceResult(this.code, this.label);

  final String code;
  final String label;

  static OccurrenceResult fromCode(Object? code) {
    for (final result in values) {
      if (result.code == code) {
        return result;
      }
    }
    return OccurrenceResult.notInformed;
  }
}

enum ViolentDeathNature {
  homicide('homicidio', 'Homicidio'),
  suicide('suicidio', 'Suicidio'),
  suspiciousDeath('morte_suspeita', 'Morte suspeita'),
  bodyFound('cadaver_encontrado', 'Cadaver encontrado'),
  bonesHumanRemains('ossada_restos_humanos', 'Ossada/restos humanos'),
  policeIntervention('intervencao_policial', 'Morte por intervencao policial'),
  bodyEncounter('encontro_cadaver', 'Encontro de cadaver'),
  biologicalTraceScene(
    'local_vestigio_biologico',
    'Local com vestigio biologico',
  ),
  other('outro', 'Outro');

  const ViolentDeathNature(this.code, this.label);

  final String code;
  final String label;

  static ViolentDeathNature? fromCode(Object? code) {
    for (final nature in values) {
      if (nature.code == code) {
        return nature;
      }
    }
    return null;
  }
}

enum BodyState {
  present('corpo_presente', 'Corpo presente no local'),
  removed('corpo_removido', 'Corpo removido antes da pericia'),
  partiallyPresent(
    'corpo_parcialmente_presente',
    'Corpo parcialmente presente',
  ),
  biologicalTracesOnly(
    'apenas_vestigios_biologicos',
    'Apenas vestigios biologicos',
  ),
  notInformed('nao_informado', 'Nao informado');

  const BodyState(this.code, this.label);

  final String code;
  final String label;

  static BodyState fromCode(Object? code) {
    for (final state in values) {
      if (state.code == code) {
        return state;
      }
    }
    return BodyState.notInformed;
  }
}

enum VictimCount {
  one('uma_vitima', '1 vitima'),
  two('duas_vitimas', '2 vitimas'),
  threeOrMore('tres_ou_mais', '3 ou mais'),
  notInformed('nao_informado', 'Nao informado');

  const VictimCount(this.code, this.label);

  final String code;
  final String label;

  static VictimCount fromCode(Object? code) {
    for (final count in values) {
      if (count.code == code) {
        return count;
      }
    }
    return VictimCount.notInformed;
  }
}

enum SceneEnvironment {
  residence('residencia', 'Residencia'),
  publicRoad('via_publica', 'Via publica'),
  forestArea('area_mata', 'Area de mata'),
  ruralRoad('area_rural_ramal', 'Area rural/ramal'),
  commercialPlace('estabelecimento_comercial', 'Estabelecimento comercial'),
  institutionalPlace('ambiente_institucional', 'Ambiente institucional'),
  vehicle('veiculo', 'Veiculo'),
  other('outro', 'Outro');

  const SceneEnvironment(this.code, this.label);

  final String code;
  final String label;

  static SceneEnvironment fromCode(Object? code) {
    for (final environment in values) {
      if (environment.code == code) {
        return environment;
      }
    }
    return SceneEnvironment.residence;
  }
}

enum ExpectedViolentDeathTrace {
  bloodBiologicalStain('sangue_mancha_biologica', 'Sangue/mancha biologica'),
  cases('capsulas_estojos', 'Capsulas/estojos'),
  projectiles('projeteis', 'Projeteis'),
  coldWeapon('arma_branca', 'Arma branca'),
  firearm('arma_fogo', 'Arma de fogo'),
  struggleSigns('sinais_luta', 'Sinais de luta'),
  dragging('arrastamento', 'Arrastamento'),
  footprints('pegadas', 'Pegadas'),
  displacedObjects('objetos_deslocados', 'Objetos deslocados'),
  clothesBelongings('vestes_pertences', 'Vestes/pertences'),
  other('outro', 'Outro');

  const ExpectedViolentDeathTrace(this.code, this.label);

  final String code;
  final String label;

  static ExpectedViolentDeathTrace fromCode(Object? code) {
    for (final trace in values) {
      if (trace.code == code) {
        return trace;
      }
    }
    return ExpectedViolentDeathTrace.other;
  }
}

enum PropertyNature {
  directEvaluation('avaliacao_direta', 'Avaliacao direta'),
  indirectEvaluation('avaliacao_indireta', 'Avaliacao indireta'),
  damages('danos', 'Danos'),
  burglary('arrombamento', 'Arrombamento'),
  fire('incendio', 'Incendio');

  const PropertyNature(this.code, this.label);

  final String code;
  final String label;

  static PropertyNature? fromCode(Object? code) {
    for (final nature in values) {
      if (nature.code == code) {
        return nature;
      }
    }
    return null;
  }
}

enum EnvironmentalNature {
  deforestation('desmatamento', 'Desmatamento'),
  animalAbuse('maus_tratos_animais', 'Maus-tratos/crueldade/abuso a animais'),
  waterPollution('poluicao_hidrica', 'Poluicao hidrica'),
  forestFire('incendio_florestal', 'Incendio florestal'),
  veterinaryNecropsy(
    'necropsia_veterinaria',
    'Necropsia forense medico-veterinaria',
  ),
  other('outro', 'Outro');

  const EnvironmentalNature(this.code, this.label);

  final String code;
  final String label;

  static EnvironmentalNature? fromCode(Object? code) {
    for (final nature in values) {
      if (nature.code == code) {
        return nature;
      }
    }
    return null;
  }
}

enum EnvironmentalSceneContext {
  ruralArea('area_rural', 'Area rural'),
  urbanArea('area_urbana', 'Area urbana'),
  forestArea('area_mata', 'Area de mata/floresta'),
  waterBody('corpo_hidrico', 'Corpo hidrico'),
  protectedArea('area_protegida', 'APP/RL/UC/area protegida'),
  enterprise('empreendimento', 'Empreendimento/industria'),
  veterinaryFacility('ambiente_veterinario', 'Ambiente veterinario'),
  other('outro', 'Outro');

  const EnvironmentalSceneContext(this.code, this.label);

  final String code;
  final String label;

  static EnvironmentalSceneContext fromCode(Object? code) {
    for (final context in values) {
      if (context.code == code) {
        return context;
      }
    }
    return EnvironmentalSceneContext.ruralArea;
  }
}

enum ExpectedEnvironmentalEvidence {
  vegetationSuppression('supressao_vegetal', 'Supressao vegetal'),
  protectedAreaImpact('area_protegida_atingida', 'Area protegida atingida'),
  waterBodyImpact('corpo_hidrico_atingido', 'Corpo hidrico atingido'),
  effluentContaminant('efluente_contaminante', 'Efluente/contaminante'),
  animalCondition('condicao_animal', 'Condicao animal'),
  animalCadaver('cadaver_animal', 'Cadaver animal'),
  biologicalMaterial('material_biologico', 'Material biologico'),
  fireIndicators('indicadores_queima', 'Indicadores de queima'),
  samples('amostras', 'Amostras/coletas'),
  documents('documentos_licencas', 'Documentos/licencas'),
  other('outro', 'Outro');

  const ExpectedEnvironmentalEvidence(this.code, this.label);

  final String code;
  final String label;

  static ExpectedEnvironmentalEvidence fromCode(Object? code) {
    for (final evidence in values) {
      if (evidence.code == code) {
        return evidence;
      }
    }
    return ExpectedEnvironmentalEvidence.other;
  }
}

enum BallisticsNature {
  ballisticComparison('confronto_balistico', 'Confronto balistico'),
  gsrCollection('coleta_gsr_mev_eds', 'Coleta GSR MEV/EDS'),
  firearmEfficiency('eficiencia_arma_fogo', 'Eficiencia em arma de fogo'),
  ammunitionEfficiency(
    'eficiencia_cartuchos',
    'Eficiencia em cartuchos de municao',
  ),
  other('outro', 'Outro');

  const BallisticsNature(this.code, this.label);

  final String code;
  final String label;

  static BallisticsNature? fromCode(Object? code) {
    for (final nature in values) {
      if (nature.code == code) {
        return nature;
      }
    }
    return null;
  }
}

enum BallisticsContext {
  lab('laboratorio', 'Laboratorio'),
  crimeScene('local_crime', 'Local de crime'),
  vehicle('veiculo', 'Veiculo'),
  suspect('pessoa_suspeita', 'Pessoa suspeita'),
  cadaver('cadaver', 'Cadaver'),
  seizedMaterial('material_apreendido', 'Material apreendido'),
  other('outro', 'Outro');

  const BallisticsContext(this.code, this.label);

  final String code;
  final String label;

  static BallisticsContext fromCode(Object? code) {
    for (final context in values) {
      if (context.code == code) {
        return context;
      }
    }
    return BallisticsContext.seizedMaterial;
  }
}

enum ExpectedBallisticEvidence {
  firearm('arma_fogo', 'Arma de fogo'),
  ammunition('municao_cartuchos', 'Municao/cartuchos'),
  cases('capsulas_estojos', 'Capsulas/estojos'),
  projectiles('projeteis', 'Projeteis'),
  ballisticStandards('padroes_balisticos', 'Padroes balisticos'),
  gsr('residuo_tiro_gsr', 'Residuo de tiro/GSR'),
  clothing('vestes', 'Vestes'),
  vehicleSurface('superficie_veiculo_local', 'Superficie veiculo/local'),
  packagesSeals('embalagens_lacres', 'Embalagens/lacres'),
  documents('documentos_requisicao', 'Documentos/requisicao'),
  other('outro', 'Outro');

  const ExpectedBallisticEvidence(this.code, this.label);

  final String code;
  final String label;

  static ExpectedBallisticEvidence fromCode(Object? code) {
    for (final evidence in values) {
      if (evidence.code == code) {
        return evidence;
      }
    }
    return ExpectedBallisticEvidence.other;
  }
}

enum AudioImageNature {
  contentAnalysis('analise_conteudo_imagem', 'Analise de conteudo em imagens'),
  imageEnhancement('melhoramento_imagem', 'Melhoramento de imagens'),
  imageRecognition('reconhecimento_imagem', 'Reconhecimento por imagem'),
  facialComparison('comparacao_facial', 'Comparacao de imagens faciais'),
  imageEditVerification(
    'verificacao_edicao_imagem',
    'Verificacao de edicao em imagens',
  ),
  speakerComparison('comparacao_locutor', 'Comparacao de locutor'),
  cctvPreservation('preservacao_cftv', 'Preservacao/coleta de CFTV'),
  statureEstimation('estimativa_estatura', 'Estimativa de estatura'),
  other('outro', 'Outro');

  const AudioImageNature(this.code, this.label);

  final String code;
  final String label;

  static AudioImageNature? fromCode(Object? code) {
    for (final nature in values) {
      if (nature.code == code) {
        return nature;
      }
    }
    return null;
  }
}

enum AudioImageContext {
  lab('laboratorio', 'Laboratorio'),
  crimeScene('local_crime', 'Local de crime'),
  cctvSystem('sistema_cftv', 'Sistema CFTV'),
  digitalMedia('midia_digital', 'Midia digital'),
  mobileDevice('dispositivo_movel', 'Dispositivo movel'),
  internetContent('conteudo_internet', 'Conteudo de internet'),
  personSample('padrao_pessoa', 'Padrao de pessoa/locutor'),
  other('outro', 'Outro');

  const AudioImageContext(this.code, this.label);

  final String code;
  final String label;

  static AudioImageContext fromCode(Object? code) {
    for (final context in values) {
      if (context.code == code) {
        return context;
      }
    }
    return AudioImageContext.digitalMedia;
  }
}

enum ExpectedAudioImageEvidence {
  originalMedia('midia_original', 'Midia original'),
  multimediaFiles('arquivos_multimidia', 'Arquivos multimidia'),
  images('imagens', 'Imagens'),
  videos('videos', 'Videos'),
  audioRecords('audios', 'Audios'),
  cctvDvrNvr('dvr_nvr_cftv', 'DVR/NVR/CFTV'),
  storageDevice('dispositivo_armazenamento', 'Dispositivo de armazenamento'),
  metadata('metadados', 'Metadados'),
  hashes('hashes', 'Hashes'),
  referenceMaterial('material_padrao', 'Material padrao'),
  vocalSample('padrao_vocal', 'Padrao vocal'),
  facialImages('imagens_faciais', 'Imagens faciais'),
  frames('quadros_frames', 'Quadros/frames'),
  accessCredentials('credenciais_acesso', 'Credenciais/acesso'),
  cameraSystem('sistema_camera', 'Sistema de cameras'),
  other('outro', 'Outro');

  const ExpectedAudioImageEvidence(this.code, this.label);

  final String code;
  final String label;

  static ExpectedAudioImageEvidence fromCode(Object? code) {
    for (final evidence in values) {
      if (evidence.code == code) {
        return evidence;
      }
    }
    return ExpectedAudioImageEvidence.other;
  }
}

enum PapiloscopyNature {
  criminalIdentification('identificacao_criminal', 'Identificacao criminal'),
  crimeScenePrints('levantamento_local', 'Levantamento em local de crime'),
  labPrints('levantamento_laboratorio', 'Levantamento em laboratorio'),
  necropapiloscopy(
    'identificacao_necropapiloscopica',
    'Identificacao necropapiloscopica',
  ),
  other('outro', 'Outro');

  const PapiloscopyNature(this.code, this.label);

  final String code;
  final String label;

  static PapiloscopyNature? fromCode(Object? code) {
    for (final nature in values) {
      if (nature.code == code) {
        return nature;
      }
    }
    return null;
  }
}

enum PapiloscopyContext {
  livingPerson('pessoa_viva', 'Pessoa viva'),
  crimeScene('local_crime', 'Local de crime'),
  lab('laboratorio', 'Laboratorio'),
  cadaver('cadaver', 'Cadaver'),
  objectSupport('objeto_suporte', 'Objeto/suporte'),
  document('documento', 'Documento'),
  other('outro', 'Outro');

  const PapiloscopyContext(this.code, this.label);

  final String code;
  final String label;

  static PapiloscopyContext fromCode(Object? code) {
    for (final context in values) {
      if (context.code == code) {
        return context;
      }
    }
    return PapiloscopyContext.crimeScene;
  }
}

enum ExpectedPapiloscopyEvidence {
  fingerprints('impressoes_digitais', 'Impressoes digitais'),
  palmprints('impressoes_palmares', 'Impressoes palmares'),
  latentPrints('impressao_latente', 'Impressao latente'),
  patentPrints('impressao_patente', 'Impressao patente'),
  plasticPrints('impressao_moldada', 'Impressao moldada'),
  biometricCapture('captura_biometrica', 'Captura biometrica'),
  questionedObjects('objetos_questionados', 'Objetos questionados'),
  adhesiveLifts('suportes_adesivos', 'Suportes adesivos'),
  photographs('fotografias', 'Fotografias'),
  afisAbis('afis_abis', 'AFIS/ABIS'),
  necropapillaryMaterial(
    'material_necropapiloscopico',
    'Material necropapiloscopico',
  ),
  chemicalReagents('reagentes_quimicos', 'Reagentes quimicos'),
  other('outro', 'Outro');

  const ExpectedPapiloscopyEvidence(this.code, this.label);

  final String code;
  final String label;

  static ExpectedPapiloscopyEvidence fromCode(Object? code) {
    for (final evidence in values) {
      if (evidence.code == code) {
        return evidence;
      }
    }
    return ExpectedPapiloscopyEvidence.other;
  }
}

class ForensicCaseMetadata {
  const ForensicCaseMetadata({
    this.type = ForensicCaseType.traffic,
    this.trafficNature,
    this.trafficInvolved = const [],
    this.officialVehicleInvolved = false,
    this.result = OccurrenceResult.notInformed,
    this.violentDeathNature,
    this.bodyState = BodyState.notInformed,
    this.victimCount = VictimCount.notInformed,
    this.sceneEnvironment = SceneEnvironment.residence,
    this.expectedViolentDeathTraces = const [],
    this.propertyNature,
    this.environmentalNature,
    this.environmentalContext = EnvironmentalSceneContext.ruralArea,
    this.expectedEnvironmentalEvidences = const [],
    this.ballisticsNature,
    this.ballisticsContext = BallisticsContext.seizedMaterial,
    this.expectedBallisticEvidences = const [],
    this.audioImageNature,
    this.audioImageContext = AudioImageContext.digitalMedia,
    this.expectedAudioImageEvidences = const [],
    this.papiloscopyNature,
    this.papiloscopyContext = PapiloscopyContext.crimeScene,
    this.expectedPapiloscopyEvidences = const [],
  });

  final ForensicCaseType type;
  final TrafficNature? trafficNature;
  final List<TrafficInvolved> trafficInvolved;
  final bool officialVehicleInvolved;
  final OccurrenceResult result;
  final ViolentDeathNature? violentDeathNature;
  final BodyState bodyState;
  final VictimCount victimCount;
  final SceneEnvironment sceneEnvironment;
  final List<ExpectedViolentDeathTrace> expectedViolentDeathTraces;
  final PropertyNature? propertyNature;
  final EnvironmentalNature? environmentalNature;
  final EnvironmentalSceneContext environmentalContext;
  final List<ExpectedEnvironmentalEvidence> expectedEnvironmentalEvidences;
  final BallisticsNature? ballisticsNature;
  final BallisticsContext ballisticsContext;
  final List<ExpectedBallisticEvidence> expectedBallisticEvidences;
  final AudioImageNature? audioImageNature;
  final AudioImageContext audioImageContext;
  final List<ExpectedAudioImageEvidence> expectedAudioImageEvidences;
  final PapiloscopyNature? papiloscopyNature;
  final PapiloscopyContext papiloscopyContext;
  final List<ExpectedPapiloscopyEvidence> expectedPapiloscopyEvidences;

  String? get primaryNatureCode {
    return switch (type) {
      ForensicCaseType.traffic => trafficNature?.code,
      ForensicCaseType.violentDeath => violentDeathNature?.code,
      ForensicCaseType.property => propertyNature?.code,
      ForensicCaseType.environmental => environmentalNature?.code,
      ForensicCaseType.ballistics => ballisticsNature?.code,
      ForensicCaseType.audioImage => audioImageNature?.code,
      ForensicCaseType.papiloscopy => papiloscopyNature?.code,
    };
  }

  String get summary {
    if (type == ForensicCaseType.violentDeath) {
      final parts = <String>[type.label];
      if (violentDeathNature != null) {
        parts.add(violentDeathNature!.label);
      }
      if (bodyState != BodyState.notInformed) {
        parts.add(bodyState.label);
      }
      if (victimCount != VictimCount.notInformed) {
        parts.add(victimCount.label);
      }
      parts.add(sceneEnvironment.label);
      return parts.join(' - ');
    }

    if (type == ForensicCaseType.property) {
      final parts = <String>[type.label];
      if (propertyNature != null) {
        parts.add(propertyNature!.label);
      }
      return parts.join(' - ');
    }

    if (type == ForensicCaseType.environmental) {
      final parts = <String>['Pericia ambiental'];
      if (environmentalNature != null) {
        parts.add(environmentalNature!.label);
      }
      parts.add(environmentalContext.label);
      return parts.join(' - ');
    }

    if (type == ForensicCaseType.ballistics) {
      final parts = <String>[type.label];
      if (ballisticsNature != null) {
        parts.add(ballisticsNature!.label);
      }
      parts.add(ballisticsContext.label);
      return parts.join(' - ');
    }

    if (type == ForensicCaseType.audioImage) {
      final parts = <String>[type.label];
      if (audioImageNature != null) {
        parts.add(audioImageNature!.label);
      }
      parts.add(audioImageContext.label);
      return parts.join(' - ');
    }

    if (type == ForensicCaseType.papiloscopy) {
      final parts = <String>[type.label];
      if (papiloscopyNature != null) {
        parts.add(papiloscopyNature!.label);
      }
      parts.add(papiloscopyContext.label);
      return parts.join(' - ');
    }

    final parts = <String>[type.label];
    if (trafficNature != null) {
      parts.add(trafficNature!.label);
    }
    if (trafficInvolved.isNotEmpty) {
      parts.add(trafficInvolved.map((item) => item.label).join(' x '));
    }
    if (officialVehicleInvolved) {
      parts.add('Carro oficial');
    }
    if (result != OccurrenceResult.notInformed) {
      parts.add(result.label);
    }
    return parts.join(' - ');
  }

  ForensicCaseMetadata copyWith({
    ForensicCaseType? type,
    TrafficNature? trafficNature,
    List<TrafficInvolved>? trafficInvolved,
    bool? officialVehicleInvolved,
    OccurrenceResult? result,
    ViolentDeathNature? violentDeathNature,
    BodyState? bodyState,
    VictimCount? victimCount,
    SceneEnvironment? sceneEnvironment,
    List<ExpectedViolentDeathTrace>? expectedViolentDeathTraces,
    PropertyNature? propertyNature,
    EnvironmentalNature? environmentalNature,
    EnvironmentalSceneContext? environmentalContext,
    List<ExpectedEnvironmentalEvidence>? expectedEnvironmentalEvidences,
    BallisticsNature? ballisticsNature,
    BallisticsContext? ballisticsContext,
    List<ExpectedBallisticEvidence>? expectedBallisticEvidences,
    AudioImageNature? audioImageNature,
    AudioImageContext? audioImageContext,
    List<ExpectedAudioImageEvidence>? expectedAudioImageEvidences,
    PapiloscopyNature? papiloscopyNature,
    PapiloscopyContext? papiloscopyContext,
    List<ExpectedPapiloscopyEvidence>? expectedPapiloscopyEvidences,
  }) {
    return ForensicCaseMetadata(
      type: type ?? this.type,
      trafficNature: trafficNature ?? this.trafficNature,
      trafficInvolved: _normalizedInvolved(
        trafficInvolved ?? this.trafficInvolved,
      ),
      officialVehicleInvolved:
          officialVehicleInvolved ?? this.officialVehicleInvolved,
      result: result ?? this.result,
      violentDeathNature: violentDeathNature ?? this.violentDeathNature,
      bodyState: bodyState ?? this.bodyState,
      victimCount: victimCount ?? this.victimCount,
      sceneEnvironment: sceneEnvironment ?? this.sceneEnvironment,
      expectedViolentDeathTraces: _normalizedViolentDeathTraces(
        expectedViolentDeathTraces ?? this.expectedViolentDeathTraces,
      ),
      propertyNature: propertyNature ?? this.propertyNature,
      environmentalNature: environmentalNature ?? this.environmentalNature,
      environmentalContext: environmentalContext ?? this.environmentalContext,
      expectedEnvironmentalEvidences: _normalizedEnvironmentalEvidences(
        expectedEnvironmentalEvidences ?? this.expectedEnvironmentalEvidences,
      ),
      ballisticsNature: ballisticsNature ?? this.ballisticsNature,
      ballisticsContext: ballisticsContext ?? this.ballisticsContext,
      expectedBallisticEvidences: _normalizedBallisticEvidences(
        expectedBallisticEvidences ?? this.expectedBallisticEvidences,
      ),
      audioImageNature: audioImageNature ?? this.audioImageNature,
      audioImageContext: audioImageContext ?? this.audioImageContext,
      expectedAudioImageEvidences: _normalizedAudioImageEvidences(
        expectedAudioImageEvidences ?? this.expectedAudioImageEvidences,
      ),
      papiloscopyNature: papiloscopyNature ?? this.papiloscopyNature,
      papiloscopyContext: papiloscopyContext ?? this.papiloscopyContext,
      expectedPapiloscopyEvidences: _normalizedPapiloscopyEvidences(
        expectedPapiloscopyEvidences ?? this.expectedPapiloscopyEvidences,
      ),
    );
  }

  Map<String, Object?> toJson() {
    final json = <String, Object?>{
      'tipo_pericia': type.code,
      'natureza': primaryNatureCode,
      'envolvidos': trafficInvolved.map((item) => item.code).toList(),
      'veiculo_oficial': officialVehicleInvolved,
      'resultado': result.code,
      'resumo': summary,
    };
    if (type == ForensicCaseType.violentDeath) {
      json['morte_violenta'] = {
        'natureza': violentDeathNature?.code,
        'estado_vitima_corpo': bodyState.code,
        'quantidade_vitimas': victimCount.code,
        'ambiente_local': sceneEnvironment.code,
        'vestigios_esperados': expectedViolentDeathTraces
            .map((item) => item.code)
            .toList(),
      };
    }
    if (type == ForensicCaseType.property) {
      json['patrimonio'] = {'natureza': propertyNature?.code};
    }
    if (type == ForensicCaseType.environmental) {
      json['ambiental'] = {
        'natureza': environmentalNature?.code,
        'contexto_local': environmentalContext.code,
        'vestigios_esperados': expectedEnvironmentalEvidences
            .map((item) => item.code)
            .toList(),
      };
    }
    if (type == ForensicCaseType.ballistics) {
      json['balistica_forense'] = {
        'natureza': ballisticsNature?.code,
        'contexto': ballisticsContext.code,
        'vestigios_esperados': expectedBallisticEvidences
            .map((item) => item.code)
            .toList(),
      };
    }
    if (type == ForensicCaseType.audioImage) {
      json['audio_imagem'] = {
        'natureza': audioImageNature?.code,
        'contexto': audioImageContext.code,
        'vestigios_esperados': expectedAudioImageEvidences
            .map((item) => item.code)
            .toList(),
      };
    }
    if (type == ForensicCaseType.papiloscopy) {
      json['papiloscopia'] = {
        'natureza': papiloscopyNature?.code,
        'contexto': papiloscopyContext.code,
        'vestigios_esperados': expectedPapiloscopyEvidences
            .map((item) => item.code)
            .toList(),
      };
    }
    return json;
  }

  factory ForensicCaseMetadata.fromJson(Map<String, Object?> json) {
    final type = ForensicCaseType.fromCode(json['tipo_pericia']);
    final rawInvolved = json['envolvidos'];
    final involved = rawInvolved is List
        ? rawInvolved.map(TrafficInvolved.fromCode).toList()
        : const <TrafficInvolved>[];
    final violentDeath = _map(json['morte_violenta']);
    final rawExpectedTraces = _list(violentDeath['vestigios_esperados']);
    final expectedTraces = rawExpectedTraces
        .map(ExpectedViolentDeathTrace.fromCode)
        .toList();
    final property = _map(json['patrimonio']);
    final environmental = _map(json['ambiental']);
    final rawEnvironmentalEvidences = _list(
      environmental['vestigios_esperados'],
    );
    final environmentalEvidences = rawEnvironmentalEvidences
        .map(ExpectedEnvironmentalEvidence.fromCode)
        .toList();
    final ballistics = _map(json['balistica_forense']);
    final rawBallisticEvidences = _list(ballistics['vestigios_esperados']);
    final ballisticEvidences = rawBallisticEvidences
        .map(ExpectedBallisticEvidence.fromCode)
        .toList();
    final audioImage = _map(json['audio_imagem']);
    final rawAudioImageEvidences = _list(audioImage['vestigios_esperados']);
    final audioImageEvidences = rawAudioImageEvidences
        .map(ExpectedAudioImageEvidence.fromCode)
        .toList();
    final papiloscopy = _map(json['papiloscopia']);
    final rawPapiloscopyEvidences = _list(papiloscopy['vestigios_esperados']);
    final papiloscopyEvidences = rawPapiloscopyEvidences
        .map(ExpectedPapiloscopyEvidence.fromCode)
        .toList();
    return ForensicCaseMetadata(
      type: type,
      trafficNature: type == ForensicCaseType.traffic
          ? TrafficNature.fromCode(json['natureza'])
          : null,
      trafficInvolved: _normalizedInvolved(involved),
      officialVehicleInvolved: _bool(json['veiculo_oficial']),
      result: OccurrenceResult.fromCode(json['resultado']),
      violentDeathNature: type == ForensicCaseType.violentDeath
          ? ViolentDeathNature.fromCode(
              violentDeath['natureza'] ?? json['natureza'],
            )
          : null,
      bodyState: BodyState.fromCode(violentDeath['estado_vitima_corpo']),
      victimCount: VictimCount.fromCode(violentDeath['quantidade_vitimas']),
      sceneEnvironment: SceneEnvironment.fromCode(
        violentDeath['ambiente_local'],
      ),
      expectedViolentDeathTraces: _normalizedViolentDeathTraces(expectedTraces),
      propertyNature: type == ForensicCaseType.property
          ? PropertyNature.fromCode(property['natureza'] ?? json['natureza'])
          : null,
      environmentalNature: type == ForensicCaseType.environmental
          ? EnvironmentalNature.fromCode(
              environmental['natureza'] ?? json['natureza'],
            )
          : null,
      environmentalContext: EnvironmentalSceneContext.fromCode(
        environmental['contexto_local'],
      ),
      expectedEnvironmentalEvidences: _normalizedEnvironmentalEvidences(
        environmentalEvidences,
      ),
      ballisticsNature: type == ForensicCaseType.ballistics
          ? BallisticsNature.fromCode(
              ballistics['natureza'] ?? json['natureza'],
            )
          : null,
      ballisticsContext: BallisticsContext.fromCode(ballistics['contexto']),
      expectedBallisticEvidences: _normalizedBallisticEvidences(
        ballisticEvidences,
      ),
      audioImageNature: type == ForensicCaseType.audioImage
          ? AudioImageNature.fromCode(
              audioImage['natureza'] ?? json['natureza'],
            )
          : null,
      audioImageContext: AudioImageContext.fromCode(audioImage['contexto']),
      expectedAudioImageEvidences: _normalizedAudioImageEvidences(
        audioImageEvidences,
      ),
      papiloscopyNature: type == ForensicCaseType.papiloscopy
          ? PapiloscopyNature.fromCode(
              papiloscopy['natureza'] ?? json['natureza'],
            )
          : null,
      papiloscopyContext: PapiloscopyContext.fromCode(papiloscopy['contexto']),
      expectedPapiloscopyEvidences: _normalizedPapiloscopyEvidences(
        papiloscopyEvidences,
      ),
    );
  }
}

List<TrafficInvolved> _normalizedInvolved(List<TrafficInvolved> involved) {
  final normalized = <TrafficInvolved>[];
  for (final item in involved) {
    if (!normalized.contains(item)) {
      normalized.add(item);
    }
  }
  return normalized;
}

List<ExpectedViolentDeathTrace> _normalizedViolentDeathTraces(
  List<ExpectedViolentDeathTrace> traces,
) {
  final normalized = <ExpectedViolentDeathTrace>[];
  for (final trace in traces) {
    if (!normalized.contains(trace)) {
      normalized.add(trace);
    }
  }
  return normalized;
}

List<ExpectedEnvironmentalEvidence> _normalizedEnvironmentalEvidences(
  List<ExpectedEnvironmentalEvidence> evidences,
) {
  final normalized = <ExpectedEnvironmentalEvidence>[];
  for (final evidence in evidences) {
    if (!normalized.contains(evidence)) {
      normalized.add(evidence);
    }
  }
  return normalized;
}

List<ExpectedBallisticEvidence> _normalizedBallisticEvidences(
  List<ExpectedBallisticEvidence> evidences,
) {
  final normalized = <ExpectedBallisticEvidence>[];
  for (final evidence in evidences) {
    if (!normalized.contains(evidence)) {
      normalized.add(evidence);
    }
  }
  return normalized;
}

List<ExpectedAudioImageEvidence> _normalizedAudioImageEvidences(
  List<ExpectedAudioImageEvidence> evidences,
) {
  final normalized = <ExpectedAudioImageEvidence>[];
  for (final evidence in evidences) {
    if (!normalized.contains(evidence)) {
      normalized.add(evidence);
    }
  }
  return normalized;
}

List<ExpectedPapiloscopyEvidence> _normalizedPapiloscopyEvidences(
  List<ExpectedPapiloscopyEvidence> evidences,
) {
  final normalized = <ExpectedPapiloscopyEvidence>[];
  for (final evidence in evidences) {
    if (!normalized.contains(evidence)) {
      normalized.add(evidence);
    }
  }
  return normalized;
}

Map<String, Object?> _map(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  return const {};
}

List<Object?> _list(Object? value) => value is List ? value : const [];

bool _bool(Object? value) => value == true;
