enum OfficialDocumentStatus {
  received('recebido', 'Recebido'),
  underReview('em_analise', 'Em analise'),
  linked('vinculado', 'Vinculado'),
  answered('respondido', 'Respondido'),
  archived('arquivado', 'Arquivado');

  const OfficialDocumentStatus(this.code, this.label);

  final String code;
  final String label;

  static OfficialDocumentStatus fromCode(Object? code) {
    for (final status in values) {
      if (status.code == code) {
        return status;
      }
    }
    return OfficialDocumentStatus.received;
  }
}

class OfficialDocumentVehicle {
  const OfficialDocumentVehicle({
    this.type = '',
    this.plate = '',
    this.renavam = '',
    this.chassis = '',
    this.brandModel = '',
    this.color = '',
    this.owner = '',
  });

  final String type;
  final String plate;
  final String renavam;
  final String chassis;
  final String brandModel;
  final String color;
  final String owner;

  String get displayTitle {
    if (plate.trim().isNotEmpty) {
      return plate.trim();
    }
    if (type.trim().isNotEmpty) {
      return type.trim();
    }
    return 'Veiculo identificado';
  }

  Map<String, Object?> toJson() {
    return {
      'tipo': type,
      'placa': plate,
      'renavam': renavam,
      'chassi': chassis,
      'marca_modelo': brandModel,
      'cor': color,
      'proprietario': owner,
    };
  }

  factory OfficialDocumentVehicle.fromJson(Map<String, Object?> json) {
    return OfficialDocumentVehicle(
      type: _string(json['tipo']),
      plate: _string(json['placa']),
      renavam: _string(json['renavam']),
      chassis: _string(json['chassi']),
      brandModel: _string(json['marca_modelo']),
      color: _string(json['cor']),
      owner: _string(json['proprietario']),
    );
  }
}

class OfficialDocument {
  const OfficialDocument({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.status = OfficialDocumentStatus.received,
    this.imagePath = '',
    this.imageSha256 = '',
    this.extractedText = '',
    this.documentNumber = '',
    this.boNumber = '',
    this.protocol = '',
    this.requestingUnit = '',
    this.recipient = '',
    this.subject = '',
    this.requestedExam = '',
    this.documentDateText = '',
    this.eventDateTimeText = '',
    this.municipality = '',
    this.district = '',
    this.address = '',
    this.deadlineAt,
    this.notes = '',
    this.vehicles = const [],
    this.linkedOccurrenceId,
  });

  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final OfficialDocumentStatus status;
  final String imagePath;
  final String imageSha256;
  final String extractedText;
  final String documentNumber;
  final String boNumber;
  final String protocol;
  final String requestingUnit;
  final String recipient;
  final String subject;
  final String requestedExam;
  final String documentDateText;
  final String eventDateTimeText;
  final String municipality;
  final String district;
  final String address;
  final DateTime? deadlineAt;
  final String notes;
  final List<OfficialDocumentVehicle> vehicles;
  final String? linkedOccurrenceId;

  String get displayTitle {
    if (documentNumber.trim().isNotEmpty) {
      return 'Oficio ${documentNumber.trim()}';
    }
    if (boNumber.trim().isNotEmpty) {
      return 'BO ${boNumber.trim()}';
    }
    return 'Oficio sem numero';
  }

  String get displaySubtitle {
    final parts = [
      if (boNumber.trim().isNotEmpty) 'BO ${boNumber.trim()}',
      if (requestingUnit.trim().isNotEmpty) requestingUnit.trim(),
      if (municipality.trim().isNotEmpty) municipality.trim(),
    ];
    return parts.isEmpty ? 'Dados pendentes de revisao' : parts.join(' - ');
  }

