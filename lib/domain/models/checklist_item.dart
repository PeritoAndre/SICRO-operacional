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
  sketchSurvey('croqui_levantamento', 'Croqui / levantamento'),
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
  fire('incendio', 'Incendio'),
  environmentalPlanning('planejamento_ambiental', 'Planejamento ambiental'),
  environmentalScene('local_ambiental', 'Local ambiental'),
  environmentalDamage('dano_ambiental', 'Dano ambiental'),
  environmentalSamples('amostras_coleta', 'Amostras / coleta'),
  ballisticReceipt('recebimento_balistico', 'Recebimento / custodia'),
  ballisticSafety('seguranca_balistica', 'Seguranca balistica'),
  firearms('armas_fogo', 'Armas de fogo'),
  ammunition('municoes', 'Municoes'),
  gsrCollection('coleta_gsr', 'Coleta GSR'),
  ballisticComparison('confronto_balistico', 'Confronto balistico'),
  multimediaReceipt('recebimento_multimidia', 'Recebimento / custodia'),
  multimediaPreservation('preservacao_multimidia', 'Preservacao digital'),
  multimediaAdequacy('adequabilidade_multimidia', 'Adequabilidade'),
  multimediaProcessing('processamento_multimidia', 'Processamento'),
  cctvCollection('coleta_cftv', 'Coleta CFTV'),
  facialComparison('comparacao_facial', 'Comparacao facial'),
  speakerComparison('comparacao_locutor', 'Comparacao de locutor'),
  imageAuthenticity('autenticidade_imagem', 'Verificacao de edicao'),
  papiloscopyBiosafety('biosseguranca_papiloscopia', 'Biosseguranca'),
  papiloscopyCollection('coleta_papiloscopica', 'Coleta papiloscopica'),
  papiloscopyDevelopment('revelacao_papiloscopica', 'Revelacao papiloscopica'),
  papiloscopyIdentification(
    'identificacao_papiloscopica',
    'Identificacao papiloscopica',
  ),
  papiloscopyLab('laboratorio_papiloscopia', 'Laboratorio'),
  papiloscopyNecro('necropapiloscopia', 'Necropapiloscopia'),
  chainOfCustody('cadeia_custodia', 'Cadeia de custodia');

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
  if (id.contains('amb_planejamento') ||
      id.contains('ambiental_planejamento') ||
      id.contains('documental_ambiental')) {
    return ChecklistCategory.environmentalPlanning;
  }
  if (id.contains('amb_local') ||
      id.contains('corpo_hidrico') ||
      id.contains('bioma') ||
      id.contains('app') ||
      id.contains('uc') ||
      id.contains('rl')) {
    return ChecklistCategory.environmentalScene;
  }
  if (id.contains('amb_dano') ||
      id.contains('desmatamento') ||
      id.contains('poluicao') ||
      id.contains('maus_tratos') ||
      id.contains('necropsia') ||
      id.contains('supressao')) {
    return ChecklistCategory.environmentalDamage;
  }
  if (id.contains('ai_recebimento') || id.contains('ai_documento')) {
    return ChecklistCategory.multimediaReceipt;
  }
  if (id.contains('ai_preservacao') ||
      id.contains('ai_hash') ||
      id.contains('ai_clone')) {
    return ChecklistCategory.multimediaPreservation;
  }
  if (id.contains('ai_adequabilidade') ||
      id.contains('ai_viabilidade') ||
      id.contains('ai_original')) {
    return ChecklistCategory.multimediaAdequacy;
  }
  if (id.contains('ai_processamento') ||
      id.contains('ai_melhoramento') ||
      id.contains('ai_quadro') ||
      id.contains('ai_frame')) {
    return ChecklistCategory.multimediaProcessing;
  }
  if (id.contains('ai_cftv') ||
      id.contains('ai_dvr') ||
      id.contains('ai_nvr')) {
    return ChecklistCategory.cctvCollection;
  }
  if (id.contains('ai_facial') || id.contains('ai_face')) {
    return ChecklistCategory.facialComparison;
  }
  if (id.contains('ai_locutor') || id.contains('ai_vocal')) {
    return ChecklistCategory.speakerComparison;
  }
  if (id.contains('ai_edicao') || id.contains('ai_autenticidade')) {
    return ChecklistCategory.imageAuthenticity;
  }
  if (id.contains('pap_biosseguranca') ||
      id.contains('pap_epi') ||
      id.contains('pap_seguranca')) {
    return ChecklistCategory.papiloscopyBiosafety;
  }
  if (id.contains('pap_coleta') ||
      id.contains('pap_datilograma') ||
      id.contains('pap_palmar') ||
      id.contains('pap_live_scan') ||
      id.contains('pap_entintamento')) {
    return ChecklistCategory.papiloscopyCollection;
  }
  if (id.contains('pap_revelacao') ||
      id.contains('pap_latente') ||
      id.contains('pap_decalque') ||
      id.contains('pap_suporte')) {
    return ChecklistCategory.papiloscopyDevelopment;
  }
  if (id.contains('pap_identificacao') ||
      id.contains('pap_afis') ||
      id.contains('pap_abis') ||
      id.contains('pap_confronto')) {
    return ChecklistCategory.papiloscopyIdentification;
  }
  if (id.contains('pap_laboratorio') ||
      id.contains('pap_reagente') ||
      id.contains('pap_fispq')) {
    return ChecklistCategory.papiloscopyLab;
  }
  if (id.contains('pap_necro') ||
      id.contains('pap_cadaver') ||
      id.contains('pap_falange')) {
    return ChecklistCategory.papiloscopyNecro;
  }
  if (id.contains('amostra') || id.contains('coleta')) {
    return ChecklistCategory.environmentalSamples;
  }
  if (id.contains('bal_recebimento') || id.contains('bal_documento')) {
    return ChecklistCategory.ballisticReceipt;
  }
  if (id.contains('bal_seguranca') || id.contains('bal_epi')) {
    return ChecklistCategory.ballisticSafety;
  }
  if (id.contains('bal_arma')) {
    return ChecklistCategory.firearms;
  }
  if (id.contains('bal_cartucho') || id.contains('bal_municao')) {
    return ChecklistCategory.ammunition;
  }
  if (id.contains('bal_gsr')) {
    return ChecklistCategory.gsrCollection;
  }
  if (id.contains('bal_confronto') || id.contains('bal_padrao')) {
    return ChecklistCategory.ballisticComparison;
  }
  if (id.contains('cadeia_custodia') || id.contains('lacrado')) {
    return ChecklistCategory.chainOfCustody;
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
