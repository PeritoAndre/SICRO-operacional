class CaseData {
  const CaseData({
    this.bo = '',
    this.requisition = '',
    this.protocol = '',
    this.policeUnit = '',
    this.municipality = '',
    this.district = '',
    this.street = '',
    this.reference = '',
    this.peritians = '',
    this.supportTeam = '',
    this.policeTeam = '',
    this.policeCommander = '',
    this.calledAt,
    this.arrivedAt,
    this.closedAt,
  });

  final String bo;
  final String requisition;
  final String protocol;
  final String policeUnit;
  final String municipality;
  final String district;
  final String street;
  final String reference;
  final String peritians;
  final String supportTeam;
  final String policeTeam;
  final String policeCommander;
  final DateTime? calledAt;
  final DateTime? arrivedAt;
  final DateTime? closedAt;

  String get displayTitle => bo.trim().isEmpty ? 'Ocorrencia sem BO' : 'BO $bo';

  String get displayLocation {
    final parts = [
      street,
      district,
      municipality,
    ].where((part) => part.trim().isNotEmpty).toList();
    return parts.isEmpty ? 'Local nao informado' : parts.join(' - ');
  }

  CaseData copyWith({
    String? bo,
    String? requisition,
    String? protocol,
    String? policeUnit,
    String? municipality,
    String? district,
    String? street,
    String? reference,
    String? peritians,
    String? supportTeam,
    String? policeTeam,
    String? policeCommander,
    DateTime? calledAt,
    DateTime? arrivedAt,
    DateTime? closedAt,
  }) {
    return CaseData(
      bo: bo ?? this.bo,
      requisition: requisition ?? this.requisition,
      protocol: protocol ?? this.protocol,
      policeUnit: policeUnit ?? this.policeUnit,
      municipality: municipality ?? this.municipality,
      district: district ?? this.district,
      street: street ?? this.street,
      reference: reference ?? this.reference,
      peritians: peritians ?? this.peritians,
      supportTeam: supportTeam ?? this.supportTeam,
      policeTeam: policeTeam ?? this.policeTeam,
      policeCommander: policeCommander ?? this.policeCommander,
      calledAt: calledAt ?? this.calledAt,
      arrivedAt: arrivedAt ?? this.arrivedAt,
      closedAt: closedAt ?? this.closedAt,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'bo': bo,
      'requisicao': requisition,
      'protocolo': protocol,
      'delegacia': policeUnit,
      'municipio': municipality,
      'bairro': district,
      'logradouro': street,
      'referencia': reference,
      'peritos': peritians,
      'tecnico_pericial': supportTeam,
      'equipe_apoio': supportTeam,
      'equipe_policial': policeTeam,
      'comandante_policial': policeCommander,
      'acionamento_em': calledAt?.toIso8601String(),
      'chegada_em': arrivedAt?.toIso8601String(),
      'encerramento_em': closedAt?.toIso8601String(),
    };
  }

  factory CaseData.fromJson(Map<String, Object?> json) {
    return CaseData(
      bo: _string(json['bo']),
      requisition: _string(json['requisicao']),
      protocol: _string(json['protocolo']),
      policeUnit: _string(json['delegacia']),
      municipality: _string(json['municipio']),
      district: _string(json['bairro']),
      street: _string(json['logradouro']),
      reference: _string(json['referencia']),
      peritians: _string(json['peritos']),
      supportTeam: _string(
        json['tecnico_pericial'],
        fallback: _string(json['equipe_apoio']),
      ),
      policeTeam: _string(json['equipe_policial']),
      policeCommander: _string(json['comandante_policial']),
      calledAt: _date(json['acionamento_em']),
      arrivedAt: _date(json['chegada_em']),
      closedAt: _date(json['encerramento_em']),
    );
  }
}

String _string(Object? value, {String fallback = ''}) {
  return value is String ? value : fallback;
}

DateTime? _date(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}
