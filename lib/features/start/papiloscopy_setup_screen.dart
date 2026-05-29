import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/data/occurrence_repository.dart';
import '../../domain/models/case_data.dart';
import '../../domain/models/forensic_case_metadata.dart';
import '../../features/occurrences/occurrence_dashboard_screen.dart';

class PapiloscopySetupScreen extends StatefulWidget {
  const PapiloscopySetupScreen({required this.repository, super.key});

  final OccurrenceRepository repository;

  @override
  State<PapiloscopySetupScreen> createState() => _PapiloscopySetupScreenState();
}

class _PapiloscopySetupScreenState extends State<PapiloscopySetupScreen> {
  PapiloscopyNature _nature = PapiloscopyNature.crimeScenePrints;
  PapiloscopyContext _context = PapiloscopyContext.crimeScene;
  late final Set<ExpectedPapiloscopyEvidence> _expectedEvidences =
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
      appBar: AppBar(title: const Text('Papiloscopia')),
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
        type: ForensicCaseType.papiloscopy,
        papiloscopyNature: _nature,
        papiloscopyContext: _context,
        expectedPapiloscopyEvidences: _expectedEvidences.toList(),
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
            child: const Icon(Icons.fingerprint, color: AppColors.gold),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Configuracao inicial de papiloscopia',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Identificacao criminal, levantamento em local, laboratorio e necropapiloscopia conforme POP federal.',
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

  final PapiloscopyNature selected;
  final ValueChanged<PapiloscopyNature> onSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Natureza do exame',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: PapiloscopyNature.values.map((nature) {
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

  final PapiloscopyContext selected;
  final ValueChanged<PapiloscopyContext> onSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Contexto',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: PapiloscopyContext.values.map((context) {
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

  final Set<ExpectedPapiloscopyEvidence> selected;
  final void Function(ExpectedPapiloscopyEvidence evidence, bool selected)
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
              children: ExpectedPapiloscopyEvidence.values.map((evidence) {
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

  final PapiloscopyNature nature;

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

  List<String> _focusItems(PapiloscopyNature nature) {
    return switch (nature) {
      PapiloscopyNature.criminalIdentification => const [
        'Conferir dados do identificado, consentimento/recusa e condicoes das maos',
        'Coletar digitais batidas, roladas, palmares e hipotenar sem troca de dedos',
        'Registrar fotografia sinaletica, peculiaridades e qualidade para AFIS/ABIS',
      ],
      PapiloscopyNature.crimeScenePrints => const [
        'Avaliar superficies antes de manipulacao e priorizar vestigios vulneraveis',
        'Fotografar impressoes com escala antes de revelacao, decalque ou coleta',
        'Escolher tecnica conforme suporte e preservar DNA/outros exames quando aplicavel',
      ],
      PapiloscopyNature.labPrints => const [
        'Registrar lacres, embalagem, requisicao e condicao de recebimento',
        'Selecionar reagente/tecnica conforme superficie e FISPQ/EPI/EPC',
        'Reacondicionar material, lacrar e registrar destino/cadeia de custodia',
      ],
      PapiloscopyNature.necropapiloscopy => const [
        'Conferir identificacao do corpo e escolher tecnica pela condicao da pele',
        'Evitar inversao de maos/dedos e sobreposicao dos datilogramas',
        'Espelhar fotografias diretas/face interna quando necessario e validar AFIS/ABIS',
      ],
      PapiloscopyNature.other => const [
        'Definir objetivo, suporte questionado e tecnica papiloscopica prevista',
        'Registrar fotos, qualidade, limitacoes e cadeia de custodia',
        'Organizar dados para confronto e integracao futura com o SICRO Desktop',
      ],
    };
  }

  IconData _icon(PapiloscopyNature nature) {
    return switch (nature) {
      PapiloscopyNature.criminalIdentification => Icons.badge_outlined,
      PapiloscopyNature.crimeScenePrints => Icons.manage_search_outlined,
      PapiloscopyNature.labPrints => Icons.science_outlined,
      PapiloscopyNature.necropapiloscopy => Icons.health_and_safety_outlined,
      PapiloscopyNature.other => Icons.fingerprint,
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
            labelText: 'Local / referencia / origem do material',
            prefixIcon: Icon(Icons.place_outlined),
          ),
        ),
      ],
    );
  }
}

PapiloscopyContext _defaultContextFor(PapiloscopyNature nature) {
  return switch (nature) {
    PapiloscopyNature.criminalIdentification => PapiloscopyContext.livingPerson,
    PapiloscopyNature.crimeScenePrints => PapiloscopyContext.crimeScene,
    PapiloscopyNature.labPrints => PapiloscopyContext.lab,
    PapiloscopyNature.necropapiloscopy => PapiloscopyContext.cadaver,
    PapiloscopyNature.other => PapiloscopyContext.crimeScene,
  };
}

List<ExpectedPapiloscopyEvidence> _defaultEvidencesFor(
  PapiloscopyNature nature,
) {
  return switch (nature) {
    PapiloscopyNature.criminalIdentification => const [
      ExpectedPapiloscopyEvidence.fingerprints,
      ExpectedPapiloscopyEvidence.palmprints,
      ExpectedPapiloscopyEvidence.biometricCapture,
      ExpectedPapiloscopyEvidence.afisAbis,
      ExpectedPapiloscopyEvidence.photographs,
    ],
    PapiloscopyNature.crimeScenePrints => const [
      ExpectedPapiloscopyEvidence.latentPrints,
      ExpectedPapiloscopyEvidence.patentPrints,
      ExpectedPapiloscopyEvidence.plasticPrints,
      ExpectedPapiloscopyEvidence.questionedObjects,
      ExpectedPapiloscopyEvidence.adhesiveLifts,
      ExpectedPapiloscopyEvidence.photographs,
    ],
    PapiloscopyNature.labPrints => const [
      ExpectedPapiloscopyEvidence.questionedObjects,
      ExpectedPapiloscopyEvidence.latentPrints,
      ExpectedPapiloscopyEvidence.patentPrints,
      ExpectedPapiloscopyEvidence.adhesiveLifts,
      ExpectedPapiloscopyEvidence.chemicalReagents,
      ExpectedPapiloscopyEvidence.photographs,
    ],
    PapiloscopyNature.necropapiloscopy => const [
      ExpectedPapiloscopyEvidence.necropapillaryMaterial,
      ExpectedPapiloscopyEvidence.fingerprints,
      ExpectedPapiloscopyEvidence.palmprints,
      ExpectedPapiloscopyEvidence.photographs,
      ExpectedPapiloscopyEvidence.afisAbis,
    ],
    PapiloscopyNature.other => const [
      ExpectedPapiloscopyEvidence.latentPrints,
      ExpectedPapiloscopyEvidence.questionedObjects,
      ExpectedPapiloscopyEvidence.photographs,
      ExpectedPapiloscopyEvidence.afisAbis,
    ],
  };
}
