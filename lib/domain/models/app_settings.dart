enum ForensicArea {
  traffic('transito', 'Transito'),
  violentDeath('morte_violenta', 'Local de crime'),
  property('patrimonio', 'Patrimonio'),
  environmental('ambiental', 'Pericia ambiental'),
  ballistics('balistica_forense', 'Balistica Forense'),
  audioImage('audio_imagem', 'Audio e Imagem'),
  papiloscopy('papiloscopia', 'Papiloscopia');

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

class BackupSettings {
  const BackupSettings({
    this.lastBackupAt,
    this.lastBackupFileName = '',
    this.lastBackupSha256 = '',
    this.lastBackupSizeBytes = 0,
    this.lastBackupOccurrenceCount = 0,
    this.lastBackupOfficialDocumentCount = 0,
    this.lastBackupDutyShiftCount = 0,
    this.lastBackupPhotoCount = 0,
    this.reminderEnabled = true,
    this.reminderIntervalDays = 30,
    this.preferredHour = 4,
  });

  final DateTime? lastBackupAt;
  final String lastBackupFileName;
  final String lastBackupSha256;
  final int lastBackupSizeBytes;
  final int lastBackupOccurrenceCount;
  final int lastBackupOfficialDocumentCount;
  final int lastBackupDutyShiftCount;
  final int lastBackupPhotoCount;
  final bool reminderEnabled;
  final int reminderIntervalDays;
  final int preferredHour;

  bool get hasBackup => lastBackupAt != null;

  bool isStale(DateTime now) {
    if (!reminderEnabled) {
      return false;
    }
    final last = lastBackupAt;
    if (last == null) {
      return true;
    }
    return now.difference(last).inDays >= reminderIntervalDays;
  }

  int daysSince(DateTime now) {
    final last = lastBackupAt;
    if (last == null) {
      return -1;
    }
    return now.difference(last).inDays;
  }

  BackupSettings copyWith({
    DateTime? lastBackupAt,
    String? lastBackupFileName,
    String? lastBackupSha256,
    int? lastBackupSizeBytes,
    int? lastBackupOccurrenceCount,
    int? lastBackupOfficialDocumentCount,
    int? lastBackupDutyShiftCount,
    int? lastBackupPhotoCount,
    bool? reminderEnabled,
    int? reminderIntervalDays,
    int? preferredHour,
    bool clearLastBackupAt = false,
  }) {
    return BackupSettings(
      lastBackupAt: clearLastBackupAt
          ? null
          : lastBackupAt ?? this.lastBackupAt,
      lastBackupFileName: lastBackupFileName ?? this.lastBackupFileName,
      lastBackupSha256: lastBackupSha256 ?? this.lastBackupSha256,
      lastBackupSizeBytes: lastBackupSizeBytes ?? this.lastBackupSizeBytes,
      lastBackupOccurrenceCount:
          lastBackupOccurrenceCount ?? this.lastBackupOccurrenceCount,
      lastBackupOfficialDocumentCount:
          lastBackupOfficialDocumentCount ??
          this.lastBackupOfficialDocumentCount,
      lastBackupDutyShiftCount:
          lastBackupDutyShiftCount ?? this.lastBackupDutyShiftCount,
      lastBackupPhotoCount: lastBackupPhotoCount ?? this.lastBackupPhotoCount,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderIntervalDays: reminderIntervalDays ?? this.reminderIntervalDays,
      preferredHour: preferredHour ?? this.preferredHour,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'ultimo_backup_em': lastBackupAt?.toIso8601String(),
      'ultimo_backup_arquivo': lastBackupFileName,
      'ultimo_backup_sha256': lastBackupSha256,
      'ultimo_backup_tamanho_bytes': lastBackupSizeBytes,
      'ultimo_backup_ocorrencias': lastBackupOccurrenceCount,
      'ultimo_backup_oficios': lastBackupOfficialDocumentCount,
      'ultimo_backup_plantoes': lastBackupDutyShiftCount,
      'ultimo_backup_fotos': lastBackupPhotoCount,
      'lembrete_ativo': reminderEnabled,
      'intervalo_lembrete_dias': reminderIntervalDays,
      'hora_preferida': preferredHour,
    };
  }

  factory BackupSettings.fromJson(Map<String, Object?> json) {
    return BackupSettings(
      lastBackupAt: _date(json['ultimo_backup_em']),
      lastBackupFileName: _string(json['ultimo_backup_arquivo']),
      lastBackupSha256: _string(json['ultimo_backup_sha256']),
      lastBackupSizeBytes: _int(json['ultimo_backup_tamanho_bytes']),
      lastBackupOccurrenceCount: _int(json['ultimo_backup_ocorrencias']),
      lastBackupOfficialDocumentCount: _int(json['ultimo_backup_oficios']),
      lastBackupDutyShiftCount: _int(json['ultimo_backup_plantoes']),
      lastBackupPhotoCount: _int(json['ultimo_backup_fotos']),
      reminderEnabled: _bool(json['lembrete_ativo'], fallback: true),
      reminderIntervalDays: _positiveInt(
        json['intervalo_lembrete_dias'],
        fallback: 30,
      ),
      preferredHour: _hour(json['hora_preferida']),
    );
  }
}

class AppSettings {
  const AppSettings({
    this.onboardingCompleted = false,
    this.profile = const ExpertProfile(),
    this.backup = const BackupSettings(),
    this.activeAreas = const [
      ForensicArea.traffic,
      ForensicArea.violentDeath,
      ForensicArea.property,
      ForensicArea.environmental,
      ForensicArea.ballistics,
      ForensicArea.audioImage,
      ForensicArea.papiloscopy,
    ],
  });

  final bool onboardingCompleted;
  final ExpertProfile profile;
  final BackupSettings backup;
  final List<ForensicArea> activeAreas;

  AppSettings copyWith({
    bool? onboardingCompleted,
    ExpertProfile? profile,
    BackupSettings? backup,
    List<ForensicArea>? activeAreas,
  }) {
    return AppSettings(
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      profile: profile ?? this.profile,
      backup: backup ?? this.backup,
      activeAreas: _normalizedAreas(activeAreas ?? this.activeAreas),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'onboarding_concluido': onboardingCompleted,
      'perfil_perito': profile.toJson(),
      'backup': backup.toJson(),
      'areas_ativas': activeAreas.map((area) => area.code).toList(),
    };
  }

  factory AppSettings.fromJson(Map<String, Object?> json) {
    final rawAreas = json['areas_ativas'];
    final areas = rawAreas is List
        ? rawAreas.map(ForensicArea.fromCode).toList()
        : const [
            ForensicArea.traffic,
            ForensicArea.violentDeath,
            ForensicArea.property,
            ForensicArea.environmental,
            ForensicArea.ballistics,
            ForensicArea.audioImage,
            ForensicArea.papiloscopy,
          ];
    return AppSettings(
      onboardingCompleted: json['onboarding_concluido'] == true,
      profile: ExpertProfile.fromJson(_map(json['perfil_perito'])),
      backup: BackupSettings.fromJson(_map(json['backup'])),
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

int _int(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  if (value is String) {
    return int.tryParse(value) ?? 0;
  }
  return 0;
}

int _positiveInt(Object? value, {required int fallback}) {
  final parsed = _int(value);
  return parsed > 0 ? parsed : fallback;
}

int _hour(Object? value) {
  final parsed = _int(value);
  if (parsed < 0 || parsed > 23) {
    return 4;
  }
  return parsed;
}

bool _bool(Object? value, {required bool fallback}) {
  return value is bool ? value : fallback;
}

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
