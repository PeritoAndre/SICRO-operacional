import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/data/occurrence_repository.dart';
import '../../domain/models/case_data.dart';
import '../../domain/models/forensic_case_metadata.dart';
import '../../features/occurrences/occurrence_dashboard_screen.dart';

class PropertySetupScreen extends StatefulWidget {
  const PropertySetupScreen({required this.repository, super.key});

  final OccurrenceRepository repository;

  @override
  State<PropertySetupScreen> createState() => _PropertySetupScreenState();
}

class _PropertySetupScreenState extends State<PropertySetupScreen> {
  PropertyNature _nature = PropertyNature.directEvaluation;
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
      appBar: AppBar(title: const Text('Patrimonio')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            const _Header(),
            const SizedBox(height: 14),
            _NatureCard(
              selected: _nature,
              onSelected: (nature) => setState(() => _nature = nature),
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
        type: ForensicCaseType.property,
        propertyNature: _nature,
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
            child: const Icon(
              Icons.domain_verification_outlined,
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
                  'Selecione a natureza real do atendimento e siga para o dossie.',
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

  final PropertyNature selected;
  final ValueChanged<PropertyNature> onSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Natureza',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: PropertyNature.values.map((nature) {
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

class _FocusCard extends StatelessWidget {
  const _FocusCard({required this.nature});

  final PropertyNature nature;

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

  List<String> _focusItems(PropertyNature nature) {
    return switch (nature) {
      PropertyNature.directEvaluation => const [
        'Bem, descricao e estado de conservacao',
        'Valor ou referencia de avaliacao',
        'Documentacao e fotos',
      ],
      PropertyNature.indirectEvaluation => const [
        'Fontes indiretas e documentacao disponivel',
        'Descricao e estado informado do bem',
        'Valor ou referencia de avaliacao',
      ],
      PropertyNature.damages => const [
        'Bem ou estrutura danificada',
        'Extensao do dano e causa aparente',
        'Medicoes e fotos de detalhe',
      ],
      PropertyNature.burglary => const [
        'Ponto de acesso e marcas de ferramenta',
        'Rompimentos, fechaduras, portas e janelas',
        'Vestigios e fotos de detalhe',
      ],
      PropertyNature.fire => const [
        'Foco provavel e padrao de queima',
        'Danos termicos, fuligem e residuos',
        'Material combustivel e area afetada',
      ],
    };
  }

  IconData _icon(PropertyNature nature) {
    return switch (nature) {
      PropertyNature.directEvaluation => Icons.inventory_2_outlined,
      PropertyNature.indirectEvaluation => Icons.description_outlined,
      PropertyNature.damages => Icons.broken_image_outlined,
      PropertyNature.burglary => Icons.lock_open_outlined,
      PropertyNature.fire => Icons.local_fire_department_outlined,
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
