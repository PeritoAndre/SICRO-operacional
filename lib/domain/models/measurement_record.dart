class MeasurementRecord {
  const MeasurementRecord({
    required this.id,
    required this.label,
    required this.value,
    this.unit = 'm',
    this.pointA = '',
    this.pointB = '',
    this.method = '',
    this.note = '',
    this.photoIds = const [],
    this.sketchElementIds = const [],
  });

  final String id;
  final String label;
  final double value;
  final String unit;
  final String pointA;
  final String pointB;
  final String method;
  final String note;
  final List<String> photoIds;
  final List<String> sketchElementIds;

  MeasurementRecord copyWith({
    String? label,
    double? value,
    String? unit,
    String? pointA,
    String? pointB,
    String? method,
    String? note,
    List<String>? photoIds,
    List<String>? sketchElementIds,
  }) {
    return MeasurementRecord(
      id: id,
      label: label ?? this.label,
      value: value ?? this.value,
      unit: unit ?? this.unit,
      pointA: pointA ?? this.pointA,
      pointB: pointB ?? this.pointB,
      method: method ?? this.method,
      note: note ?? this.note,
      photoIds: photoIds ?? this.photoIds,
      sketchElementIds: sketchElementIds ?? this.sketchElementIds,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'rotulo': label,
      'valor': value,
      'unidade': unit,
      'ponto_a': pointA,
      'ponto_b': pointB,
      'metodo': method,
      'observacao': note,
      'fotos': photoIds,
      'croqui': sketchElementIds,
    };
  }

  factory MeasurementRecord.fromJson(Map<String, Object?> json) {
    return MeasurementRecord(
      id: _string(json['id']),
      label: _string(json['rotulo']),
      value: _double(json['valor']) ?? 0,
      unit: _string(json['unidade'], fallback: 'm'),
      pointA: _string(json['ponto_a']),
      pointB: _string(json['ponto_b']),
      method: _string(json['metodo']),
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
