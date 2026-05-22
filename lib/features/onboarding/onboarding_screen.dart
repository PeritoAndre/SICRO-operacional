import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/data/app_settings_repository.dart';
import '../../domain/models/app_settings.dart';
import '../../shared/widgets/pilot_notice_card.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({required this.settingsRepository, super.key});

  final AppSettingsRepository settingsRepository;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _name = TextEditingController();
  final _role = TextEditingController();
  final _registration = TextEditingController();
  final _organization = TextEditingController();
  final _unit = TextEditingController();
  final Set<ForensicArea> _activeAreas = {ForensicArea.traffic};
  bool _saving = false;

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
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 24),
          children: [
            const _WelcomeHeader(),
            const SizedBox(height: 12),
            const PilotNoticeCard(),
            const SizedBox(height: 18),
            Text(
              'Configuracao inicial',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              'Voce pode preencher agora ou ajustar depois em Configuracoes.',
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
              'Areas de atuacao',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            _AreaCards(
              activeAreas: _activeAreas,
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
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: _saving ? null : _finish,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.arrow_forward),
              label: const Text('Entrar no SICRO Operacional'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _saving ? null : _skip,
              child: const Text('Pular por enquanto'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    await widget.settingsRepository.completeOnboarding(
      profile: ExpertProfile(
        name: _name.text.trim(),
        role: _role.text.trim(),
        registration: _registration.text.trim(),
        organization: _organization.text.trim(),
        unit: _unit.text.trim(),
      ),
      activeAreas: _activeAreas.toList(),
    );
  }

  Future<void> _skip() async {
    setState(() => _saving = true);
    await widget.settingsRepository.skipOnboarding();
  }
}

class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.gold),
                ),
                child: const Icon(Icons.shield_outlined, color: AppColors.gold),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Bem-vindo ao SICRO Operacional',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Configure o perfil do perito e escolha quais areas deseja deixar visiveis na criacao de novas pericias.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
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

class _AreaCards extends StatelessWidget {
  const _AreaCards({required this.activeAreas, required this.onChanged});

  final Set<ForensicArea> activeAreas;
  final void Function(ForensicArea area, bool selected) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: ForensicArea.values.map((area) {
        final selected = activeAreas.contains(area);
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Card(
            child: CheckboxListTile(
              value: selected,
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
      ForensicArea.traffic => 'Transito fica pronto para uso agora',
      ForensicArea.violentDeath => 'Visibilidade preparada para modulo futuro',
      ForensicArea.property => 'Visibilidade preparada para modulo futuro',
    };
  }

  IconData _icon(ForensicArea area) {
    return switch (area) {
      ForensicArea.traffic => Icons.traffic_outlined,
      ForensicArea.violentDeath => Icons.health_and_safety_outlined,
      ForensicArea.property => Icons.domain_verification_outlined,
    };
  }
}
