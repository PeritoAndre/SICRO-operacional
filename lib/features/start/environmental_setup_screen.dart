import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/data/occurrence_repository.dart';
import '../../domain/models/case_data.dart';
import '../../domain/models/forensic_case_metadata.dart';
import '../../features/occurrences/occurrence_dashboard_screen.dart';

class EnvironmentalSetupScreen extends StatefulWidget {
  const EnvironmentalSetupScreen({required this.repository, super.key});

  final OccurrenceRepository repository;

  @override
  State<EnvironmentalSetupScreen> createState() =>
      _EnvironmentalSetupScreenState();
}

class _EnvironmentalSetupScreenState extends State<EnvironmentalSetupScreen> {
  EnvironmentalNature _nature = EnvironmentalNature.deforestation;
  EnvironmentalSceneContext _context = EnvironmentalSceneContext.ruralArea;
  late final Set<ExpectedEnvironmentalEvidence> _expectedEvidences =
      _defaultEvidencesFor(_nature).toSet();

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
      appBar: AppBar(title: const Text('Pericia ambiental')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            const _Header(),
            const SizedBox(height: 14),
            _NatureCard(
              selected: _nature,
              onSelected: (nature) {
                setState(() {
                  _nature = nature;
                  _context = _defaultContextFor(nature);
                  _expectedEvidences
                    ..clear()
                    ..addAll(_defaultEvidencesFor(nature));
                });
              },
            ),
            const SizedBox(height: 12),
            _ContextCard(
              selected: _context,
              onSelected: (context) => setState(() => _context = context),
            ),
            const SizedBox(height: 12),
            _EvidenceCard(
              selected: _expectedEvidences,
              onChanged: (evidence, selected) {
                setState(() {
                  if (selected) {
                    _expectedEvidences.add(evidence);
                  } else {
                    _expectedEvidences.remove(evidence);
                  }
                });
              },
            ),
            const SizedBox(height: 12),
            _FocusCard(nature: _nature),
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
        type: ForensicCaseType.environmental,
        environmentalNature: _nature,
        environmentalContext: _context,
        expectedEnvironmentalEvidences: _expectedEvidences.toList(),
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
  const _Header();

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
            child: const Icon(Icons.forest_outlined, color: AppColors.gold),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Configuracao inicial ambiental',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Naturezas e pontos de atencao alinhados ao POP federal de pericia criminal ambiental.',
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

class _NatureCard extends StatelessWidget {
  const _NatureCard({required this.selected, required this.onSelected});

  final EnvironmentalNature selected;
  final ValueChanged<EnvironmentalNature> onSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Natureza ambiental',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: EnvironmentalNature.values.map((nature) {
                return ChoiceChip(
                  label: Text(nature.label),
                  selected: selected == nature,
                  onSelected: (_) => onSelected(nature),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContextCard extends StatelessWidget {
  const _ContextCard({required this.selected, required this.onSelected});

  final EnvironmentalSceneContext selected;
  final ValueChanged<EnvironmentalSceneContext> onSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Contexto do local',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: EnvironmentalSceneContext.values.map((context) {
                return ChoiceChip(
                  label: Text(context.label),
                  selected: selected == context,
                  onSelected: (_) => onSelected(context),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _EvidenceCard extends StatelessWidget {
  const _EvidenceCard({required this.selected, required this.onChanged});

  final Set<ExpectedEnvironmentalEvidence> selected;
  final void Function(ExpectedEnvironmentalEvidence evidence, bool selected)
  onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Elementos esperados',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ExpectedEnvironmentalEvidence.values.map((evidence) {
                return FilterChip(
                  label: Text(evidence.label),
                  selected: selected.contains(evidence),
                  onSelected: (value) => onChanged(evidence, value),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _FocusCard extends StatelessWidget {
  const _FocusCard({required this.nature});

  final EnvironmentalNature nature;

  @override
  Widget build(BuildContext context) {
    final items = _focusItems(nature);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_icon(nature), color: AppColors.gold),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    nature.label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      size: 17,
                      color: AppColors.gold,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<String> _focusItems(EnvironmentalNature nature) {
    return switch (nature) {
      EnvironmentalNature.deforestation => const [
        'Area suprimida, bioma, fitofisionomia e regeneracao',
        'APP, reserva legal, unidade de conservacao ou area protegida',
        'Tocos, material lenhoso, imagens, GNSS e eventual coleta botanica',
      ],
      EnvironmentalNature.animalAbuse => const [
        'Caracterizacao do animal e do ambiente de manutencao',
        'Lesoes, sinais de sofrimento, condicao corporal e bem-estar',
        'Tutor/responsavel, documentos e necessidade de apoio veterinario',
      ],
      EnvironmentalNature.waterPollution => const [
        'Corpo hidrico, ponto de descarte, montante e jusante',
        'Odor, espuma, oleo/iridescencia, cor, turbidez e fauna/flora afetadas',
        'Amostras, acondicionamento, lacre e cadeia de custodia',
      ],
      EnvironmentalNature.forestFire => const [
        'Perimetro queimado, frente/flancos e zona de origem',
        'Indicadores de queima, fuligem, combustivel protegido e foco inicial',
        'Agente igneo, autoria possivel, danos e relacao com desmatamento',
      ],
      EnvironmentalNature.veterinaryNecropsy => const [
        'Recepcao, identificacao zoologica e cadeia de custodia',
        'Estado de conservacao, fenomenos cadavericos e lesoes',
        'Amostras, exames complementares e biosseguranca',
      ],
      EnvironmentalNature.other => const [
        'Caracterizacao ambiental do local',
        'Vestigios, coordenadas, fotos e documentos',
        'Amostras e cadeia de custodia quando houver coleta',
      ],
    };
  }

  IconData _icon(EnvironmentalNature nature) {
    return switch (nature) {
      EnvironmentalNature.deforestation => Icons.forest_outlined,
      EnvironmentalNature.animalAbuse => Icons.pets_outlined,
      EnvironmentalNature.waterPollution => Icons.water_drop_outlined,
      EnvironmentalNature.forestFire => Icons.local_fire_department_outlined,
      EnvironmentalNature.veterinaryNecropsy => Icons.biotech_outlined,
      EnvironmentalNature.other => Icons.eco_outlined,
    };
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

EnvironmentalSceneContext _defaultContextFor(EnvironmentalNature nature) {
  return switch (nature) {
    EnvironmentalNature.deforestation => EnvironmentalSceneContext.ruralArea,
    EnvironmentalNature.animalAbuse => EnvironmentalSceneContext.urbanArea,
    EnvironmentalNature.waterPollution => EnvironmentalSceneContext.waterBody,
    EnvironmentalNature.forestFire => EnvironmentalSceneContext.forestArea,
    EnvironmentalNature.veterinaryNecropsy =>
      EnvironmentalSceneContext.veterinaryFacility,
    EnvironmentalNature.other => EnvironmentalSceneContext.ruralArea,
  };
}

List<ExpectedEnvironmentalEvidence> _defaultEvidencesFor(
  EnvironmentalNature nature,
) {
  return switch (nature) {
    EnvironmentalNature.deforestation => const [
      ExpectedEnvironmentalEvidence.vegetationSuppression,
      ExpectedEnvironmentalEvidence.protectedAreaImpact,
      ExpectedEnvironmentalEvidence.waterBodyImpact,
      ExpectedEnvironmentalEvidence.documents,
    ],
    EnvironmentalNature.animalAbuse => const [
      ExpectedEnvironmentalEvidence.animalCondition,
      ExpectedEnvironmentalEvidence.biologicalMaterial,
      ExpectedEnvironmentalEvidence.animalCadaver,
      ExpectedEnvironmentalEvidence.documents,
    ],
    EnvironmentalNature.waterPollution => const [
      ExpectedEnvironmentalEvidence.waterBodyImpact,
      ExpectedEnvironmentalEvidence.effluentContaminant,
      ExpectedEnvironmentalEvidence.samples,
      ExpectedEnvironmentalEvidence.protectedAreaImpact,
    ],
    EnvironmentalNature.forestFire => const [
      ExpectedEnvironmentalEvidence.fireIndicators,
      ExpectedEnvironmentalEvidence.vegetationSuppression,
      ExpectedEnvironmentalEvidence.protectedAreaImpact,
      ExpectedEnvironmentalEvidence.samples,
    ],
    EnvironmentalNature.veterinaryNecropsy => const [
      ExpectedEnvironmentalEvidence.animalCadaver,
      ExpectedEnvironmentalEvidence.biologicalMaterial,
      ExpectedEnvironmentalEvidence.samples,
      ExpectedEnvironmentalEvidence.documents,
    ],
    EnvironmentalNature.other => const [
      ExpectedEnvironmentalEvidence.documents,
      ExpectedEnvironmentalEvidence.samples,
    ],
  };
}
