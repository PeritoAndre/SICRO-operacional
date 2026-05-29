import 'dart:io';

import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/data/official_document_repository.dart';
import '../../core/data/occurrence_repository.dart';
import '../../core/services/official_document_ocr_service.dart';
import '../../domain/models/case_data.dart';
import '../../domain/models/forensic_case_metadata.dart';
import '../../domain/models/official_document.dart';
import '../../domain/models/occurrence.dart';
import '../../features/occurrences/occurrence_dashboard_screen.dart';
import '../../shared/widgets/empty_state.dart';

class OfficialDocumentsScreen extends StatefulWidget {
  const OfficialDocumentsScreen({
    required this.repository,
    required this.occurrenceRepository,
    this.ocrService,
    super.key,
  });

  final OfficialDocumentRepository repository;
  final OccurrenceRepository occurrenceRepository;
  final OfficialDocumentOcrService? ocrService;

  @override
  State<OfficialDocumentsScreen> createState() =>
      _OfficialDocumentsScreenState();
}

class _OfficialDocumentsScreenState extends State<OfficialDocumentsScreen> {
  late final OfficialDocumentOcrService _ocrService;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _ocrService = widget.ocrService ?? OfficialDocumentOcrService();
  }

  @override
  void dispose() {
    _ocrService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.repository,
        widget.occurrenceRepository,
      ]),
      builder: (context, _) {
        final documents = widget.repository.documents;
        return Scaffold(
          appBar: AppBar(title: const Text('Oficios')),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              children: [
                const _OfficialDocumentsIntro(),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _busy ? null : _scanDocument,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.document_scanner_outlined),
                  label: const Text('Digitalizar oficio'),
                ),
                const SizedBox(height: 18),
                if (documents.isEmpty)
                  const EmptyState(
                    icon: Icons.mark_email_unread_outlined,
                    title: 'Nenhum oficio salvo',
                    message:
                        'Fotografe o oficio recebido para extrair dados impressos e guardar o controle local.',
                  )
                else
                  ...documents.map(
                    (document) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _OfficialDocumentCard(
                        document: document,
                        onOpen: () => _editDocument(document),
                        onOpenImage: () =>
                            _openDocumentImage(document.imagePath),
                        onCreateOccurrence: () =>
                            _createTrafficOccurrenceFromDocument(document),
                        onLinkOccurrence: () => _linkDocument(document),
                        onStatusChanged: (status) =>
                            _updateDocumentStatus(document, status),
                        onDelete: () => _confirmDelete(document),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _scanDocument() async {
    setState(() => _busy = true);
    OfficialDocumentScanDraft? draft;
    try {
      draft = await _ocrService.scanFromCamera();
      if (draft == null || !mounted) {
        return;
      }
      final document = await Navigator.of(context).push<OfficialDocument>(
        MaterialPageRoute(
          builder: (_) => OfficialDocumentReviewScreen(draft: draft),
        ),
      );
      if (document == null) {
        await _ocrService.deleteImage(draft.imagePath);
        return;
      }
      await widget.repository.saveDocument(document);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Oficio salvo com sucesso.')),
      );
    } catch (error) {
      if (draft != null) {
        await _ocrService.deleteImage(draft.imagePath);
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Falha ao digitalizar oficio: $error'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _editDocument(OfficialDocument document) async {
    final updated = await Navigator.of(context).push<OfficialDocument>(
      MaterialPageRoute(
        builder: (_) => OfficialDocumentReviewScreen(document: document),
      ),
    );
    if (updated == null) {
      return;
    }
    await widget.repository.saveDocument(updated);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Oficio atualizado.')));
  }

  void _openDocumentImage(String path) {
    if (path.trim().isEmpty) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OfficialDocumentImageScreen(imagePath: path),
      ),
    );
  }

  Future<void> _createTrafficOccurrenceFromDocument(
    OfficialDocument document,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Criar pericia a partir do oficio?'),
          content: const Text(
            'O SICRO criara uma ocorrencia de transito com BO, protocolo, local e veiculos sugeridos pelo oficio. Voce podera editar tudo depois.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Criar'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }

    final occurrence = await widget.occurrenceRepository.createOccurrence(
      CaseData(
        bo: document.boNumber,
        requisition: document.documentNumber,
        protocol: document.protocol,
        policeUnit: document.requestingUnit,
        municipality: document.municipality.trim().isEmpty
            ? 'Macapa'
            : document.municipality,
        district: document.district,
        street: document.address,
        reference: 'Criada a partir do ${document.displayTitle}.',
      ),
      metadata: ForensicCaseMetadata(
        type: ForensicCaseType.traffic,
        trafficNature: TrafficNature.collision,
        trafficInvolved: _trafficInvolvedFromDocument(document),
        result: OccurrenceResult.notInformed,
      ),
    );

    for (var index = 0; index < document.vehicles.length; index++) {
      final detected = document.vehicles[index];
      final created = await widget.occurrenceRepository.createVehicle(
        occurrence.id,
      );
      if (created == null) {
        continue;
      }
      await widget.occurrenceRepository.updateVehicle(
        occurrence.id,
        created.copyWith(
          identifier: 'V${index + 1}',
          plate: detected.plate,
          type: detected.type,
          model: detected.brandModel,
          color: detected.color,
          owner: detected.owner,
          note: [
            if (detected.renavam.isNotEmpty) 'RENAVAM: ${detected.renavam}',
            if (detected.chassis.isNotEmpty) 'Chassi: ${detected.chassis}',
            'Dados importados do ${document.displayTitle}.',
          ].join('\n'),
        ),
      );
    }

    await widget.repository.saveDocument(
      document.copyWith(
        status: OfficialDocumentStatus.linked,
        linkedOccurrenceId: occurrence.id,
      ),
    );

    if (!mounted) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OccurrenceDashboardScreen(
          repository: widget.occurrenceRepository,
          occurrenceId: occurrence.id,
          officialDocumentRepository: widget.repository,
        ),
      ),
    );
  }

  Future<void> _linkDocument(OfficialDocument document) async {
    final occurrences = widget.occurrenceRepository.occurrences;
    if (occurrences.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nenhuma ocorrencia local disponivel para vinculo.'),
        ),
      );
      return;
    }

    final selected = await showModalBottomSheet<FieldOccurrence>(
      context: context,
      backgroundColor: AppColors.panel,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            children: [
              Text(
                'Vincular oficio',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              for (final occurrence in occurrences)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.assignment_outlined),
                    title: Text(occurrence.metadata.summary),
                    subtitle: Text(occurrence.caseData.displayLocation),
                    trailing: Text(occurrence.status.label),
                    onTap: () => Navigator.of(context).pop(occurrence),
                  ),
                ),
            ],
          ),
        );
      },
    );

    if (selected == null) {
      return;
    }
    await widget.repository.saveDocument(
      document.copyWith(
        status: OfficialDocumentStatus.linked,
        linkedOccurrenceId: selected.id,
      ),
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Oficio vinculado a ${selected.metadata.summary}.'),
      ),
    );
  }

  Future<void> _updateDocumentStatus(
    OfficialDocument document,
    OfficialDocumentStatus status,
  ) async {
    await widget.repository.saveDocument(document.copyWith(status: status));
  }

  Future<void> _confirmDelete(OfficialDocument document) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Excluir oficio?'),
          content: const Text(
            'Esta acao removera o cadastro local e a foto do oficio. Nao podera ser desfeita.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    await widget.repository.deleteDocument(document.id);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Oficio excluido.')));
  }
}

