import 'app_settings.dart';

enum DutyShiftStatus {
  upcoming('proximo', 'Proximo'),
  inProgress('em_andamento', 'Em andamento'),
  finished('encerrado', 'Encerrado');

  const DutyShiftStatus(this.code, this.label);

  final String code;
  final String label;
}

class DutyShift {
  const DutyShift({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.startsAt,
    required this.endsAt,
    this.title = '',
    this.area = ForensicArea.traffic,
    this.unit = '',
    this.team = '',
    this.notes = '',
    this.remindDayBefore = true,
    this.remindTwoHoursBefore = true,
  });

  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String title;
  final ForensicArea area;
  final DateTime startsAt;
  final DateTime endsAt;
  final String unit;
  final String team;
  final String notes;
  final bool remindDayBefore;
  final bool remindTwoHoursBefore;

  String get displayTitle {
    final cleaned = title.trim();
    return cleaned.isEmpty ? area.label : cleaned;
  }

  Duration get duration => endsAt.difference(startsAt);

  DutyShiftStatus statusAt(DateTime date) {
    if (date.isBefore(startsAt)) {
      return DutyShiftStatus.upcoming;
    }
    if (date.isBefore(endsAt)) {
      return DutyShiftStatus.inProgress;
    }
    return DutyShiftStatus.finished;
  }

  DutyShift copyWith({
    DateTime? updatedAt,
    DateTime? startsAt,
    DateTime? endsAt,
    String? title,
    ForensicArea? area,
    String? unit,
    String? team,
    String? notes,
    bool? remindDayBefore,
    bool? remindTwoHoursBefore,
  }) {
    return DutyShift(
      id: id,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      title: title ?? this.title,
      area: area ?? this.area,
      startsAt: startsAt ?? this.startsAt,
      endsAt: endsAt ?? this.endsAt,
      unit: unit ?? this.unit,
      team: team ?? this.team,
      notes: notes ?? this.notes,
      remindDayBefore: remindDayBefore ?? this.remindDayBefore,
      remindTwoHoursBefore: remindTwoHoursBefore ?? this.remindTwoHoursBefore,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'criado_em': createdAt.toIso8601String(),
      'atualizado_em': updatedAt.toIso8601String(),
      'titulo': title,
      'area': area.code,
      'inicio_em': startsAt.toIso8601String(),
      'fim_em': endsAt.toIso8601String(),
      'unidade': unit,
      'equipe': team,
      'observacoes': notes,
      'lembrar_24h': remindDayBefore,
      'lembrar_2h': remindTwoHoursBefore,
    };
  }

  factory DutyShift.fromJson(Map<String, Object?> json) {
    final now = DateTime.now();
    final startsAt = _date(json['inicio_em']) ?? now;
    return DutyShift(
      id: _string(json['id']),
      createdAt: _date(json['criado_em']) ?? startsAt,
      updatedAt: _date(json['atualizado_em']) ?? startsAt,
      title: _string(json['titulo']),
      area: ForensicArea.fromCode(json['area']),
      startsAt: startsAt,
      endsAt: _date(json['fim_em']) ?? startsAt.add(const Duration(hours: 12)),
      unit: _string(json['unidade']),
      team: _string(json['equipe']),
      notes: _string(json['observacoes']),
      remindDayBefore: _bool(json['lembrar_24h'], fallback: true),
      remindTwoHoursBefore: _bool(json['lembrar_2h'], fallback: true),
    );
  }
}

String _string(Object? value) => value is String ? value : '';

bool _bool(Object? value, {required bool fallback}) {
  return value is bool ? value : fallback;
}

DateTime? _date(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}
