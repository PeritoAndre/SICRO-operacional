import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/data/app_settings_repository.dart';
import '../../core/data/duty_shift_repository.dart';
import '../../core/data/official_document_repository.dart';
import '../../core/data/occurrence_repository.dart';
import '../../core/services/backup_notification_service.dart';
import '../../core/services/duty_shift_notification_service.dart';
import '../../domain/models/app_settings.dart';
import '../../features/backup/backup_screen.dart';
import '../../shared/widgets/pilot_notice_card.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    required this.settingsRepository,
    this.occurrenceRepository,
    this.officialDocumentRepository,
    this.dutyShiftRepository,
    this.backupNotificationService,
    this.dutyShiftNotificationService,
    super.key,
  });

  final AppSettingsRepository settingsRepository;
  final OccurrenceRepository? occurrenceRepository;
  final OfficialDocumentRepository? officialDocumentRepository;
  final DutyShiftRepository? dutyShiftRepository;
  final BackupNotificationService? backupNotificationService;
  final DutyShiftNotificationService? dutyShiftNotificationService;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _name;
  late final TextEditingController _role;
  late final TextEditingController _registration;
  late final TextEditingController _organization;
  late final TextEditingController _unit;
  late final Set<ForensicArea> _activeAreas;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final settings = widget.settingsRepository.settings;
    final profile = settings.profile;
    _name = TextEditingController(text: profile.name);
    _role = TextEditingController(text: profile.role);
    _registration = TextEditingController(text: profile.registration);
    _organization = TextEditingController(text: profile.organization);
    _unit = TextEditingController(text: profile.unit);
    _activeAreas = settings.activeAreas.toSet();
  }

  @override
  void dispose() {
    _name.dispose();
    _role.dispose();
    _registration.dispose();
    _organization.dispose();
    _unit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuracoes')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const PilotNoticeCard(),
            const SizedBox(height: 18),
            Text(
              'Perfil do perito',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              'Essas informacoes ficam salvas apenas neste aparelho.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            _ProfileFields(
              name: _name,
              role: _role,
              registration: _registration,
              organization: _organization,
              unit: _unit,
            ),
            const SizedBox(height: 18),
            Text(
              'Areas ativas',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            _AreaSelector(
              selected: _activeAreas,
              onChanged: (area, selected) {
                setState(() {
                  if (selected) {
                    _activeAreas.add(area);
                  } else {
                    _activeAreas.remove(area);
                  }
                  if (_activeAreas.isEmpty) {
                    _activeAreas.add(ForensicArea.traffic);
                  }
                });
              },
            ),
            if (_canOpenBackup) ...[
              const SizedBox(height: 18),
              _BackupSettingsEntry(onOpen: _openBackup),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('Salvar configuracoes'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await widget.settingsRepository.updateSettings(
      profile: ExpertProfile(
        name: _name.text.trim(),
        role: _role.text.trim(),
        registration: _registration.text.trim(),
        organization: _organization.text.trim(),
        unit: _unit.text.trim(),
      ),
      activeAreas: _activeAreas.toList(),
    );
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Configuracoes salvas.')));
  }

  bool get _canOpenBackup {
    return widget.occurrenceRepository != null &&
        widget.officialDocumentRepository != null &&
        widget.dutyShiftRepository != null;
  }

  void _openBackup() {
    final occurrenceRepository = widget.occurrenceRepository;
    final officialDocumentRepository = widget.officialDocumentRepository;
    final dutyShiftRepository = widget.dutyShiftRepository;
    if (occurrenceRepository == null ||
        officialDocumentRepository == null ||
        dutyShiftRepository == null) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BackupScreen(
          settingsRepository: widget.settingsRepository,
          occurrenceRepository: occurrenceRepository,
          officialDocumentRepository: officialDocumentRepository,
          dutyShiftRepository: dutyShiftRepository,
          backupNotificationService: widget.backupNotificationService,
          dutyShiftNotificationService: widget.dutyShiftNotificationService,
        ),
      ),
    );
  }
}

class _ProfileFields extends StatelessWidget {
  const _ProfileFields({
    required this.name,
    required this.role,
    required this.registration,
    required this.organization,
    required this.unit,
  });

  final TextEditingController name;
  final TextEditingController role;
  final TextEditingController registration;
  final TextEditingController organization;
  final TextEditingController unit;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: name,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Nome',
            prefixIcon: Icon(Icons.person_outline),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: role,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Cargo',
            prefixIcon: Icon(Icons.badge_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: registration,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Matricula',
            prefixIcon: Icon(Icons.confirmation_number_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: organization,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Orgao',
            prefixIcon: Icon(Icons.account_balance_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: unit,
          decoration: const InputDecoration(
            labelText: 'Unidade / setor',
            prefixIcon: Icon(Icons.apartment_outlined),
          ),
        ),
      ],
    );
  }
}

class _AreaSelector extends StatelessWidget {
  const _AreaSelector({required this.selected, required this.onChanged});

  final Set<ForensicArea> selected;
  final void Function(ForensicArea area, bool selected) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: ForensicArea.values.map((area) {
        final active = selected.contains(area);
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Card(
            child: CheckboxListTile(
              value: active,
              onChanged: (value) => onChanged(area, value ?? false),
              title: Text(area.label),
              subtitle: Text(_subtitle(area)),
              secondary: Icon(_icon(area), color: AppColors.gold),
              controlAffinity: ListTileControlAffinity.trailing,
            ),
          ),
        );
      }).toList(),
    );
  }

  String _subtitle(ForensicArea area) {
    return switch (area) {
      ForensicArea.traffic => 'Modulo operacional ativo no MVP',
      ForensicArea.violentDeath => 'Fluxo de local de crime contra a vida',
      ForensicArea.property => 'Estrutura preparada para etapa futura',
      ForensicArea.environmental => 'Checklist ambiental baseado em POP',
      ForensicArea.ballistics => 'Balistica Forense com checklist POP',
      ForensicArea.audioImage => 'Audio e Imagem com checklist POP',
      ForensicArea.papiloscopy => 'Papiloscopia com checklist POP',
    };
  }

  IconData _icon(ForensicArea area) {
    return switch (area) {
      ForensicArea.traffic => Icons.traffic_outlined,
      ForensicArea.violentDeath => Icons.health_and_safety_outlined,
      ForensicArea.property => Icons.domain_verification_outlined,
      ForensicArea.environmental => Icons.forest_outlined,
      ForensicArea.ballistics => Icons.adjust_outlined,
      ForensicArea.audioImage => Icons.perm_media_outlined,
      ForensicArea.papiloscopy => Icons.fingerprint,
    };
  }
}

class _BackupSettingsEntry extends StatelessWidget {
  const _BackupSettingsEntry({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onOpen,
        leading: const Icon(Icons.backup_outlined, color: AppColors.gold),
        title: const Text(
          'Backup completo do SICRO',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: const Text(
          'Gerar .sicrobackup e acompanhar lembrete mensal.',
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