class OfficialDocumentReviewScreen extends StatefulWidget {
  const OfficialDocumentReviewScreen({this.draft, this.document, super.key})
    : assert(draft != null || document != null);

  final OfficialDocumentScanDraft? draft;
  final OfficialDocument? document;

  @override
  State<OfficialDocumentReviewScreen> createState() =>
      _OfficialDocumentReviewScreenState();
}

class _OfficialDocumentReviewScreenState
    extends State<OfficialDocumentReviewScreen> {
  final _documentNumber = TextEditingController();
  final _boNumber = TextEditingController();
  final _protocol = TextEditingController();
  final _requestingUnit = TextEditingController();
  final _recipient = TextEditingController();
  final _subject = TextEditingController();
  final _requestedExam = TextEditingController();
  final _documentDateText = TextEditingController();
  final _eventDateTimeText = TextEditingController();
  final _municipality = TextEditingController();
  final _district = TextEditingController();
  final _address = TextEditingController();
  final _notes = TextEditingController();

  late final String _id;
  late final DateTime _createdAt;
  late final String _imagePath;
  late final String _imageSha256;
  late final String _extractedText;
  late List<OfficialDocumentVehicle> _vehicles;
  OfficialDocumentStatus _status = OfficialDocumentStatus.received;
  DateTime? _deadlineAt;

  @override
  void initState() {
    super.initState();
    final document = widget.document;
    final draft = widget.draft;
    final extraction = draft?.extraction;
    final now = DateTime.now();

    _id = document?.id ?? draft?.id ?? 'oficio_${now.microsecondsSinceEpoch}';
    _createdAt = document?.createdAt ?? now;
    _imagePath = document?.imagePath ?? draft?.imagePath ?? '';
    _imageSha256 = document?.imageSha256 ?? draft?.imageSha256 ?? '';
    _extractedText = document?.extractedText ?? draft?.extractedText ?? '';
    _vehicles = document?.vehicles ?? extraction?.vehicles ?? const [];
    _status = document?.status ?? OfficialDocumentStatus.received;
    _deadlineAt = document?.deadlineAt;

    _documentNumber.text =
        document?.documentNumber ?? extraction?.documentNumber ?? '';
    _boNumber.text = document?.boNumber ?? extraction?.boNumber ?? '';
    _protocol.text = document?.protocol ?? extraction?.protocol ?? '';
    _requestingUnit.text =
        document?.requestingUnit ?? extraction?.requestingUnit ?? '';
    _recipient.text = document?.recipient ?? extraction?.recipient ?? '';
    _subject.text = document?.subject ?? extraction?.subject ?? '';
    _requestedExam.text =
        document?.requestedExam ?? extraction?.requestedExam ?? '';
    _documentDateText.text =
        document?.documentDateText ?? extraction?.documentDateText ?? '';
    _eventDateTimeText.text =
        document?.eventDateTimeText ?? extraction?.eventDateTimeText ?? '';
    _municipality.text =
        document?.municipality ?? extraction?.municipality ?? '';
    _district.text = document?.district ?? extraction?.district ?? '';
    _address.text = document?.address ?? extraction?.address ?? '';
    _notes.text = document?.notes ?? '';
  }

  @override
  void dispose() {
    _documentNumber.dispose();
    _boNumber.dispose();
    _protocol.dispose();
    _requestingUnit.dispose();
    _recipient.dispose();
    _subject.dispose();
    _requestedExam.dispose();
    _documentDateText.dispose();
    _eventDateTimeText.dispose();
    _municipality.dispose();
    _district.dispose();
    _address.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.document == null ? 'Revisar oficio' : 'Editar oficio',
        ),
        actions: [
          IconButton(
            tooltip: 'Salvar',
            onPressed: _save,
            icon: const Icon(Icons.check),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          children: [
            _ReviewNotice(hasProtocol: _protocol.text.trim().isNotEmpty),
            const SizedBox(height: 12),
            _StatusPicker(
              value: _status,
              onChanged: (value) => setState(() => _status = value),
            ),
            const SizedBox(height: 12),
            if (_imagePath.isNotEmpty)
              _DocumentImagePreview(
                path: _imagePath,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        OfficialDocumentImageScreen(imagePath: _imagePath),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            _Field(
              controller: _documentNumber,
              label: 'Numero do oficio',
              icon: Icons.description_outlined,
            ),
            _Field(controller: _boNumber, label: 'BO', icon: Icons.tag),
            _Field(
              controller: _protocol,
              label: 'Protocolo PCI (conferir se manuscrito)',
              icon: Icons.edit_note_outlined,
            ),
            _Field(
              controller: _requestingUnit,
              label: 'Unidade solicitante',
              icon: Icons.account_balance_outlined,
              maxLines: 2,
            ),
            _Field(
              controller: _recipient,
              label: 'Destinatario',
              icon: Icons.person_outline,
              maxLines: 2,
            ),
            _Field(
              controller: _subject,
              label: 'Assunto',
              icon: Icons.subject_outlined,
            ),
            _Field(
              controller: _requestedExam,
              label: 'Exame solicitado',
              icon: Icons.fact_check_outlined,
            ),
            _Field(
              controller: _documentDateText,
              label: 'Data do oficio (texto)',
              icon: Icons.event_note_outlined,
            ),
            _Field(
              controller: _eventDateTimeText,
              label: 'Data/hora do fato ou exame informado',
              icon: Icons.schedule_outlined,
            ),
            _Field(
              controller: _municipality,
              label: 'Municipio',
              icon: Icons.location_city_outlined,
            ),
            _Field(
              controller: _district,
              label: 'Bairro',
              icon: Icons.map_outlined,
            ),
            _Field(
              controller: _address,
              label: 'Endereco/local',
              icon: Icons.place_outlined,
              maxLines: 2,
            ),
            _DeadlineTile(
              deadlineAt: _deadlineAt,
              onPick: _pickDeadline,
              onClear: () => setState(() => _deadlineAt = null),
            ),
            const SizedBox(height: 12),
            _VehiclesPreview(vehicles: _vehicles),
            const SizedBox(height: 12),
            _Field(
              controller: _notes,
              label: 'Observacoes',
              icon: Icons.notes_outlined,
              maxLines: 4,
            ),
            const SizedBox(height: 12),
            _ExtractedTextPreview(text: _extractedText),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: const Text('Salvar oficio revisado'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadlineAt ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _deadlineAt = DateTime(picked.year, picked.month, picked.day);
    });
  }

  void _save() {
    final now = DateTime.now();
    final document = OfficialDocument(
      id: _id,
      createdAt: _createdAt,
      updatedAt: now,
      status: _status,
      imagePath: _imagePath,
      imageSha256: _imageSha256,
      extractedText: _extractedText,
      documentNumber: _documentNumber.text.trim(),
      boNumber: _boNumber.text.trim(),
      protocol: _protocol.text.trim(),
      requestingUnit: _requestingUnit.text.trim(),
      recipient: _recipient.text.trim(),
      subject: _subject.text.trim(),
      requestedExam: _requestedExam.text.trim(),
      documentDateText: _documentDateText.text.trim(),
      eventDateTimeText: _eventDateTimeText.text.trim(),
      municipality: _municipality.text.trim(),
      district: _district.text.trim(),
      address: _address.text.trim(),
      deadlineAt: _deadlineAt,
      notes: _notes.text.trim(),
      vehicles: _vehicles,
      linkedOccurrenceId: widget.document?.linkedOccurrenceId,
    );
    Navigator.of(context).pop(document);
  }
}

class OfficialDocumentImageScreen extends StatelessWidget {
  const OfficialDocumentImageScreen({required this.imagePath, super.key});

  final String imagePath;

  @override
  Widget build(BuildContext context) {
    final file = File(imagePath);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Imagem do oficio'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: file.existsSync()
            ? InteractiveViewer(
                minScale: 0.6,
                maxScale: 5,
                child: Center(
                  child: Image.file(
                    file,
                    fit: BoxFit.contain,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
              )
            : const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Imagem do oficio nao encontrada neste aparelho.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ),
      ),
    );
  }
}

class _OfficialDocumentsIntro extends StatelessWidget {
  const _OfficialDocumentsIntro();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.mark_email_read_outlined, color: AppColors.gold),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Digitalize oficios fisicos, extraia o texto impresso e revise os campos antes de salvar. O protocolo manuscrito deve ser confirmado manualmente.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfficialDocumentCard extends StatelessWidget {
  const _OfficialDocumentCard({
    required this.document,
    required this.onOpen,
    required this.onOpenImage,
    required this.onCreateOccurrence,
    required this.onLinkOccurrence,
    required this.onStatusChanged,
    required this.onDelete,
  });

  final OfficialDocument document;
  final VoidCallback onOpen;
  final VoidCallback onOpenImage;
  final VoidCallback onCreateOccurrence;
  final VoidCallback onLinkOccurrence;
  final ValueChanged<OfficialDocumentStatus> onStatusChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DocumentThumb(path: document.imagePath, onTap: onOpenImage),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      document.displayTitle,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      document.displaySubtitle,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _MiniChip(document.status.label, AppColors.success),
                        if (document.protocol.trim().isEmpty)
                          const _MiniChip('Protocolo pendente', AppColors.gold)
                        else
                          const _MiniChip('Protocolo OK', AppColors.success),
                        if (document.deadlineAt != null)
                          _MiniChip(
                            'Prazo ${_dateLabel(document.deadlineAt!)}',
                            AppColors.textSecondary,
                          ),
                        if (document.vehicles.isNotEmpty)
                          _MiniChip(
                            '${document.vehicles.length} veiculo(s)',
                            AppColors.textSecondary,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'create_occurrence') {
                    onCreateOccurrence();
                  } else if (value == 'link_occurrence') {
                    onLinkOccurrence();
                  } else if (value.startsWith('status:')) {
                    onStatusChanged(
                      OfficialDocumentStatus.fromCode(
                        value.substring('status:'.length),
                      ),
                    );
                  } else if (value == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'create_occurrence',
                    child: Text('Criar pericia de transito'),
                  ),
                  const PopupMenuItem(
                    value: 'link_occurrence',
                    child: Text('Vincular ocorrencia existente'),
                  ),
                  const PopupMenuDivider(),
                  for (final status in OfficialDocumentStatus.values)
                    PopupMenuItem(
                      value: 'status:${status.code}',
                      child: Text('Status: ${status.label}'),
                    ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(value: 'delete', child: Text('Excluir')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewNotice extends StatelessWidget {
  const _ReviewNotice({required this.hasProtocol});

  final bool hasProtocol;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasProtocol ? AppColors.border : AppColors.gold,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            hasProtocol ? Icons.fact_check_outlined : Icons.edit_note_outlined,
            color: hasProtocol ? AppColors.gold : AppColors.danger,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              hasProtocol
                  ? 'Revise os campos extraidos antes de salvar o oficio.'
                  : 'O protocolo manuscrito raramente e confiavel no OCR. Confira esse campo manualmente antes de salvar.',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPicker extends StatelessWidget {
  const _StatusPicker({required this.value, required this.onChanged});

  final OfficialDocumentStatus value;
  final ValueChanged<OfficialDocumentStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<OfficialDocumentStatus>(
      initialValue: value,
      decoration: const InputDecoration(
        labelText: 'Status do oficio',
        prefixIcon: Icon(Icons.flag_outlined),
      ),
      items: OfficialDocumentStatus.values.map((status) {
        return DropdownMenuItem(value: status, child: Text(status.label));
      }).toList(),
      onChanged: (status) {
        if (status != null) {
          onChanged(status);
        }
      },
    );
  }
}

class _DocumentImagePreview extends StatelessWidget {
  const _DocumentImagePreview({required this.path, required this.onTap});

  final String path;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final file = File(path);
    if (!file.existsSync()) {
      return const SizedBox.shrink();
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Ink(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                file,
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            Container(
              margin: const EdgeInsets.all(10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.open_in_full, size: 16, color: Colors.white),
                  SizedBox(width: 6),
                  Text(
                    'Abrir imagem',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
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
}

class _DocumentThumb extends StatelessWidget {
  const _DocumentThumb({required this.path, required this.onTap});

  final String path;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final file = File(path);
    if (path.isEmpty || !file.existsSync()) {
      return Container(
        width: 76,
        height: 96,
        decoration: BoxDecoration(
          color: AppColors.panel,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: const Icon(Icons.description_outlined, color: AppColors.gold),
      );
    }
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(file, width: 76, height: 96, fit: BoxFit.cover),
          ),
          Container(
            margin: const EdgeInsets.all(5),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Icon(
              Icons.open_in_full,
              size: 13,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeadlineTile extends StatelessWidget {
  const _DeadlineTile({
    required this.deadlineAt,
    required this.onPick,
    required this.onClear,
  });

  final DateTime? deadlineAt;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.event_available_outlined, color: AppColors.gold),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              deadlineAt == null
                  ? 'Prazo nao definido'
                  : 'Prazo: ${_dateLabel(deadlineAt!)}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          TextButton(onPressed: onPick, child: const Text('Definir')),
          if (deadlineAt != null)
            IconButton(
              tooltip: 'Limpar prazo',
              onPressed: onClear,
              icon: const Icon(Icons.close),
            ),
        ],
      ),
    );
  }
}

class _VehiclesPreview extends StatelessWidget {
  const _VehiclesPreview({required this.vehicles});

  final List<OfficialDocumentVehicle> vehicles;

  @override
  Widget build(BuildContext context) {
    if (vehicles.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Veiculos detectados',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          ...vehicles.map(
            (vehicle) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                [
                  vehicle.displayTitle,
                  if (vehicle.type.isNotEmpty) vehicle.type,
                  if (vehicle.color.isNotEmpty) vehicle.color,
                  if (vehicle.owner.isNotEmpty) vehicle.owner,
                ].join(' - '),
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExtractedTextPreview extends StatelessWidget {
  const _ExtractedTextPreview({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: const Text('Texto reconhecido pelo OCR'),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: SelectableText(
              text,
              style: const TextStyle(
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color == AppColors.textSecondary
              ? AppColors.textSecondary
              : color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

List<TrafficInvolved> _trafficInvolvedFromDocument(OfficialDocument document) {
  final involved = <TrafficInvolved>{};
  for (final vehicle in document.vehicles) {
    final type = _fold('${vehicle.type} ${vehicle.brandModel}');
    if (type.contains('moto') || type.contains('motocicleta')) {
      involved.add(TrafficInvolved.motorcycle);
    } else if (type.contains('caminhao')) {
      involved.add(TrafficInvolved.truck);
    } else if (type.contains('onibus')) {
      involved.add(TrafficInvolved.bus);
    } else if (type.contains('bicicleta')) {
      involved.add(TrafficInvolved.bicycle);
    } else {
      involved.add(TrafficInvolved.car);
    }
  }
  return involved.toList();
}

String _fold(String value) {
  return value
      .toLowerCase()
      .replaceAll('\u00e1', 'a')
      .replaceAll('\u00e0', 'a')
      .replaceAll('\u00e3', 'a')
      .replaceAll('\u00e2', 'a')
      .replaceAll('\u00e9', 'e')
      .replaceAll('\u00ea', 'e')
      .replaceAll('\u00ed', 'i')
      .replaceAll('\u00f3', 'o')
      .replaceAll('\u00f4', 'o')
      .replaceAll('\u00f5', 'o')
      .replaceAll('\u00fa', 'u')
      .replaceAll('\u00e7', 'c');
}

String _dateLabel(DateTime date) {
  return '${_two(date.day)}/${_two(date.month)}/${date.year}';
}

String _two(int value) => value.toString().padLeft(2, '0');
