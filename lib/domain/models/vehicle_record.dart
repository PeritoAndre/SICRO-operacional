class VehicleRecord {
  const VehicleRecord({
    required this.id,
    required this.identifier,
    this.plate = '',
    this.type = '',
    this.model = '',
    this.color = '',
    this.trafficDirection = '',
    this.finalPosition = '',
    this.impactPoint = '',
    this.damage = '',
    this.driver = '',
    this.owner = '',
    this.note = '',
    this.photoIds = const [],
  });

  final String id;
  final String identifier;
  final String plate;
  final String type;
  final String model;
  final String color;
  final String trafficDirection;
  final String finalPosition;
  final String impactPoint;
  final String damage;
  final String driver;
  final String owner;
  final String note;
  final List<String> photoIds;

  VehicleRecord copyWith({
    String? identifier,
    String? plate,
    String? type,
    String? model,
    String? color,
    String? trafficDirection,
    String? finalPosition,
    String? impactPoint,
    String? damage,
    String? driver,
    String? owner,
    String? note,
    List<String>? photoIds,
  }) {
    return VehicleRecord(
      id: id,
      identifier: identifier ?? this.identifier,
      plate: plate ?? this.plate,
      type: type ?? this.type,
      model: model ?? this.model,
      color: color ?? this.color,
      trafficDirection: trafficDirection ?? this.trafficDirection,
      finalPosition: finalPosition ?? this.finalPosition,
      impactPoint: impactPoint ?? this.impactPoint,
      damage: damage ?? this.damage,
      driver: driver ?? this.driver,
      owner: owner ?? this.owner,
      note: note ?? this.note,
      photoIds: photoIds ?? this.photoIds,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'identificador': identifier,
      'placa': plate,
      'tipo': type,
      'modelo': model,
      'cor': color,
      'sentido_trafego': trafficDirection,
      'posicao_final': finalPosition,
      'ponto_impacto': impactPoint,
      'avarias': damage,
      'condutor': driver,
      'proprietario': owner,
      'observacao': note,
      'fotos': photoIds,
    };
  }

  factory VehicleRecord.fromJson(Map<String, Object?> json) {
    return VehicleRecord(
      id: _string(json['id']),
      identifier: _string(json['identificador']),
      plate: _string(json['placa']),
      type: _string(json['tipo']),
      model: _string(json['modelo']),
      color: _string(json['cor']),
      trafficDirection: _string(json['sentido_trafego']),
      finalPosition: _string(json['posicao_final']),
      impactPoint: _string(json['ponto_impacto']),
      damage: _string(json['avarias']),
      driver: _string(json['condutor']),
      owner: _string(json['proprietario']),
      note: _string(json['observacao']),
      photoIds: _stringList(json['fotos']),
    );
  }
}

String _string(Object? value) => value is String ? value : '';

List<String> _stringList(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value.whereType<String>().toList();
}
