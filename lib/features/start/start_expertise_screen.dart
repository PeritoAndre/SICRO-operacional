import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/data/app_settings_repository.dart';
import '../../core/data/occurrence_repository.dart';
import '../../domain/models/app_settings.dart';
import '../../domain/models/case_data.dart';
import '../../domain/models/forensic_case_metadata.dart';
import '../../features/occurrences/occurrence_dashboard_screen.dart';
import 'property_setup_screen.dart';
import 'violent_death_setup_screen.dart';

class StartExpertiseScreen extends StatefulWidget {
  const StartExpertiseScreen({
    required this.repository,
    required this.settingsRepository,
    super.key,
  });

  final OccurrenceRepository repository;
  final AppSettingsRepository settingsRepository;

  @override
  State<StartExpertiseScreen> createState() => _StartExpertiseScreenState();
}

class _StartExpertiseScreenState extends State<StartExpertiseScreen> {
  late final List<ForensicArea> _availableAreas;
  ForensicCaseType _type = ForensicCaseType.traffic;
  TrafficNature _trafficNature = TrafficNature.collision;
  final Set<TrafficInvolved> _trafficInvolved = {};
  OccurrenceResult _result = OccurrenceResult.notInformed;

  final _bo = TextEditingController();
  final _protocol = TextEditingController();
  final _municipality = TextEditingController(text: 'Macapa');
  final _street = TextEditingController();
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    final areas = widget.settingsRepository.settings.activeAreas;
    _availableAreas = List.unmodifiable(
      areas.isEmpty ? const [ForensicArea.traffic] : areas,
    );
    if (!_availableAreas.contains(ForensicArea.traffic)) {
      _type = _caseTypeForArea(_availableAreas.first);
    }
  }

  @override
  void dispose() {
    _bo.dispose();
    _protocol.dispose();
    _municipality.dispose();
    _street.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Iniciar pericia')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Text(
              'Tipo de pericia',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              'Escolha a area e informe os metadados iniciais da ocorrencia.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            _AreaChoices(
              activeAreas: _availableAreas,
              selectedType: _type,
              onSelected: _selectType,
            ),
            const SizedBox(height: 16),
            if (_type == ForensicCaseType.traffic)
              _TrafficForm(
                nature: _trafficNature,
                involved: _trafficInvolved,
                result: _result,
                onNatureChanged: (value) {
                  setState(() {
                    _trafficNature = value;
                    if (_trafficNature != TrafficNature.collision) {
                      _trafficInvolved.clear();
                    }
                  });
                },
                onInvolvedChanged: (item, selected) {
                  setState(() {
                    if (selected) {
                      _trafficInvolved.add(item);
                    } else {
                      _trafficInvolved.remove(item);
                    }
                  });
                },
                onResultChanged: (value) => setState(() => _result = value),
              )
            else if (_type == ForensicCaseType.violentDeath)
              _ViolentDeathEntryPanel(onTap: _openViolentDeathSetup)
            else if (_type == ForensicCaseType.property)
              _PropertyEntryPanel(onTap: _openPropertySetup)
            else
              _FutureModuleNotice(type: _type),
            const SizedBox(height: 16),
            _InitialCaseFields(
              bo: _bo,
              protocol: _protocol,
              municipality: _municipality,
              street: _street,
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: _creating
                  ? null
                  : _type == ForensicCaseType.traffic
                  ? _createOccurrence
                  : _type == ForensicCaseType.violentDeath
                  ? _openViolentDeathSetup
                  : _type == ForensicCaseType.property
                  ? _openPropertySetup
                  : null,
              icon: _creating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.arrow_forward),
              label: Text(
                _type == ForensicCaseType.traffic
                    ? 'Criar ocorrencia'
                    : _type == ForensicCaseType.violentDeath
                    ? 'Configurar morte violenta'
                    : _type == ForensicCaseType.property
                    ? 'Configurar patrimonio'
                    : 'Modulo em preparacao',
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createOccurrence() async {
    setState(() => _creating = true);
    final occurrence = await widget.repository.createOccurrence(
      CaseData(
        bo: _bo.text.trim(),
        protocol: _protocol.text.trim(),
        municipality: _municipality.text.trim().isEmpty
            ? 'Macapa'
            : _municipality.text.trim(),
        street: _street.text.trim(),
      ),
      metadata: ForensicCaseMetadata(
        type: _type,
        trafficNature: _trafficNature,
        trafficInvolved: _trafficNature == TrafficNature.collision
            ? _trafficInvolved.toList()
            : const [],
        result: _result,
      ),
    );
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => OccurrenceDashboardScreen(
          repository: widget.repository,
          occurrenceId: occurrence.id,
        ),
      ),
    );
  }

  void _selectType(ForensicCaseType type) {
    setState(() => _type = type);
  }

  void _openViolentDeathSetup() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ViolentDeathSetupScreen(repository: widget.repository),
      ),
    );
  }

  void _openPropertySetup() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PropertySetupScreen(repository: widget.repository),
      ),
    );
  }

  ForensicCaseType _caseTypeForArea(ForensicArea area) {
    return switch (area) {
      ForensicArea.traffic => ForensicCaseType.traffic,
      ForensicArea.violentDeath => ForensicCaseType.violentDeath,
      ForensicArea.property => ForensicCaseType.property,
    };
  }
}

