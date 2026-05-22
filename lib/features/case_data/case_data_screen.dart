import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/data/occurrence_repository.dart';
import '../../domain/models/case_data.dart';
import '../../shared/widgets/empty_state.dart';

class CaseDataScreen extends StatefulWidget {
  const CaseDataScreen({
    required this.repository,
    required this.occurrenceId,
    super.key,
  });

  final OccurrenceRepository repository;
  final String occurrenceId;

  @override
  State<CaseDataScreen> createState() => _CaseDataScreenState();
}

class _CaseDataScreenState extends State<CaseDataScreen> {
  final _bo = TextEditingController();
  final _requisition = TextEditingController();
  final _protocol = TextEditingController();
  final _policeUnit = TextEditingController();
  final _municipality = TextEditingController();
  final _district = TextEditingController();
  final _street = TextEditingController();
  final _reference = TextEditingController();
  final _peritians = TextEditingController();
  final _supportTeam = TextEditingController();
  Timer? _saveTimer;
  bool _initialized = false;
  String? _lastSavedSignature;

  @override
  void initState() {
    super.initState();
    final occurrence = widget.repository.findById(widget.occurrenceId);
    if (occurrence == null) {
      return;
    }
    final data = occurrence.caseData;
    _bo.text = data.bo;
    _requisition.text = data.requisition;
    _protocol.text = data.protocol;
    _policeUnit.text = data.policeUnit;
    _municipality.text = data.municipality;
    _district.text = data.district;
    _street.text = data.street;
    _reference.text = data.reference;
    _peritians.text = data.peritians;
    _supportTeam.text = data.supportTeam;
    _lastSavedSignature = _signature(data);
    _initialized = true;
  }

  @override
  void dispose() {
    _saveNow();
    _saveTimer?.cancel();
    _bo.dispose();
    _requisition.dispose();
    _protocol.dispose();
    _policeUnit.dispose();
    _municipality.dispose();
    _district.dispose();
    _street.dispose();
    _reference.dispose();
    _peritians.dispose();
    _supportTeam.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final occurrence = widget.repository.findById(widget.occurrenceId);
    if (occurrence == null) {
      return const Scaffold(
        body: EmptyState(
          icon: Icons.error_outline,
          title: 'Ocorrencia nao encontrada',
          message: 'Nao foi possivel editar os dados do caso.',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dados do caso'),
        actions: [
          IconButton(
            tooltip: 'Salvar',
            onPressed: _saveAndClose,
            icon: const Icon(Icons.check),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Field(
              controller: _bo,
              label: 'BO',
              icon: Icons.tag,
              onChanged: _scheduleSave,
            ),
            _Field(
              controller: _requisition,
              label: 'Requisicao',
              icon: Icons.description_outlined,
              onChanged: _scheduleSave,
            ),
            _Field(
              controller: _protocol,
              label: 'Protocolo',
              icon: Icons.folder_outlined,
              onChanged: _scheduleSave,
            ),
            _Field(
              controller: _policeUnit,
              label: 'Delegacia / unidade',
              icon: Icons.account_balance_outlined,
              onChanged: _scheduleSave,
            ),
            _Field(
              controller: _municipality,
              label: 'Municipio',
              icon: Icons.location_city_outlined,
              onChanged: _scheduleSave,
            ),
            _Field(
              controller: _district,
              label: 'Bairro',
              icon: Icons.map_outlined,
              onChanged: _scheduleSave,
            ),
            _Field(
              controller: _street,
              label: 'Logradouro',
              icon: Icons.place_outlined,
              onChanged: _scheduleSave,
            ),
            _Field(
              controller: _reference,
              label: 'Complemento / referencia',
              icon: Icons.signpost_outlined,
              onChanged: _scheduleSave,
            ),
            _Field(
              controller: _peritians,
              label: 'Peritos presentes',
              icon: Icons.badge_outlined,
              onChanged: _scheduleSave,
            ),
            _Field(
              controller: _supportTeam,
              label: 'Equipe de apoio',
              icon: Icons.groups_outlined,
              onChanged: _scheduleSave,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _saveAndClose,
              icon: const Icon(Icons.check),
              label: const Text('Salvar dados do caso'),
            ),
          ],
        ),
      ),
    );
  }

  void _scheduleSave(String _) {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 450), _saveNow);
  }

  void _saveNow() {
    _saveTimer?.cancel();
    if (!_initialized) {
      return;
    }
    unawaited(_persist());
  }

  Future<void> _saveAndClose() async {
    _saveTimer?.cancel();
    if (_initialized) {
      await _persist();
    }
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _persist() async {
    final data = CaseData(
      bo: _bo.text.trim(),
      requisition: _requisition.text.trim(),
      protocol: _protocol.text.trim(),
      policeUnit: _policeUnit.text.trim(),
      municipality: _municipality.text.trim(),
      district: _district.text.trim(),
      street: _street.text.trim(),
      reference: _reference.text.trim(),
      peritians: _peritians.text.trim(),
      supportTeam: _supportTeam.text.trim(),
    );
    final signature = _signature(data);
    if (_lastSavedSignature == signature) {
      return;
    }
    _lastSavedSignature = signature;
    await widget.repository.updateCaseData(widget.occurrenceId, data);
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      ),
    );
  }
}

String _signature(CaseData data) {
  return [
    data.bo,
    data.requisition,
    data.protocol,
    data.policeUnit,
    data.municipality,
    data.district,
    data.street,
    data.reference,
    data.peritians,
    data.supportTeam,
  ].join('|');
}
