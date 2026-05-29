import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/data/occurrence_repository.dart';
import '../../domain/models/case_data.dart';
import '../../domain/models/forensic_case_metadata.dart';
import '../../features/occurrences/occurrence_dashboard_screen.dart';

class BallisticsSetupScreen extends StatefulWidget {
  const BallisticsSetupScreen({required this.repository, super.key});

  final OccurrenceRepository repository;

  @override
  State<BallisticsSetupScreen> createState() => _BallisticsSetupScreenState();
}

class _BallisticsSetupScreenState extends State<BallisticsSetupScreen> {
  BallisticsNature _nature = BallisticsNature.ballisticComparison;
  BallisticsContext _context = BallisticsContext.seizedMaterial;
  late final Set<ExpectedBallisticEvidence> _expectedEvidences =
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
      appBar: AppBar(title: const Text('Balistica Forense')),
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
        type: ForensicCaseType.ballistics,
        ballisticsNature: _nature,
        ballisticsContext: _context,
        expectedBallisticEvidences: _expectedEvidences.toList(),
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
            child: const Icon(Icons.adjust_outlined, color: AppColors.gold),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Configuracao inicial de balistica',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Naturezas e pontos de atencao alinhados ao POP federal de Balistica Forense.',
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

  final BallisticsNature selected;
  final ValueChanged<BallisticsNature> onSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Natureza balistica',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: BallisticsNature.values.map((nature) {
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

  final BallisticsContext selected;
  final ValueChanged<BallisticsContext> onSelected;

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
              children: BallisticsContext.values.map((context) {
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

  final Set<ExpectedBallisticEvidence> selected;
  final void Function(ExpectedBallisticEvidence evidence, bool selected)
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
              children: ExpectedBallisticEvidence.values.map((evidence) {
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

  final BallisticsNature nature;

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

  List<String> _focusItems(BallisticsNature nature) {
    return switch (nature) {
      BallisticsNature.ballisticComparison => const [
        'Recebimento, involucros, lacres e compatibilidade documental',
        'Caracterizacao de armas, estojos, projeteis e cartuchos',
        'Coleta de padroes, individualizacao e comparacao microbalistica',
      ],
      BallisticsNature.gsrCollection => const [
        'Preservacao das superficies e prevencao de contaminacao',
        'Coleta por stub com fita dupla face de carbono',
        'Identificacao, acondicionamento e ficha de coleta de residuos',
      ],
      BallisticsNature.firearmEfficiency => const [
        'Arma tratada como carregada ate verificacao final',
        'Inspecao externa, registro fotografico e caracterizacao individual',
        'Teste seguro, EPI, acionamento remoto quando necessario',
      ],
      BallisticsNature.ammunitionEfficiency => const [
        'Cartuchos separados por calibre, origem, fabricante e caracteristicas',
        'Inspecao de percussao, corrosao, recarga, dano ou impedimento',
        'Teste de eficiencia seguro, amostragem e destino do remanescente',
      ],
      BallisticsNature.other => const [
        'Material recebido, lacres, documentos e cadeia de custodia',
        'Riscos, EPI, preservacao de vestigios complementares',
        'Fotos, caracterizacao e observacoes tecnicas relevantes',
      ],
    };
  }

  IconData _icon(BallisticsNature nature) {
    return switch (nature) {
      BallisticsNature.ballisticComparison => Icons.compare_arrows_outlined,
      BallisticsNature.gsrCollection => Icons.science_outlined,
      BallisticsNature.firearmEfficiency => Icons.gps_fixed_outlined,
      BallisticsNature.ammunitionEfficiency => Icons.adjust_outlined,
      BallisticsNature.other => Icons.fact_check_outlined,
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

BallisticsContext _defaultContextFor(BallisticsNature nature) {
  return switch (nature) {
    BallisticsNature.ballisticComparison => BallisticsContext.seizedMaterial,
    BallisticsNature.gsrCollection => BallisticsContext.suspect,
    BallisticsNature.firearmEfficiency => BallisticsContext.lab,
    BallisticsNature.ammunitionEfficiency => BallisticsContext.lab,
    BallisticsNature.other => BallisticsContext.seizedMaterial,
  };
}

List<ExpectedBallisticEvidence> _defaultEvidencesFor(BallisticsNature nature) {
  return switch (nature) {
    BallisticsNature.ballisticComparison => const [
      ExpectedBallisticEvidence.firearm,
      ExpectedBallisticEvidence.cases,
      ExpectedBallisticEvidence.projectiles,
      ExpectedBallisticEvidence.ballisticStandards,
      ExpectedBallisticEvidence.packagesSeals,
      ExpectedBallisticEvidence.documents,
    ],
    BallisticsNature.gsrCollection => const [
      ExpectedBallisticEvidence.gsr,
      ExpectedBallisticEvidence.clothing,
      ExpectedBallisticEvidence.vehicleSurface,
      ExpectedBallisticEvidence.packagesSeals,
      ExpectedBallisticEvidence.documents,
    ],
    BallisticsNature.firearmEfficiency => const [
      ExpectedBallisticEvidence.firearm,
      ExpectedBallisticEvidence.ammunition,
      ExpectedBallisticEvidence.ballisticStandards,
      ExpectedBallisticEvidence.packagesSeals,
      ExpectedBallisticEvidence.documents,
    ],
    BallisticsNature.ammunitionEfficiency => const [
      ExpectedBallisticEvidence.ammunition,
      ExpectedBallisticEvidence.cases,
      ExpectedBallisticEvidence.projectiles,
      ExpectedBallisticEvidence.packagesSeals,
      ExpectedBallisticEvidence.documents,
    ],
    BallisticsNature.other => const [
      ExpectedBallisticEvidence.firearm,
      ExpectedBallisticEvidence.ammunition,
      ExpectedBallisticEvidence.packagesSeals,
      ExpectedBallisticEvidence.documents,
    ],
  };
}
