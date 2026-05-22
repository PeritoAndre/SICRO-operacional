class LocationRecord {
  const LocationRecord({
    this.latitude,
    this.longitude,
    this.accuracyMeters,
    this.altitudeMeters,
    this.capturedAt,
    this.source = 'gps',
    this.note = '',
  });

  final double? latitude;
  final double? longitude;
  final double? accuracyMeters;
  final double? altitudeMeters;
  final DateTime? capturedAt;
  final String source;
  final String note;

  bool get hasCoordinates => latitude != null && longitude != null;

  String get coordinateLabel {
    if (!hasCoordinates) {
      return 'Coordenada nao capturada';
    }
    return '${latitude!.toStringAsFixed(7)}, ${longitude!.toStringAsFixed(7)}';
  }

  String get accuracyLabel {
    if (accuracyMeters == null) {
      return 'Precisao nao informada';
    }
    return '${accuracyMeters!.toStringAsFixed(1)} m';
  }

  Map<String, Object?> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'precisao_m': accuracyMeters,
      'altitude_m': altitudeMeters,
      'capturado_em': capturedAt?.toIso8601String(),
      'origem': source,
      'observacao': note,
    };
  }

  factory LocationRecord.fromJson(Map<String, Object?> json) {
    return LocationRecord(
      latitude: _double(json['latitude']),
      longitude: _double(json['longitude']),
      accuracyMeters: _double(json['precisao_m']),
      altitudeMeters: _double(json['altitude_m']),
      capturedAt: _date(json['capturado_em']),
      source: _string(json['origem'], fallback: 'gps'),
      note: _string(json['observacao']),
    );
  }
}

enum LocationPrecisionQuality {
  unknown('Aguardando', 'Sem leitura'),
  excellent('Excelente', 'Ate 5 m'),
  acceptable('Aceitavel', 'Ate 15 m'),
  poor('Ruim', 'Acima de 15 m');

  const LocationPrecisionQuality(this.label, this.description);

  final String label;
  final String description;

  static LocationPrecisionQuality fromAccuracy(double? accuracyMeters) {
    if (accuracyMeters == null) {
      return LocationPrecisionQuality.unknown;
    }
    if (accuracyMeters <= 5) {
      return LocationPrecisionQuality.excellent;
    }
    if (accuracyMeters <= 15) {
      return LocationPrecisionQuality.acceptable;
    }
    return LocationPrecisionQuality.poor;
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

DateTime? _date(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}
