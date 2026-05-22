enum ForensicCaseType {
  traffic('transito', 'Transito'),
  violentDeath('morte_violenta', 'Morte violenta'),
  property('patrimonio', 'Patrimonio');

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

class ForensicCaseMetadata {
  const ForensicCaseMetadata({
    this.type = ForensicCaseType.traffic,
    this.trafficNature,
    this.trafficInvolved = const [],
    this.result = OccurrenceResult.notInformed,
    this.violentDeathNature,
    this.bodyState = BodyState.notInformed,
    this.victimCount = VictimCount.notInformed,
    this.sceneEnvironment = SceneEnvironment.residence,
    this.expectedViolentDeathTraces = const [],
    this.propertyNature,
  });

  final ForensicCaseType type;
  final TrafficNature? trafficNature;
  final List<TrafficInvolved> trafficInvolved;
  final OccurrenceResult result;
  final ViolentDeathNature? violentDeathNature;
  final BodyState bodyState;
  final VictimCount victimCount;
  final SceneEnvironment sceneEnvironment;
  final List<ExpectedViolentDeathTrace> expectedViolentDeathTraces;
  final PropertyNature? propertyNature;

  String? get primaryNatureCode {
    return switch (type) {
      ForensicCaseType.traffic => trafficNature?.code,
      ForensicCaseType.violentDeath => violentDeathNature?.code,
      ForensicCaseType.property => propertyNature?.code,
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

    final parts = <String>[type.label];
    if (trafficNature != null) {
      parts.add(trafficNature!.label);
    }
    if (trafficInvolved.isNotEmpty) {
      parts.add(trafficInvolved.map((item) => item.label).join(' x '));
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
    OccurrenceResult? result,
    ViolentDeathNature? violentDeathNature,
    BodyState? bodyState,
    VictimCount? victimCount,
    SceneEnvironment? sceneEnvironment,
    List<ExpectedViolentDeathTrace>? expectedViolentDeathTraces,
    PropertyNature? propertyNature,
  }) {
    return ForensicCaseMetadata(
      type: type ?? this.type,
      trafficNature: trafficNature ?? this.trafficNature,
      trafficInvolved: _normalizedInvolved(
        trafficInvolved ?? this.trafficInvolved,
      ),
      result: result ?? this.result,
      violentDeathNature: violentDeathNature ?? this.violentDeathNature,
      bodyState: bodyState ?? this.bodyState,
      victimCount: victimCount ?? this.victimCount,
      sceneEnvironment: sceneEnvironment ?? this.sceneEnvironment,
      expectedViolentDeathTraces: _normalizedViolentDeathTraces(
        expectedViolentDeathTraces ?? this.expectedViolentDeathTraces,
      ),
      propertyNature: propertyNature ?? this.propertyNature,
    );
  }

  Map<String, Object?> toJson() {
    final json = <String, Object?>{
      'tipo_pericia': type.code,
      'natureza': primaryNatureCode,
      'envolvidos': trafficInvolved.map((item) => item.code).toList(),
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
    return ForensicCaseMetadata(
      type: type,
      trafficNature: type == ForensicCaseType.traffic
          ? TrafficNature.fromCode(json['natureza'])
          : null,
      trafficInvolved: _normalizedInvolved(involved),
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
