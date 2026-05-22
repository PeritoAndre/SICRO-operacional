import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/data/occurrence_repository.dart';
import '../../domain/models/case_data.dart';
import '../../domain/models/forensic_case_metadata.dart';
import '../../features/occurrences/occurrence_dashboard_screen.dart';

class ViolentDeathSetupScreen extends StatefulWidget {
  const ViolentDeathSetupScreen({required this.repository, super.key});

  final OccurrenceRepository repository;

  @override
  State<ViolentDeathSetupScreen> createState() =>
      _ViolentDeathSetupScreenState();
}

class _ViolentDeathSetupScreenState extends State<ViolentDeathSetupScreen> {
  ViolentDeathNature _nature = ViolentDeathNature.homicide;
  BodyState _bodyState = BodyState.notInformed;
  VictimCount _victimCount = VictimCount.notInformed;
  SceneEnvironment _environment = SceneEnvironment.residence;
  final Set<ExpectedViolentDeathTrace> _expectedTraces = {};

  final _bo = TextEditingController();
  final _protocol = TextEditingController();
  final _municipality = TextEditingController(text: 'Macapa');
  final _street = TextEditingController();
  bool _creating = false;

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
      appBar: AppBar(title: const Text('Morte violenta')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _Header(),
            const SizedBox(height: 14),
            _SectionCard(
              title: 'Natureza inicial',
              child: _ChoiceWrap<ViolentDeathNature>(
                values: ViolentDeathNature.values,
                selected: _nature,
                labelFor: (item) => item.label,
                onSelected: (item) => setState(() => _nature = item),
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Estado da vitima/corpo',
              subtitle: 'Campo recomendado para orientar a coleta inicial.',
              child: _ChoiceWrap<BodyState>(
                values: BodyState.values,
                selected: _bodyState,
                labelFor: (item) => item.label,
                onSelected: (item) => setState(() => _bodyState = item),
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Quantidade de vitimas',
              child: _ChoiceWrap<VictimCount>(
                values: VictimCount.values,
                selected: _victimCount,
                labelFor: (item) => item.label,
                onSelected: (item) => setState(() => _victimCount = item),
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Ambiente do local',
              child: _ChoiceWrap<SceneEnvironment>(
                values: SceneEnvironment.values,
                selected: _environment,
                labelFor: (item) => item.label,
                onSelected: (item) => setState(() => _environment = item),
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Vestigios esperados',
              subtitle:
                  'Marque apenas o que fizer sentido na chegada ao local.',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ExpectedViolentDeathTrace.values.map((item) {
                  return FilterChip(
                    label: Text(item.label),
                    selected: _expectedTraces.contains(item),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _expectedTraces.add(item);
                        } else {
                          _expectedTraces.remove(item);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            _InitialCaseFields(
              bo: _bo,
              protocol: _protocol,
              municipality: _municipality,
              street: _street,
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: _creating ? null : _createOccurrence,
              icon: _creating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.arrow_forward),
              label: const Text('Criar ocorrencia'),
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
        type: ForensicCaseType.violentDeath,
        violentDeathNature: _nature,
        bodyState: _bodyState,
        victimCount: _victimCount,
        sceneEnvironment: _environment,
        expectedViolentDeathTraces: _expectedTraces.toList(),
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
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.gold),
            ),
            child: const Icon(
              Icons.health_and_safety_outlined,
              color: AppColors.gold,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Configuracao inicial',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Registre o contexto minimo e siga para o dossie operacional.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _ChoiceWrap<T> extends StatelessWidget {
  const _ChoiceWrap({
    required this.values,
    required this.selected,
    required this.labelFor,
    required this.onSelected,
  });

  final List<T> values;
  final T selected;
  final String Function(T value) labelFor;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values.map((item) {
        return ChoiceChip(
          label: Text(labelFor(item)),
          selected: item == selected,
          onSelected: (_) => onSelected(item),
        );
      }).toList(),
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
