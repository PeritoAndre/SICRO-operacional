enum PhotoCategory {
  overview('visao_geral', 'Visao geral'),
  approach('aproximacao', 'Aproximacao'),
  detail('detalhe', 'Detalhe'),
  vehicle('veiculo', 'Veiculo'),
  victim('vitima', 'Vitima'),
  trace('vestigio', 'Vestigio'),
  signaling('sinalizacao', 'Sinalizacao'),
  braking('frenagem', 'Frenagem'),
  trafficLight('semaforo', 'Semaforo'),
  damage('dano', 'Dano'),
  document('documento', 'Documento'),
  other('outros', 'Outros');

  const PhotoCategory(this.code, this.label);

  final String code;
  final String label;

  static PhotoCategory fromCode(Object? code) {
    for (final category in values) {
      if (category.code == code) {
        return category;
      }
    }
    return PhotoCategory.other;
  }
}

class FieldPhoto {
  const FieldPhoto({
    required this.id,
    required this.filePath,
    required this.category,
    required this.capturedAt,
    this.caption = '',
    this.sha256 = '',
    this.linkedEntityId,
  });

  final String id;
  final String filePath;
  final PhotoCategory category;
  final DateTime capturedAt;
  final String caption;
  final String sha256;
  final String? linkedEntityId;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'arquivo': filePath,
      'categoria': category.code,
      'capturada_em': capturedAt.toIso8601String(),
      'legenda': caption,
      'sha256': sha256,
      'entidade_vinculada': linkedEntityId,
    };
  }

  factory FieldPhoto.fromJson(Map<String, Object?> json) {
    return FieldPhoto(
      id: _string(json['id']),
      filePath: _string(json['arquivo']),
      category: PhotoCategory.fromCode(json['categoria']),
      capturedAt: _date(json['capturada_em']) ?? DateTime.now(),
      caption: _string(json['legenda']),
      sha256: _string(json['sha256']),
      linkedEntityId: json['entidade_vinculada'] is String
          ? json['entidade_vinculada'] as String
          : null,
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