  OfficialDocument copyWith({
    DateTime? updatedAt,
    OfficialDocumentStatus? status,
    String? imagePath,
    String? imageSha256,
    String? extractedText,
    String? documentNumber,
    String? boNumber,
    String? protocol,
    String? requestingUnit,
    String? recipient,
    String? subject,
    String? requestedExam,
    String? documentDateText,
    String? eventDateTimeText,
    String? municipality,
    String? district,
    String? address,
    DateTime? deadlineAt,
    String? notes,
    List<OfficialDocumentVehicle>? vehicles,
    String? linkedOccurrenceId,
    bool clearDeadline = false,
    bool clearLinkedOccurrence = false,
  }) {
    return OfficialDocument(
      id: id,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      imagePath: imagePath ?? this.imagePath,
      imageSha256: imageSha256 ?? this.imageSha256,
      extractedText: extractedText ?? this.extractedText,
      documentNumber: documentNumber ?? this.documentNumber,
      boNumber: boNumber ?? this.boNumber,
      protocol: protocol ?? this.protocol,
      requestingUnit: requestingUnit ?? this.requestingUnit,
      recipient: recipient ?? this.recipient,
      subject: subject ?? this.subject,
      requestedExam: requestedExam ?? this.requestedExam,
      documentDateText: documentDateText ?? this.documentDateText,
      eventDateTimeText: eventDateTimeText ?? this.eventDateTimeText,
      municipality: municipality ?? this.municipality,
      district: district ?? this.district,
      address: address ?? this.address,
      deadlineAt: clearDeadline ? null : deadlineAt ?? this.deadlineAt,
      notes: notes ?? this.notes,
      vehicles: vehicles ?? this.vehicles,
      linkedOccurrenceId: clearLinkedOccurrence
          ? null
          : linkedOccurrenceId ?? this.linkedOccurrenceId,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'status': status.code,
      'criado_em': createdAt.toIso8601String(),
      'atualizado_em': updatedAt.toIso8601String(),
      'imagem_arquivo': imagePath,
      'imagem_sha256': imageSha256,
      'texto_ocr': extractedText,
      'oficio_numero': documentNumber,
      'bo': boNumber,
      'protocolo_pci': protocol,
      'unidade_solicitante': requestingUnit,
      'destinatario': recipient,
      'assunto': subject,
      'exame_solicitado': requestedExam,
      'data_oficio_texto': documentDateText,
      'data_hora_fato_texto': eventDateTimeText,
      'municipio': municipality,
      'bairro': district,
      'endereco': address,
      'prazo_em': deadlineAt?.toIso8601String(),
      'observacoes': notes,
      'veiculos': vehicles.map((vehicle) => vehicle.toJson()).toList(),
      'ocorrencia_vinculada_id': linkedOccurrenceId,
    };
  }

  factory OfficialDocument.fromJson(Map<String, Object?> json) {
    return OfficialDocument(
      id: _string(json['id']),
      status: OfficialDocumentStatus.fromCode(json['status']),
      createdAt: _date(json['criado_em']) ?? DateTime.now(),
      updatedAt: _date(json['atualizado_em']) ?? DateTime.now(),
      imagePath: _string(json['imagem_arquivo']),
      imageSha256: _string(json['imagem_sha256']),
      extractedText: _string(json['texto_ocr']),
      documentNumber: _string(json['oficio_numero']),
      boNumber: _string(json['bo']),
      protocol: _string(json['protocolo_pci']),
      requestingUnit: _string(json['unidade_solicitante']),
      recipient: _string(json['destinatario']),
      subject: _string(json['assunto']),
      requestedExam: _string(json['exame_solicitado']),
      documentDateText: _string(json['data_oficio_texto']),
      eventDateTimeText: _string(json['data_hora_fato_texto']),
      municipality: _string(json['municipio']),
      district: _string(json['bairro']),
      address: _string(json['endereco']),
      deadlineAt: _date(json['prazo_em']),
      notes: _string(json['observacoes']),
      vehicles: _list(
        json['veiculos'],
      ).map((item) => OfficialDocumentVehicle.fromJson(_map(item))).toList(),
      linkedOccurrenceId: json['ocorrencia_vinculada_id'] is String
          ? json['ocorrencia_vinculada_id'] as String
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
