enum VictimCondition {
  unharmed('ilesa', 'Ilesa'),
  injured('lesionada', 'Lesionada'),
  death('obito', 'Obito'),
  unknown('desconhecida', 'Desconhecida');

  const VictimCondition(this.code, this.label);

  final String code;
  final String label;

  static VictimCondition fromCode(Object? code) {
    for (final condition in values) {
      if (condition.code == code) {
        return condition;
      }
    }
    return VictimCondition.unknown;
  }
}

enum VictimType {
  driver('condutor', 'Condutor'),
  passenger('passageiro', 'Passageiro'),
  pedestrian('pedestre', 'Pedestre'),
  cyclist('ciclista', 'Ciclista'),
  motorcyclist('motociclista', 'Motociclista'),
  other('outro', 'Outro');

  const VictimType(this.code, this.label);

  final String code;
  final String label;

  static VictimType fromCode(Object? code) {
    for (final type in values) {
      if (type.code == code) {
        return type;
      }
    }
    return VictimType.other;
  }
}

enum VictimRemovalStatus {
  yes('sim', 'Sim'),
  no('nao', 'Nao'),
  unknown('nao_informado', 'Nao informado');

  const VictimRemovalStatus(this.code, this.label);

  final String code;
  final String label;

  static VictimRemovalStatus fromCode(Object? code) {
    if (code == true) {
      return VictimRemovalStatus.yes;
    }
    if (code == false) {
      return VictimRemovalStatus.no;
    }
    for (final status in values) {
      if (status.code == code) {
        return status;
      }
    }
    return VictimRemovalStatus.unknown;
  }
}

class VictimRecord {
  const VictimRecord({
    required this.id,
    required this.identifier,
    this.name = '',
    this.condition = VictimCondition.unknown,
    this.type = VictimType.other,
    this.removalStatus = VictimRemovalStatus.unknown,
    this.rescuedBy = '',
    this.destination = '',
    this.removedAt,
    this.bodyPosition = '',
    this.protectiveEquipment = '',
    this.note = '',
    this.photoIds = const [],
  });

  final String id;
  final String identifier;
  final String name;
  final VictimCondition condition;
  final VictimType type;
  final VictimRemovalStatus removalStatus;
  final String rescuedBy;
  final String destination;
  final DateTime? removedAt;
  final String bodyPosition;
  final String protectiveEquipment;
  final String note;
  final List<String> photoIds;

  VictimRecord copyWith({
    String? identifier,
    String? name,
    VictimCondition? condition,
    VictimType? type,
    VictimRemovalStatus? removalStatus,
    String? rescuedBy,
    String? destination,
    DateTime? removedAt,
    String? bodyPosition,
    String? protectiveEquipment,
    String? note,
    List<String>? photoIds,
  }) {
    return VictimRecord(
      id: id,
      identifier: identifier ?? this.identifier,
      name: name ?? this.name,
      condition: condition ?? this.condition,
      type: type ?? this.type,
      removalStatus: removalStatus ?? this.removalStatus,
      rescuedBy: rescuedBy ?? this.rescuedBy,
      destination: destination ?? this.destination,
      removedAt: removedAt ?? this.removedAt,
      bodyPosition: bodyPosition ?? this.bodyPosition,
      protectiveEquipment: protectiveEquipment ?? this.protectiveEquipment,
      note: note ?? this.note,
      photoIds: photoIds ?? this.photoIds,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'identificador': identifier,
      'nome': name,
      'condicao': condition.code,
      'tipo': type.code,
      'removida': removalStatus.code,
      'socorrida_por': rescuedBy,
      'destino': destination,
      'removida_em': removedAt?.toIso8601String(),
      'posicao_corporal': bodyPosition,
      'epi': protectiveEquipment,
      'observacao': note,
      'fotos': photoIds,
    };
  }

  factory VictimRecord.fromJson(Map<String, Object?> json) {
    return VictimRecord(
      id: _string(json['id']),
      identifier: _string(json['identificador']),
      name: _string(json['nome']),
      condition: VictimCondition.fromCode(json['condicao']),
      type: VictimType.fromCode(json['tipo']),
      removalStatus: VictimRemovalStatus.fromCode(json['removida']),
      rescuedBy: _string(json['socorrida_por']),
      destination: _string(json['destino']),
      removedAt: _date(json['removida_em']),
      bodyPosition: _string(json['posicao_corporal']),
      protectiveEquipment: _string(json['epi']),
      note: _string(json['observacao']),
      photoIds: _stringList(json['fotos']),
    );
  }
}

String _string(Object? value) => value is String ? value : '';

DateTime? _date(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}

List<String> _stringList(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value.whereType<String>().toList();
}