class _AreaChoices extends StatelessWidget {
  const _AreaChoices({
    required this.activeAreas,
    required this.selectedType,
    required this.onSelected,
  });

  final List<ForensicArea> activeAreas;
  final ForensicCaseType selectedType;
  final ValueChanged<ForensicCaseType> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: activeAreas.map((area) {
        final type = _caseTypeForArea(area);
        final selected = type == selectedType;
        return ChoiceChip(
          avatar: Icon(
            _icon(type),
            size: 18,
            color: selected ? AppColors.base : AppColors.gold,
          ),
          label: Text(type.label),
          selected: selected,
          onSelected: (_) => onSelected(type),
        );
      }).toList(),
    );
  }

  ForensicCaseType _caseTypeForArea(ForensicArea area) {
    return switch (area) {
      ForensicArea.traffic => ForensicCaseType.traffic,
      ForensicArea.violentDeath => ForensicCaseType.violentDeath,
      ForensicArea.property => ForensicCaseType.property,
    };
  }

  IconData _icon(ForensicCaseType type) {
    return switch (type) {
      ForensicCaseType.traffic => Icons.traffic_outlined,
      ForensicCaseType.violentDeath => Icons.health_and_safety_outlined,
      ForensicCaseType.property => Icons.domain_verification_outlined,
    };
  }
}

class _TrafficForm extends StatelessWidget {
  const _TrafficForm({
    required this.nature,
    required this.involved,
    required this.result,
    required this.onNatureChanged,
    required this.onInvolvedChanged,
    required this.onResultChanged,
  });

  final TrafficNature nature;
  final Set<TrafficInvolved> involved;
  final OccurrenceResult result;
  final ValueChanged<TrafficNature> onNatureChanged;
  final void Function(TrafficInvolved item, bool selected) onInvolvedChanged;
  final ValueChanged<OccurrenceResult> onResultChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Transito',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            const Text(
              'Natureza',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: TrafficNature.values.map((item) {
                return ChoiceChip(
                  label: Text(item.label),
                  selected: nature == item,
                  onSelected: (_) => onNatureChanged(item),
                );
              }).toList(),
            ),
            if (nature == TrafficNature.collision) ...[
              const SizedBox(height: 16),
              const Text(
                'Envolvidos',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: TrafficInvolved.values.map((item) {
                  return FilterChip(
                    label: Text(item.label),
                    selected: involved.contains(item),
                    onSelected: (selected) => onInvolvedChanged(item, selected),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'Resultado',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: OccurrenceResult.values.map((item) {
                return ChoiceChip(
                  label: Text(item.label),
                  selected: result == item,
                  onSelected: (_) => onResultChanged(item),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _FutureModuleNotice extends StatelessWidget {
  const _FutureModuleNotice({required this.type});

  final ForensicCaseType type;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.construction_outlined, color: AppColors.gold),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${type.label} ja aparece como area ativa, mas o fluxo operacional sera implementado depois do MVP de transito.',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ViolentDeathEntryPanel extends StatelessWidget {
  const _ViolentDeathEntryPanel({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.health_and_safety_outlined,
                  color: AppColors.gold,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Morte violenta',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Abra a configuracao inicial para informar natureza, contexto do corpo, ambiente e vestigios esperados.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Abrir configuracao'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PropertyEntryPanel extends StatelessWidget {
  const _PropertyEntryPanel({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.domain_verification_outlined,
                  color: AppColors.gold,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Patrimonio',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Use o fluxo simplificado para avaliacao direta, avaliacao indireta, danos, arrombamento ou incendio.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Abrir configuracao'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InitialCaseFields extends StatelessWidget {
  const _InitialCaseFields({
    required this.bo,
    required this.protocol,
    required this.municipality,
    required this.street,
  });

  final TextEditingController bo;
  final TextEditingController protocol;
  final TextEditingController municipality;
  final TextEditingController street;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dados iniciais',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: bo,
          decoration: const InputDecoration(
            labelText: 'BO',
            prefixIcon: Icon(Icons.tag),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: protocol,
          decoration: const InputDecoration(
            labelText: 'Protocolo',
            prefixIcon: Icon(Icons.folder_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: municipality,
          decoration: const InputDecoration(
            labelText: 'Municipio',
            prefixIcon: Icon(Icons.location_city_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: street,
          minLines: 1,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Logradouro / referencia',
            prefixIcon: Icon(Icons.place_outlined),
          ),
        ),
      ],
    );
  }
}
