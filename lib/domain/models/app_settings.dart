enum ForensicArea {
  traffic('transito', 'Transito'),
  violentDeath('morte_violenta', 'Morte violenta'),
  property('patrimonio', 'Patrimonio');

  const ForensicArea(this.code, this.label);

  final String code;
  final String label;

  static ForensicArea fromCode(Object? code) {
    for (final area in values) {
      if (area.code == code) {
        return area;
      }
    }
    return ForensicArea.traffic;
  }
}

class ExpertProfile {
  const ExpertProfile({
    this.name = '',
    this.role = '',
    this.registration = '',
    this.organization = '',
    this.unit = '',
  });

  final String name;
  final String role;
  final String registration;
  final String organization;
  final String unit;

  bool get hasAnyData {
    return [
      name,
      role,
      registration,
      organization,
      unit,
    ].any((value) => value.trim().isNotEmpty);
  }

  ExpertProfile copyWith({
    String? name,
    String? role,
    String? registration,
    String? organization,
    String? unit,
  }) {
    return ExpertProfile(
      name: name ?? this.name,
      role: role ?? this.role,
      registration: registration ?? this.registration,
      organization: organization ?? this.organization,
      unit: unit ?? this.unit,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'nome': name,
      'cargo': role,
      'matricula': registration,
      'orgao': organization,
      'unidade': unit,
    };
  }

  factory ExpertProfile.fromJson(Map<String, Object?> json) {
    return ExpertProfile(
      name: _string(json['nome']),
      role: _string(json['cargo']),
      registration: _string(json['matricula']),
      organization: _string(json['orgao']),
      unit: _string(json['unidade']),
    );
  }
}

class AppSettings {
  const AppSettings({
    this.onboardingCompleted = false,
    this.profile = const ExpertProfile(),
    this.activeAreas = const [ForensicArea.traffic],
  });

  final bool onboardingCompleted;
  final ExpertProfile profile;
  final List<ForensicArea> activeAreas;

  AppSettings copyWith({
    bool? onboardingCompleted,
    ExpertProfile? profile,
    List<ForensicArea>? activeAreas,
  }) {
    return AppSettings(
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      profile: profile ?? this.profile,
      activeAreas: _normalizedAreas(activeAreas ?? this.activeAreas),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'onboarding_concluido': onboardingCompleted,
      'perfil_perito': profile.toJson(),
      'areas_ativas': activeAreas.map((area) => area.code).toList(),
    };
  }

  factory AppSettings.fromJson(Map<String, Object?> json) {
    final rawAreas = json['areas_ativas'];
    final areas = rawAreas is List
        ? rawAreas.map(ForensicArea.fromCode).toList()
        : const [ForensicArea.traffic];
    return AppSettings(
      onboardingCompleted: json['onboarding_concluido'] == true,
      profile: ExpertProfile.fromJson(_map(json['perfil_perito'])),
      activeAreas: _normalizedAreas(areas),
    );
  }
}

List<ForensicArea> _normalizedAreas(List<ForensicArea> areas) {
  final normalized = <ForensicArea>[];
  for (final area in areas) {
    if (!normalized.contains(area)) {
      normalized.add(area);
    }
  }
  return normalized.isEmpty ? [ForensicArea.traffic] : normalized;
}

String _string(Object? value) => value is String ? value : '';

Map<String, Object?> _map(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  return const {};
}
