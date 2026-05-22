enum NoteCategory {
  general('geral', 'Geral'),
  location('local', 'Local'),
  vehicle('veiculo', 'Veiculo'),
  victim('vitima', 'Vitima'),
  trace('vestigio', 'Vestigio'),
  dynamics('dinamica', 'Dinamica'),
  pending('pendencia', 'Pendencia'),
  other('outro', 'Outro');

  const NoteCategory(this.code, this.label);

  final String code;
  final String label;

  static NoteCategory fromCode(Object? code) {
    for (final category in values) {
      if (category.code == code) {
        return category;
      }
    }
    return NoteCategory.general;
  }
}

enum NotePriority {
  normal('normal', 'Normal'),
  important('importante', 'Importante'),
  critical('critica', 'Critica');

  const NotePriority(this.code, this.label);

  final String code;
  final String label;

  static NotePriority fromCode(Object? code) {
    if (code == true) {
      return NotePriority.important;
    }
    for (final priority in values) {
      if (priority.code == code) {
        return priority;
      }
    }
    return NotePriority.normal;
  }
}

class FieldNote {
  const FieldNote({
    required this.id,
    required this.createdAt,
    required this.text,
    DateTime? updatedAt,
    this.category = NoteCategory.general,
    this.priority = NotePriority.normal,
  }) : updatedAt = updatedAt ?? createdAt;

  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String text;
  final NoteCategory category;
  final NotePriority priority;

  FieldNote copyWith({
    DateTime? updatedAt,
    String? text,
    NoteCategory? category,
    NotePriority? priority,
  }) {
    return FieldNote(
      id: id,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      text: text ?? this.text,
      category: category ?? this.category,
      priority: priority ?? this.priority,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'criado_em': createdAt.toIso8601String(),
      'editado_em': updatedAt.toIso8601String(),
      'texto': text,
      'categoria': category.code,
      'prioridade': priority.code,
    };
  }

  factory FieldNote.fromJson(Map<String, Object?> json) {
    final createdAt = _date(json['criado_em']) ?? DateTime.now();
    return FieldNote(
      id: _string(json['id']),
      createdAt: createdAt,
      updatedAt: _date(json['editado_em']) ?? createdAt,
      text: _string(json['texto']),
      category: NoteCategory.fromCode(json['categoria']),
      priority: NotePriority.fromCode(json['prioridade']),
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
