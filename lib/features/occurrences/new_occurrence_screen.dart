import 'package:flutter/material.dart';

import '../../core/data/occurrence_repository.dart';
import '../../domain/models/case_data.dart';
import 'occurrence_dashboard_screen.dart';

class NewOccurrenceScreen extends StatefulWidget {
  const NewOccurrenceScreen({required this.repository, super.key});

  final OccurrenceRepository repository;

  @override
  State<NewOccurrenceScreen> createState() => _NewOccurrenceScreenState();
}

class _NewOccurrenceScreenState extends State<NewOccurrenceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _bo = TextEditingController();
  final _requisition = TextEditingController();
  final _protocol = TextEditingController();
  final _municipality = TextEditingController(text: 'Macapa');
  final _street = TextEditingController();

  @override
  void dispose() {
    _bo.dispose();
    _requisition.dispose();
    _protocol.dispose();
    _municipality.dispose();
    _street.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nova ocorrencia')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Dados iniciais',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _bo,
                decoration: const InputDecoration(
                  labelText: 'BO',
                  prefixIcon: Icon(Icons.tag),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _requisition,
                decoration: const InputDecoration(
                  labelText: 'Requisicao',
                  prefixIcon: Icon(Icons.description_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _protocol,
                decoration: const InputDecoration(
                  labelText: 'Protocolo',
                  prefixIcon: Icon(Icons.folder_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _municipality,
                decoration: const InputDecoration(
                  labelText: 'Municipio',
                  prefixIcon: Icon(Icons.location_city_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Informe o municipio';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _street,
                decoration: const InputDecoration(
                  labelText: 'Logradouro / referencia',
                  prefixIcon: Icon(Icons.place_outlined),
                ),
                minLines: 1,
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _create,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Criar ocorrencia'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final occurrence = await widget.repository.createOccurrence(
      CaseData(
        bo: _bo.text.trim(),
        requisition: _requisition.text.trim(),
        protocol: _protocol.text.trim(),
        municipality: _municipality.text.trim(),
        street: _street.text.trim(),
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
