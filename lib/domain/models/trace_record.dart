enum TraceType {
  braking('frenagem', 'Frenagem'),
  drag('arrasto', 'Arrasto'),
  fragment('fragmento', 'Fragmento'),
  stain('mancha', 'Mancha'),
  furrow('sulco', 'Sulco'),
  tire('pneu', 'Pneu'),
  fluid('fluido', 'Fluido'),
  detachedPart('peca_desprendida', 'Peca desprendida'),
  blood('sangue', 'Sangue'),
  biological('vestigio_biologico', 'Vestigio biologico'),
  ballisticCase('capsula_estojo', 'Capsula/estojo'),
  projectile('projetil', 'Projetil'),
  perforation('perfuracao', 'Perfuracao'),
  coldWeapon('arma_branca', 'Arma branca'),
  firearm('arma_fogo', 'Arma de fogo'),
  struggleSign('sinal_luta', 'Sinal de luta'),
  footprint('pegada', 'Pegada'),
  displacedObject('objeto_deslocado', 'Objeto deslocado'),
  damage('dano', 'Dano'),
  toolMark('marca_ferramenta', 'Marca de ferramenta'),
  rupture('rompimento', 'Rompimento'),
  lock('fechadura', 'Fechadura'),
  doorWindow('porta_janela', 'Porta/janela'),
  fireFocus('foco_provavel_incendio', 'Foco provavel'),
  burnPattern('padrao_queima', 'Padrao de queima'),
  thermalDamage('dano_termico', 'Dano termico'),
  sootResidue('fuligem_residuo', 'Fuligem/residuo'),
  combustibleMaterial('material_combustivel', 'Material combustivel'),
  other('outro', 'Outro');

  const TraceType(this.code, this.label);

  final String code;
  final String label;

  static TraceType fromCode(Object? code) {
    final normalizedCode = code is String ? code : '';
    for (final type in values) {
      if (type.code == normalizedCode) {
        return type;
      }
    }
    if (normalizedCode == 'fragmentos') {
      return TraceType.fragment;
    }
    if (normalizedCode == 'sangue') {
      return TraceType.blood;
    }
    if (normalizedCode == 'peca') {
      return TraceType.detachedPart;
    }
    return TraceType.other;
  }
}

class TraceRecord {
  const TraceRecord({
    required this.id,
    required this.identifier,
    required this.type,
    this.description = '',
    this.length,
    this.width,
    this.unit = 'm',
    this.direction = '',
    this.locationDescription = '',
    this.note = '',
    this.photoIds = const [],
    this.sketchElementIds = const [],
  });

  final String id;
  final String identifier;
  final TraceType type;
  final String description;
  final double? length;
  final double? width;
  final String unit;
  final String direction;
  final String locationDescription;
  final String note;
  final List<String> photoIds;
  final List<String> sketchElementIds;

  TraceRecord copyWith({
    String? identifier,
    TraceType? type,
    String? description,
    double? length,
    double? width,
    String? unit,
    String? direction,
    String? locationDescription,
    String? note,
    List<String>? photoIds,
    List<String>? sketchElementIds,
  }) {
    return TraceRecord(
      id: id,
      identifier: identifier ?? this.identifier,
      type: type ?? this.type,
      description: description ?? this.description,
      length: length ?? this.length,
      width: width ?? this.width,
      unit: unit ?? this.unit,
      direction: direction ?? this.direction,
      locationDescription: locationDescription ?? this.locationDescription,
      note: note ?? this.note,
      photoIds: photoIds ?? this.photoIds,
      sketchElementIds: sketchElementIds ?? this.sketchElementIds,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'identificador': identifier,
      'tipo': type.code,
      'descricao': description,
      'comprimento': length,
      'largura': width,
      'unidade': unit,
      'direcao': direction,
      'localizacao_textual': locationDescription,
      'observacao': note,
      'fotos': photoIds,
      'croqui': sketchElementIds,
    };
  }

  factory TraceRecord.fromJson(Map<String, Object?> json) {
    return TraceRecord(
      id: _string(json['id']),
      identifier: _string(json['identificador']),
      type: TraceType.fromCode(json['tipo']),
      description: _string(json['descricao']),
      length: _double(json['comprimento']),
      width: _double(json['largura']),
      unit: _string(json['unidade'], fallback: 'm'),
      direction: _string(json['direcao']),
      locationDescription: _string(json['localizacao_textual']),
      note: _string(json['observacao']),
      photoIds: _stringList(json['fotos']),
      sketchElementIds: _stringList(json['croqui']),
    );
  }
}

String _string(Object? value, {String fallback = ''}) {
  return value is String ? value : fallback;
}

double? _double(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value);
  }
  return null;
}

List<String> _stringList(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value.whereType<String>().toList();
}
