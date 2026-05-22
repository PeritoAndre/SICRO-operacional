enum ChecklistAnswer {
  unchecked('nao_verificado', 'Nao verificado'),
  yes('sim', 'Sim'),
  no('nao', 'Nao'),
  notApplicable('nao_se_aplica', 'Nao se aplica');

  const ChecklistAnswer(this.code, this.label);

  final String code;
  final String label;

  static ChecklistAnswer fromCode(Object? code) {
    for (final answer in values) {
      if (answer.code == code) {
        return answer;
      }
    }
    return ChecklistAnswer.unchecked;
  }
}

enum ChecklistCategory {
  preservation('preservacao', 'Preservacao / isolamento'),
  victims('vitimas', 'Vitimas'),
  vehicles('veiculos', 'Veiculos'),
  roadConditions('condicoes_via', 'Condicoes da via'),
  pavement('pavimento', 'Pavimento'),
  lighting('iluminacao', 'Iluminacao'),
  weatherVisibility('clima_visibilidade', 'Clima / visibilidade'),
  signaling('sinalizacao', 'Sinalizacao'),
  trafficLight('semaforo', 'Semaforo'),
  traces('vestigios', 'Vestigios'),
  bodyVictim('corpo_vitima', 'Corpo / vitima'),
  biologicalTraces('vestigios_biologicos', 'Vestigios biologicos'),
  ballisticTraces('vestigios_balisticos', 'Vestigios balisticos'),
  weaponsObjects('armas_objetos', 'Armas / objetos'),
  environment('ambiente', 'Ambiente'),
  photographicRecord('registro_fotografico', 'Registro fotografico'),
  propertyGoods('bens_avaliacao', 'Bens / avaliacao'),
  documentation('documentacao', 'Documentacao'),
  damage('danos', 'Danos'),
  burglary('arrombamento', 'Arrombamento'),
  fire('incendio', 'Incendio');

  const ChecklistCategory(this.code, this.label);

  final String code;
  final String label;

  static ChecklistCategory fromCode(Object? code) {
    for (final category in values) {
      if (category.code == code) {
        return category;
      }
    }
    return ChecklistCategory.preservation;
  }
}

enum ChecklistItemOrigin {
  base('base', 'Base institucional'),
  added('adicionado', 'Adicionado na ocorrencia');

  const ChecklistItemOrigin(this.code, this.label);

  final String code;
  final String label;

  static ChecklistItemOrigin fromCode(Object? code) {
    for (final origin in values) {
      if (origin.code == code) {
        return origin;
      }
    }
    return ChecklistItemOrigin.base;
  }
}

class ChecklistItem {
  const ChecklistItem({
    required this.id,
    required this.category,
    required this.question,
    this.required = false,
    this.answer = ChecklistAnswer.unchecked,
    this.note = '',
    this.defaultNote = '',
    this.origin = ChecklistItemOrigin.base,
  });

  final String id;
  final ChecklistCategory category;
  final String question;
  final bool required;
  final ChecklistAnswer answer;
  final String note;
  final String defaultNote;
  final ChecklistItemOrigin origin;

  ChecklistItem copyWith({
    ChecklistCategory? category,
    String? question,
    bool? required,
    ChecklistAnswer? answer,
    String? note,
    String? defaultNote,
    ChecklistItemOrigin? origin,
  }) {
    return ChecklistItem(
      id: id,
      category: category ?? this.category,
      question: question ?? this.question,
      required: required ?? this.required,
      answer: answer ?? this.answer,
      note: note ?? this.note,
      defaultNote: defaultNote ?? this.defaultNote,
      origin: origin ?? this.origin,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'categoria': category.code,
      'pergunta': question,
      'obrigatorio': required,
      'resposta': answer.code,
      'observacao': note,
      'observacao_padrao': defaultNote,
      'origem': origin.code,
    };
  }

  factory ChecklistItem.fromJson(Map<String, Object?> json) {
    final id = _string(json['id']);
    return ChecklistItem(
      id: id,
      category: json.containsKey('categoria')
          ? ChecklistCategory.fromCode(json['categoria'])
          : _categoryFromLegacyId(id),
      question: _string(json['pergunta']),
      required: json['obrigatorio'] == true,
      answer: ChecklistAnswer.fromCode(json['resposta']),
      note: _string(json['observacao']),
      defaultNote: _string(json['observacao_padrao']),
      origin: ChecklistItemOrigin.fromCode(json['origem']),
    );
  }
}

String _string(Object? value) => value is String ? value : '';

ChecklistCategory _categoryFromLegacyId(String id) {
  if (id.contains('vitima')) {
    return ChecklistCategory.victims;
  }
  if (id.contains('corpo') || id.contains('lesao') || id.contains('livor')) {
    return ChecklistCategory.bodyVictim;
  }
  if (id.contains('biologico') || id.contains('sangue')) {
    return ChecklistCategory.biologicalTraces;
  }
  if (id.contains('capsula') ||
      id.contains('estojo') ||
      id.contains('projetil') ||
      id.contains('balistico')) {
    return ChecklistCategory.ballisticTraces;
  }
  if (id.contains('arma') || id.contains('objeto')) {
    return ChecklistCategory.weaponsObjects;
  }
  if (id.contains('foto')) {
    return ChecklistCategory.photographicRecord;
  }
  if (id.contains('avaliacao') || id.contains('bem')) {
    return ChecklistCategory.propertyGoods;
  }
  if (id.contains('documento')) {
    return ChecklistCategory.documentation;
  }
  if (id.contains('dano')) {
    return ChecklistCategory.damage;
  }
  if (id.contains('arrombamento') ||
      id.contains('fechadura') ||
      id.contains('porta') ||
      id.contains('janela')) {
    return ChecklistCategory.burglary;
  }
  if (id.contains('incendio') ||
      id.contains('queima') ||
      id.contains('fuligem')) {
    return ChecklistCategory.fire;
  }
  if (id.contains('veiculo')) {
    return ChecklistCategory.vehicles;
  }
  if (id.contains('pavimento')) {
    return ChecklistCategory.pavement;
  }
  if (id.contains('iluminacao')) {
    return ChecklistCategory.lighting;
  }
  if (id.contains('semaforo')) {
    return ChecklistCategory.trafficLight;
  }
  if (id.contains('sinalizacao')) {
    return ChecklistCategory.signaling;
  }
  if (id.contains('frenagem') ||
      id.contains('arrasto') ||
      id.contains('fragmento') ||
      id.contains('vestigio')) {
    return ChecklistCategory.traces;
  }
  return ChecklistCategory.preservation;
}
