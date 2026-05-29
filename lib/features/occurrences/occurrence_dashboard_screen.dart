import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/theme/app_theme.dart';
import '../../core/data/official_document_repository.dart';
import '../../core/data/occurrence_repository.dart';
import '../../core/data/sicrocampo_export_service.dart';
import '../../domain/models/field_note.dart';
import '../../domain/models/field_photo.dart';
import '../../domain/models/forensic_case_metadata.dart';
import '../../domain/models/official_document.dart';
import '../../domain/models/occurrence.dart';
import '../../domain/models/trace_record.dart';
import '../../domain/models/victim_record.dart';
import '../../features/case_data/case_data_screen.dart';
import '../../features/checklist/checklist_screen.dart';
import '../../features/location/location_screen.dart';
import '../../features/measurements/measurements_screen.dart';
import '../../features/notes/notes_screen.dart';
import '../../features/photos/photos_screen.dart';
import '../../features/traces/traces_screen.dart';
import '../../features/vehicles/vehicles_screen.dart';
import '../../features/victims/victims_screen.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/module_tile.dart';
import '../../shared/widgets/status_chip.dart';
import '../../shared/utils/share_origin.dart';
import 'occurrence_closure_screen.dart';
import 'occurrence_delete_flow.dart';

class OccurrenceDashboardScreen extends StatefulWidget {
  const OccurrenceDashboardScreen({
    required this.repository,
    required this.occurrenceId,
    this.officialDocumentRepository,
    super.key,
  });

  final OccurrenceRepository repository;
  final String occurrenceId;
  final OfficialDocumentRepository? officialDocumentRepository;

  @override
  State<OccurrenceDashboardScreen> createState() =>
      _OccurrenceDashboardScreenState();
}

class _OccurrenceDashboardScreenState extends State<OccurrenceDashboardScreen> {
  final SicroCampoExportService _exportService = SicroCampoExportService();
  SicroCampoExportResult? _lastExportResult;
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.officialDocumentRepository == null
          ? widget.repository
          : Listenable.merge([
              widget.repository,
              widget.officialDocumentRepository!,
            ]),
      builder: (context, _) {
        final occurrence = widget.repository.findById(widget.occurrenceId);
        if (occurrence == null) {
          return const Scaffold(
            body: EmptyState(
              icon: Icons.error_outline,
              title: 'Ocorrencia nao encontrada',
              message: 'A ocorrencia pode ter sido removida deste aparelho.',
            ),
          );
        }
        final operational = occurrence.operationalProgress;
        final linkedOfficialDocuments = _linkedOfficialDocuments(occurrence.id);
        return Scaffold(
          appBar: AppBar(
            title: const Text('Dossie operacional'),
            actions: [
              IconButton(
                tooltip: 'Excluir ocorrencia',
                color: AppColors.danger,
                onPressed: () => _confirmDeleteOccurrence(context, occurrence),
                icon: const Icon(Icons.delete_outline),
              ),
              PopupMenuButton<OccurrenceStatus>(
                tooltip: 'Alterar status',
                onSelected: (status) async {
                  await widget.repository.updateStatus(occurrence.id, status);
                },
                itemBuilder: (context) {
                  return OccurrenceStatus.values.map((status) {
                    return PopupMenuItem(
                      value: status,
                      child: Text(status.label),
                    );
                  }).toList();
                },
              ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              children: [
                _Summary(occurrence: occurrence, progress: operational),
                const SizedBox(height: 12),
                _NextActionCard(
                  occurrence: occurrence,
                  progress: operational,
                  onReview: () => _openClosure(context, occurrence),
                  onAction: (stepId) =>
                      _openOperationalStep(context, occurrence, stepId),
                ),
                const SizedBox(height: 12),
                _PendingCompactPanel(
                  progress: operational,
                  onStepTap: (stepId) =>
                      _openOperationalStep(context, occurrence, stepId),
                ),
                const SizedBox(height: 12),
                ModuleTile(
                  icon: Icons.assignment_outlined,
                  title: 'Dados do caso',
                  subtitle: occurrence.caseData.displayLocation,
                  trailingText: operational.stateFor('case_data').label,
                  trailingColor: _stateColor(operational.stateFor('case_data')),
                  onTap: () => _openCaseData(context, occurrence),
                ),
                const SizedBox(height: 10),
                ModuleTile(
                  icon: Icons.my_location_outlined,
                  title: 'GPS / localizacao',
                  subtitle: _locationSummary(occurrence),
                  trailingText: operational.stateFor('gps').label,
                  trailingColor: _stateColor(operational.stateFor('gps')),
                  onTap: () => _openLocation(context, occurrence),
                ),
                const SizedBox(height: 10),
                ModuleTile(
                  icon: Icons.checklist_outlined,
                  title: _checklistTitle(occurrence),
                  subtitle: _checklistSummary(occurrence),
                  trailingText: operational.stateFor('checklist').label,
                  trailingColor: _stateColor(operational.stateFor('checklist')),
                  onTap: () => _openChecklist(context, occurrence),
                ),
                const SizedBox(height: 10),
                ModuleTile(
                  icon: Icons.photo_camera_outlined,
                  title: 'Fotos categorizadas',
                  subtitle: _photoSummary(occurrence),
                  trailingText: operational.stateFor('photos').label,
                  trailingColor: _stateColor(operational.stateFor('photos')),
                  onTap: () => _openPhotos(context, occurrence),
                ),
                if (occurrence.metadata.type == ForensicCaseType.traffic) ...[
                  const SizedBox(height: 10),
                  ModuleTile(
                    icon: Icons.directions_car_outlined,
                    title: 'Veiculos',
                    subtitle: _vehicleSummary(occurrence),
                    trailingText: operational.stateFor('vehicles').label,
                    trailingColor: _stateColor(
                      operational.stateFor('vehicles'),
                    ),
                    onTap: () => _openVehicles(context, occurrence),
                  ),
                  const SizedBox(height: 10),
                  ModuleTile(
                    icon: Icons.personal_injury_outlined,
                    title: 'Vitimas',
                    subtitle: _victimSummary(occurrence),
                    trailingText: operational.stateFor('victims').label,
                    trailingColor: _stateColor(operational.stateFor('victims')),
                    onTap: () => _openVictims(context, occurrence),
                  ),
                  const SizedBox(height: 10),
                  ModuleTile(
                    icon: Icons.scatter_plot_outlined,
                    title: 'Vestigios',
                    subtitle: _traceSummary(occurrence),
                    trailingText: operational.stateFor('traces').label,
                    trailingColor: _stateColor(operational.stateFor('traces')),
                    onTap: () => _openTraces(context, occurrence),
                  ),
                ] else if (occurrence.metadata.type ==
                    ForensicCaseType.violentDeath) ...[
                  const SizedBox(height: 10),
                  ModuleTile(
                    icon: Icons.personal_injury_outlined,
                    title: 'Vitimas/Corpos',
                    subtitle: _victimSummary(occurrence),
                    trailingText: operational.stateFor('victims').label,
                    trailingColor: _stateColor(operational.stateFor('victims')),
                    onTap: () => _openVictims(context, occurrence),
                  ),
                  const SizedBox(height: 10),
                  ModuleTile(
                    icon: Icons.biotech_outlined,
                    title: 'Vestigios biologicos',
                    subtitle: _traceGroupSummary(
                      occurrence,
                      _biologicalDashboardTraceTypes,
                      'Sangue, manchas, fluidos e material biologico',
                    ),
                    trailingText: operational
                        .stateFor(OperationalItemIds.biologicalTraces)
                        .label,
                    trailingColor: _stateColor(
                      operational.stateFor(OperationalItemIds.biologicalTraces),
                    ),
                    onTap: () => _openTraces(context, occurrence),
                  ),
                  const SizedBox(height: 10),
                  ModuleTile(
                    icon: Icons.gps_fixed_outlined,
                    title: 'Vestigios balisticos',
                    subtitle: _traceGroupSummary(
                      occurrence,
                      _ballisticDashboardTraceTypes,
                      'Capsulas, estojos, projeteis e perfuracoes',
                    ),
                    trailingText: operational
                        .stateFor(OperationalItemIds.ballisticTraces)
                        .label,
                    trailingColor: _stateColor(
                      operational.stateFor(OperationalItemIds.ballisticTraces),
                    ),
                    onTap: () => _openTraces(context, occurrence),
                  ),
                  const SizedBox(height: 10),
                  ModuleTile(
                    icon: Icons.construction_outlined,
                    title: 'Armas/objetos',
                    subtitle: _traceGroupSummary(
                      occurrence,
                      _weaponObjectDashboardTraceTypes,
                      'Armas, sinais de luta, pegadas e objetos deslocados',
                    ),
                    trailingText: operational
                        .stateFor(OperationalItemIds.weaponsObjects)
                        .label,
                    trailingColor: _stateColor(
                      operational.stateFor(OperationalItemIds.weaponsObjects),
                    ),
                    onTap: () => _openTraces(context, occurrence),
                  ),
                  if (occurrence.shouldShowVehicleModule) ...[
                    const SizedBox(height: 10),
                    ModuleTile(
                      icon: Icons.directions_car_outlined,
                      title: 'Veiculo como ambiente',
                      subtitle: _vehicleSummary(occurrence),
                      trailingText: operational.stateFor('vehicles').label,
                      trailingColor: _stateColor(
                        operational.stateFor('vehicles'),
                      ),
                      onTap: () => _openVehicles(context, occurrence),
                    ),
                  ],
                ] else if (occurrence.metadata.type ==
                    ForensicCaseType.property) ...[
                  const SizedBox(height: 10),
                  ModuleTile(
                    icon: Icons.domain_verification_outlined,
                    title: 'Vestigios patrimoniais',
                    subtitle: _traceSummary(occurrence),
                    trailingText: operational.stateFor('traces').label,
                    trailingColor: _stateColor(operational.stateFor('traces')),
                    onTap: () => _openTraces(context, occurrence),
                  ),
                ] else if (occurrence.metadata.type ==
                    ForensicCaseType.environmental) ...[
                  const SizedBox(height: 10),
                  ModuleTile(
                    icon: Icons.forest_outlined,
                    title: 'Vestigios ambientais',
                    subtitle: _traceSummary(occurrence),
                    trailingText: operational.stateFor('traces').label,
                    trailingColor: _stateColor(operational.stateFor('traces')),
                    onTap: () => _openTraces(context, occurrence),
                  ),
                ] else if (occurrence.metadata.type ==
                    ForensicCaseType.ballistics) ...[
                  const SizedBox(height: 10),
                  ModuleTile(
                    icon: Icons.adjust_outlined,
                    title: 'Material balistico',
                    subtitle: _traceSummary(occurrence),
                    trailingText: operational
                        .stateFor(OperationalItemIds.ballisticTraces)
                        .label,
                    trailingColor: _stateColor(
                      operational.stateFor(OperationalItemIds.ballisticTraces),
                    ),
                    onTap: () => _openTraces(context, occurrence),
                  ),
                ] else if (occurrence.metadata.type ==
                    ForensicCaseType.audioImage) ...[
                  const SizedBox(height: 10),
                  ModuleTile(
                    icon: Icons.perm_media_outlined,
                    title: 'Midias e arquivos',
                    subtitle: _traceSummary(occurrence),
                    trailingText: operational.stateFor('traces').label,
                    trailingColor: _stateColor(operational.stateFor('traces')),
                    onTap: () => _openTraces(context, occurrence),
                  ),
                ] else if (occurrence.metadata.type ==
                    ForensicCaseType.papiloscopy) ...[
                  const SizedBox(height: 10),
                  ModuleTile(
                    icon: Icons.fingerprint,
                    title: 'Vestigios papiloscopicos',
                    subtitle: _traceSummary(occurrence),
                    trailingText: operational
                        .stateFor(OperationalItemIds.papiloscopicTraces)
                        .label,
                    trailingColor: _stateColor(
                      operational.stateFor(
                        OperationalItemIds.papiloscopicTraces,
                      ),
                    ),
                    onTap: () => _openTraces(context, occurrence),
                  ),
                ],
                const SizedBox(height: 10),
                ModuleTile(
                  icon: Icons.straighten_outlined,
                  title: 'Medicoes',
                  subtitle: _measurementSummary(occurrence),
                  trailingText: operational.stateFor('measurements').label,
                  trailingColor: _stateColor(
                    operational.stateFor('measurements'),
                  ),
                  onTap: () => _openMeasurements(context, occurrence),
                ),
                const SizedBox(height: 10),
                ModuleTile(
                  icon: Icons.notes_outlined,
                  title: 'Observacoes',
                  subtitle: _notesSummary(occurrence),
                  trailingText: operational.stateFor('notes').label,
                  trailingColor: _stateColor(operational.stateFor('notes')),
                  onTap: () => _openNotes(context, occurrence),
                ),
                if (linkedOfficialDocuments.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ModuleTile(
                    icon: Icons.mark_email_read_outlined,
                    title: 'Oficios vinculados',
                    subtitle:
                        '${linkedOfficialDocuments.length} oficio(s) anexado(s) ao dossie',
                    trailingText: 'ver',
                    trailingColor: AppColors.gold,
                    onTap: () => _showLinkedOfficialDocuments(
                      context,
                      linkedOfficialDocuments,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                ModuleTile(
                  icon: Icons.archive_outlined,
                  title: 'Exportar .sicroapp',
                  subtitle: _exporting
                      ? 'Gerando pacote offline...'
                      : 'Gerar pacote offline para o SICRO desktop',
                  trailingText: operational.stateFor('export').label,
                  trailingColor: _stateColor(operational.stateFor('export')),
                  onTap: _exporting
                      ? () {}
                      : () => _exportOccurrence(context, occurrence),
                ),
                const SizedBox(height: 10),
                ModuleTile(
                  icon: occurrence.sessionActive
                      ? Icons.flag_outlined
                      : Icons.fact_check_outlined,
                  title: occurrence.sessionActive
                      ? 'Concluir pericia'
                      : 'Ver encerramento',
                  subtitle: occurrence.sessionActive
                      ? 'Encerrar a sessao e revisar o resumo operacional'
                      : 'Estatisticas, pendencias e timeline da ocorrencia',
                  trailingText: occurrence.sessionActive
                      ? 'encerrar'
                      : occurrence.status.label,
                  trailingColor: occurrence.sessionActive
                      ? AppColors.gold
                      : _statusColor(occurrence.status),
                  onTap: () => _openClosure(context, occurrence),
                ),
                if (_lastExportResult != null) ...[
                  const SizedBox(height: 10),
                  ModuleTile(
                    icon: Icons.ios_share_outlined,
                    title: 'Compartilhar ultimo pacote',
                    subtitle:
                        '${_lastExportResult!.fileName} - ${_formatBytes(_lastExportResult!.sizeBytes)}',
                    trailingText: 'enviar',
                    onTap: () => _shareExport(context, _lastExportResult!),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _openCaseData(BuildContext context, FieldOccurrence occurrence) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CaseDataScreen(
          repository: widget.repository,
          occurrenceId: occurrence.id,
        ),
      ),
    );
  }

  void _openLocation(BuildContext context, FieldOccurrence occurrence) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LocationScreen(
          repository: widget.repository,
          occurrenceId: occurrence.id,
        ),
      ),
    );
  }

  void _openChecklist(BuildContext context, FieldOccurrence occurrence) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChecklistScreen(
          repository: widget.repository,
          occurrenceId: occurrence.id,
        ),
      ),
    );
  }

  void _openPhotos(BuildContext context, FieldOccurrence occurrence) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PhotosScreen(
          repository: widget.repository,
          occurrenceId: occurrence.id,
        ),
      ),
    );
  }

  void _openVehicles(BuildContext context, FieldOccurrence occurrence) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VehiclesScreen(
          repository: widget.repository,
          occurrenceId: occurrence.id,
        ),
      ),
    );
  }

  void _openVictims(BuildContext context, FieldOccurrence occurrence) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VictimsScreen(
          repository: widget.repository,
          occurrenceId: occurrence.id,
        ),
      ),
    );
  }

  void _openTraces(BuildContext context, FieldOccurrence occurrence) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TracesScreen(
          repository: widget.repository,
          occurrenceId: occurrence.id,
        ),
      ),
    );
  }

  void _openMeasurements(BuildContext context, FieldOccurrence occurrence) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MeasurementsScreen(
          repository: widget.repository,
          occurrenceId: occurrence.id,
        ),
      ),
    );
  }

  void _openNotes(BuildContext context, FieldOccurrence occurrence) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NotesScreen(
          repository: widget.repository,
          occurrenceId: occurrence.id,
        ),
      ),
    );
  }

  List<OfficialDocument> _linkedOfficialDocuments(String occurrenceId) {
    final repository = widget.officialDocumentRepository;
    if (repository == null) {
      return const [];
    }
    return repository.documents
        .where((document) => document.linkedOccurrenceId == occurrenceId)
        .toList(growable: false);
  }

  Future<void> _showLinkedOfficialDocuments(
    BuildContext context,
    List<OfficialDocument> documents,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.panel,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            shrinkWrap: true,
            children: [
              Text(
                'Oficios vinculados',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              for (final document in documents)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: Text(document.displayTitle),
                    subtitle: Text(document.displaySubtitle),
                    trailing: Text(document.status.label),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteOccurrence(
    BuildContext context,
    FieldOccurrence occurrence,
  ) async {
    final deleted = await confirmAndDeleteOccurrence(
      context: context,
      repository: widget.repository,
      occurrence: occurrence,
      exportService: _exportService,
    );
    if (deleted && context.mounted) {
      Navigator.of(context).pop();
    }
  }

  void _openClosure(BuildContext context, FieldOccurrence occurrence) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OccurrenceClosureScreen(
          repository: widget.repository,
          occurrenceId: occurrence.id,
        ),
      ),
    );
  }

  void _openOperationalStep(
    BuildContext context,
    FieldOccurrence occurrence,
    String stepId,
  ) {
    switch (stepId) {
      case 'case_data':
        _openCaseData(context, occurrence);
        return;
      case 'gps':
        _openLocation(context, occurrence);
        return;
      case 'checklist':
        _openChecklist(context, occurrence);
        return;
      case 'photos':
        _openPhotos(context, occurrence);
        return;
      case 'trace_photos':
        _openPhotos(context, occurrence);
        return;
      case 'vehicles':
        _openVehicles(context, occurrence);
        return;
      case 'victims':
        _openVictims(context, occurrence);
        return;
      case 'traces':
        _openTraces(context, occurrence);
        return;
      case 'biological_traces':
        _openTraces(context, occurrence);
        return;
      case 'ballistic_traces':
        _openTraces(context, occurrence);
        return;
      case 'weapons_objects':
        _openTraces(context, occurrence);
        return;
      case 'measurements':
        _openMeasurements(context, occurrence);
        return;
      case 'notes':
        _openNotes(context, occurrence);
        return;
      case 'export':
        _exportOccurrence(context, occurrence);
        return;
    }
  }

  Future<void> _exportOccurrence(
    BuildContext context,
    FieldOccurrence occurrence,
  ) async {
    if (_exporting) {
      return;
    }
    setState(() => _exporting = true);
    var progressDialogOpen = false;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return const AlertDialog(
          content: Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
              SizedBox(width: 16),
              Expanded(child: Text('Gerando pacote .sicroapp...')),
            ],
          ),
        );
      },
    );
    progressDialogOpen = true;

    try {
      final result = await _exportService.exportOccurrence(
        occurrence,
        officialDocuments: _linkedOfficialDocuments(occurrence.id),
      );

      if (context.mounted && progressDialogOpen) {
        Navigator.of(context, rootNavigator: true).pop();
        progressDialogOpen = false;
      }

      if (!context.mounted) {
        return;
      }
      await widget.repository.markExported(
        occurrence.id,
        exportedAt: result.generatedAt,
        packageName: result.fileName,
        sha256: result.sha256,
      );
      if (!context.mounted) {
        return;
      }
      setState(() => _lastExportResult = result);
      await _showExportResultDialog(context, result);
    } catch (error) {
      if (context.mounted && progressDialogOpen) {
        Navigator.of(context, rootNavigator: true).pop();
        progressDialogOpen = false;
      }
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Falha ao exportar .sicroapp: $error'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  Future<void> _shareExport(
    BuildContext context,
    SicroCampoExportResult result,
  ) async {
    if (!await result.file.exists()) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('O ultimo pacote nao foi encontrado no aparelho.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    if (!context.mounted) {
      return;
    }
    final shareOrigin = sharePositionOriginFor(context);
    await SharePlus.instance.share(
      ShareParams(
        title: 'Compartilhar .sicroapp',
        subject: result.fileName,
        text:
            'Pacote SICRO Operacional gerado offline. Hash SHA256: ${result.sha256}',
        sharePositionOrigin: shareOrigin,
        files: [
          XFile(
            result.file.path,
            mimeType: 'application/zip',
            name: result.fileName,
          ),
        ],
        fileNameOverrides: [result.fileName],
      ),
    );
  }

  Future<void> _showExportResultDialog(
    BuildContext context,
    SicroCampoExportResult result,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Pacote .sicroapp gerado com sucesso'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ExportInfoRow(label: 'Arquivo', value: result.fileName),
                _ExportInfoRow(
                  label: 'Tamanho',
                  value: _formatBytes(result.sizeBytes),
                ),
                _ExportInfoRow(label: 'Local', value: result.file.path),
                _ExportInfoRow(
                  label: 'Fotos',
                  value:
                      '${result.photosIncluded}/${result.photosTotal} incluida(s)',
                ),
                if (result.officialDocumentsTotal > 0)
                  _ExportInfoRow(
                    label: 'Oficios',
                    value:
                        '${result.officialDocumentsIncluded}/${result.officialDocumentsTotal} incluido(s)',
                  ),
                _ExportInfoRow(
                  label: 'Conteudo',
                  value: '${result.entryCount} arquivo(s) no pacote',
                ),
                _ExportInfoRow(
                  label: 'Hashes',
                  value: result.hashesReady
                      ? '${result.hashCount} SHA-256 calculado(s)'
                      : 'Pendente',
                ),
                _ExportInfoRow(
                  label: 'SHA pacote',
                  value: _shortHash(result.sha256),
                ),
                if (result.warnings.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    '${result.warnings.length} aviso(s)',
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (final warning in result.warnings.take(3))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        warning,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fechar'),
            ),
            FilledButton.icon(
              onPressed: () async {
                await _shareExport(context, result);
              },
              icon: const Icon(Icons.ios_share_outlined),
              label: const Text('Compartilhar'),
            ),
          ],
        );
      },
    );
  }
}

String _vehicleSummary(FieldOccurrence occurrence) {
  if (occurrence.isNotApplicable(OperationalItemIds.vehicles)) {
    return 'Nao aplicavel nesta ocorrencia';
  }
  if (occurrence.vehicles.isEmpty) {
    if (occurrence.metadata.type == ForensicCaseType.violentDeath) {
      return 'Use apenas se o veiculo for ambiente ou elemento relevante';
    }
    return 'Placa, ponto de impacto, avarias, posicao final e fotos';
  }

  final linkedPhotos = occurrence.vehicles.fold<int>(
    0,
    (total, vehicle) => total + vehicle.photoIds.length,
  );
  return '${occurrence.vehicles.length} registrado(s) - $linkedPhotos foto(s) vinculada(s)';
}

String _locationSummary(FieldOccurrence occurrence) {
  final location = occurrence.location;
  if (!location.hasCoordinates) {
    return occurrence.sessionActive
        ? 'GPS automatico aguardando primeira leitura'
        : 'Pendente de captura';
  }

  final readings = occurrence.gpsReadingsCount;
  final suffix = readings > 0 ? ' - $readings leitura(s)' : '';
  return '${location.accuracyLabel} - ${_shortDateTime(location.capturedAt)}$suffix';
}

String _checklistSummary(FieldOccurrence occurrence) {
  return '${occurrence.answeredChecklistItems}/${occurrence.checklist.length} respondidos - ${occurrence.pendingRequiredChecklistItems} obrigatorios pendentes';
}

String _checklistTitle(FieldOccurrence occurrence) {
  return switch (occurrence.metadata.type) {
    ForensicCaseType.traffic => 'Checklist de transito',
    ForensicCaseType.violentDeath => 'Checklist de local de crime',
    ForensicCaseType.property => 'Checklist de patrimonio',
    ForensicCaseType.environmental => 'Checklist ambiental',
    ForensicCaseType.ballistics => 'Checklist de balistica',
    ForensicCaseType.audioImage => 'Checklist de audio e imagem',
    ForensicCaseType.papiloscopy => 'Checklist de papiloscopia',
  };
}

String _photoSummary(FieldOccurrence occurrence) {
  if (occurrence.photos.isEmpty) {
    return 'Nenhuma foto capturada';
  }

  final counts = <PhotoCategory, int>{};
  for (final photo in occurrence.photos) {
    counts.update(photo.category, (value) => value + 1, ifAbsent: () => 1);
  }
  final summary = counts.entries
      .take(3)
      .map((entry) => '${entry.value} ${entry.key.label.toLowerCase()}')
      .join(', ');
  return '${occurrence.photos.length} foto(s) - $summary';
}

String _victimSummary(FieldOccurrence occurrence) {
  if (occurrence.isNotApplicable(OperationalItemIds.victims)) {
    return 'Nao aplicavel nesta ocorrencia';
  }
  if (occurrence.victims.isEmpty) {
    if (occurrence.metadata.type == ForensicCaseType.violentDeath) {
      return 'Identificacao, remocao, posicao corporal, vestes e fotos';
    }
    return 'Condicao, remocao, destino, posicao corporal e fotos';
  }

  final severe = occurrence.victims
      .where(
        (victim) =>
            victim.condition == VictimCondition.injured ||
            victim.condition == VictimCondition.death,
      )
      .length;
  final linkedPhotos = occurrence.victims.fold<int>(
    0,
    (total, victim) => total + victim.photoIds.length,
  );
  return '${occurrence.victims.length} registrada(s) - $severe lesionada(s)/obito - $linkedPhotos foto(s)';
}

String _traceSummary(FieldOccurrence occurrence) {
  if (occurrence.isNotApplicable(OperationalItemIds.traces)) {
    return 'Nao aplicavel nesta ocorrencia';
  }
  if (occurrence.traces.isEmpty) {
    if (occurrence.metadata.type == ForensicCaseType.property) {
      return switch (occurrence.metadata.propertyNature) {
        PropertyNature.directEvaluation || PropertyNature.indirectEvaluation =>
          'Registre vestigios apenas se houver detalhe tecnico relevante',
        PropertyNature.damages => 'Danos, extensao, causa aparente e fotos',
        PropertyNature.burglary =>
          'Ponto de acesso, marcas, rompimentos e fechaduras',
        PropertyNature.fire =>
          'Foco provavel, queima, danos termicos e residuos',
        null => 'Vestigios patrimoniais relevantes',
      };
    }
    if (occurrence.metadata.type == ForensicCaseType.environmental) {
      return switch (occurrence.metadata.environmentalNature) {
        EnvironmentalNature.deforestation =>
          'Supressao vegetal, tocos, material lenhoso e area afetada',
        EnvironmentalNature.animalAbuse =>
          'Condicao animal, lesoes, ambiente e vestigios biologicos',
        EnvironmentalNature.waterPollution =>
          'Efluente, corpo hidrico, amostras e fauna/flora afetadas',
        EnvironmentalNature.forestFire =>
          'Indicadores de queima, foco, fuligem e danos ambientais',
        EnvironmentalNature.veterinaryNecropsy =>
          'Cadaver animal, lesoes, amostras e cadeia de custodia',
        EnvironmentalNature.other =>
          'Vestigios ambientais, amostras e documentos relevantes',
        null => 'Vestigios ambientais relevantes',
      };
    }
    if (occurrence.metadata.type == ForensicCaseType.ballistics) {
      return switch (occurrence.metadata.ballisticsNature) {
        BallisticsNature.ballisticComparison =>
          'Armas, estojos, projeteis e padroes balisticos',
        BallisticsNature.gsrCollection =>
          'Amostras GSR, vestes e superficies de coleta',
        BallisticsNature.firearmEfficiency =>
          'Armas de fogo, funcionamento, avarias e padroes',
        BallisticsNature.ammunitionEfficiency =>
          'Cartuchos, estojos, projeteis e material remanescente',
        BallisticsNature.other => 'Material balistico relevante',
        null => 'Material balistico relevante',
      };
    }
    if (occurrence.metadata.type == ForensicCaseType.audioImage) {
      return switch (occurrence.metadata.audioImageNature) {
        AudioImageNature.contentAnalysis =>
          'Videos, imagens, trechos, frames e eventos de interesse',
        AudioImageNature.imageEnhancement =>
          'Imagens/videos originais, recortes, quadros e arquivos melhorados',
        AudioImageNature.imageRecognition =>
          'Imagens questionadas, padroes e elementos de reconhecimento',
        AudioImageNature.facialComparison =>
          'Imagens faciais questionadas e material padrao',
        AudioImageNature.imageEditVerification =>
          'Arquivos originais, metadados e estrutura para autenticidade',
        AudioImageNature.speakerComparison =>
          'Audios questionados, padrao vocal e trechos comparaveis',
        AudioImageNature.cctvPreservation =>
          'DVR/NVR, cameras, midias e arquivos extraidos',
        AudioImageNature.statureEstimation =>
          'Imagens, frames, referencias metricas e padroes',
        AudioImageNature.other => 'Midias e arquivos multimidia relevantes',
        null => 'Midias e arquivos multimidia relevantes',
      };
    }
    if (occurrence.metadata.type == ForensicCaseType.papiloscopy) {
      return switch (occurrence.metadata.papiloscopyNature) {
        PapiloscopyNature.criminalIdentification =>
          'Digitais, palmares, fotografia sinaletica e AFIS/ABIS',
        PapiloscopyNature.crimeScenePrints =>
          'Latentes, patentes, moldadas, suportes e decalques',
        PapiloscopyNature.labPrints =>
          'Suportes questionados, reagentes, revelacoes e lacres',
        PapiloscopyNature.necropapiloscopy =>
          'Registros necropapiloscopicos, falanges e tecnicas de pele',
        PapiloscopyNature.other => 'Vestigios papiloscopicos relevantes',
        null => 'Vestigios papiloscopicos relevantes',
      };
    }
    return 'Frenagem, derrapagem, sulcagem, arrasto e fragmentos';
  }

  final counts = <String, int>{};
  for (final trace in occurrence.traces) {
    counts.update(trace.type.label, (value) => value + 1, ifAbsent: () => 1);
  }

  final summary = counts.entries
      .take(3)
      .map((entry) => '${entry.value} ${entry.key.toLowerCase()}')
      .join(', ');
  return '${occurrence.traces.length} registrado(s) - $summary';
}

String _traceGroupSummary(
  FieldOccurrence occurrence,
  Set<TraceType> types,
  String emptyMessage,
) {
  if (occurrence.isNotApplicable(OperationalItemIds.traces)) {
    return 'Nao aplicavel nesta ocorrencia';
  }
  final traces = occurrence.traces
      .where((trace) => types.contains(trace.type))
      .toList(growable: false);
  if (traces.isEmpty) {
    return emptyMessage;
  }

  final counts = <String, int>{};
  for (final trace in traces) {
    counts.update(trace.type.label, (value) => value + 1, ifAbsent: () => 1);
  }
  final summary = counts.entries
      .take(3)
      .map((entry) => '${entry.value} ${entry.key.toLowerCase()}')
      .join(', ');
  return '${traces.length} registrado(s) - $summary';
}

String _measurementSummary(FieldOccurrence occurrence) {
  if (occurrence.isNotApplicable(OperationalItemIds.measurements)) {
    return 'Nao aplicavel nesta ocorrencia';
  }
  if (occurrence.measurements.isEmpty) {
    if (occurrence.metadata.type == ForensicCaseType.property) {
      return 'Dimensoes, extensao de dano ou area afetada';
    }
    if (occurrence.metadata.type == ForensicCaseType.environmental) {
      return 'Area, perimetro, distancias e pontos de coleta';
    }
    if (occurrence.metadata.type == ForensicCaseType.ballistics) {
      return 'Calibre, dimensoes, massa e referencias tecnicas';
    }
    if (occurrence.metadata.type == ForensicCaseType.audioImage) {
      return 'Tempos, frames, duracoes, dimensoes e referencias metricas';
    }
    if (occurrence.metadata.type == ForensicCaseType.papiloscopy) {
      return 'Escalas, dimensoes de suporte e referencias tecnicas';
    }
    return 'Ponto A/B, valor, unidade e observacao';
  }

  final summary = occurrence.measurements
      .take(3)
      .map((measurement) {
        final value = measurement.value <= 0
            ? 'pendente'
            : '${_numberText(measurement.value)} ${measurement.unit}';
        return '${measurement.label} $value';
      })
      .join(', ');
  return '${occurrence.measurements.length} registrada(s) - $summary';
}

String _notesSummary(FieldOccurrence occurrence) {
  if (occurrence.notes.isEmpty) {
    return 'Notas livres do perito durante o atendimento';
  }

  final highlighted = occurrence.notes
      .where((note) => note.priority != NotePriority.normal)
      .length;
  return '${occurrence.notes.length} registrada(s) - $highlighted importante(s)/critica(s)';
}

String _numberText(double value) {
  final fixed = value.toStringAsFixed(2);
  return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
}

String _shortDateTime(DateTime? value) {
  if (value == null) {
    return 'horario nao informado';
  }
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day/$month $hour:$minute';
}

String _formatBytes(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }
  final kb = bytes / 1024;
  if (kb < 1024) {
    return '${kb.toStringAsFixed(1)} KB';
  }
  final mb = kb / 1024;
  return '${mb.toStringAsFixed(2)} MB';
}

String _durationLabel(int seconds) {
  final safe = seconds < 0 ? 0 : seconds;
  final hours = safe ~/ 3600;
  final minutes = (safe % 3600) ~/ 60;
  final remainingSeconds = safe % 60;
  if (hours > 0) {
    return '${hours}h ${minutes.toString().padLeft(2, '0')}min';
  }
  if (minutes > 0) {
    return '${minutes}min ${remainingSeconds.toString().padLeft(2, '0')}s';
  }
  return '${remainingSeconds}s';
}

String _shortHash(String hash) {
  if (hash.length <= 16) {
    return hash;
  }
  return '${hash.substring(0, 16)}...';
}

Color _statusColor(OccurrenceStatus status) {
  return switch (status) {
    OccurrenceStatus.inProgress => AppColors.gold,
    OccurrenceStatus.completed => AppColors.success,
    OccurrenceStatus.exported => AppColors.active,
    OccurrenceStatus.pendingReview => AppColors.gold,
    OccurrenceStatus.incomplete => AppColors.danger,
    OccurrenceStatus.archived => AppColors.textSecondary,
  };
}

Color _stateColor(OperationalItemState state) {
  return switch (state) {
    OperationalItemState.pending => AppColors.danger,
    OperationalItemState.partial => AppColors.gold,
    OperationalItemState.completed => AppColors.success,
    OperationalItemState.notApplicable => AppColors.textSecondary,
  };
}

IconData _stepIcon(String id) {
  return switch (id) {
    'case_data' => Icons.assignment_outlined,
    'gps' => Icons.my_location_outlined,
    'checklist' => Icons.checklist_outlined,
    'photos' => Icons.photo_camera_outlined,
    'trace_photos' => Icons.center_focus_strong_outlined,
    'vehicles' => Icons.directions_car_outlined,
    'victims' => Icons.personal_injury_outlined,
    'traces' => Icons.scatter_plot_outlined,
    'biological_traces' => Icons.biotech_outlined,
    'ballistic_traces' => Icons.gps_fixed_outlined,
    'weapons_objects' => Icons.construction_outlined,
    'papiloscopic_traces' => Icons.fingerprint,
    'measurements' => Icons.straighten_outlined,
    'notes' => Icons.notes_outlined,
    'export' => Icons.archive_outlined,
    _ => Icons.radio_button_unchecked,
  };
}

const _biologicalDashboardTraceTypes = {
  TraceType.blood,
  TraceType.biological,
  TraceType.stain,
  TraceType.fluid,
  TraceType.drag,
};

const _ballisticDashboardTraceTypes = {
  TraceType.ballisticCase,
  TraceType.projectile,
  TraceType.perforation,
  TraceType.cartridge,
  TraceType.ballisticStandard,
  TraceType.gsrSample,
  TraceType.firearm,
};

const _weaponObjectDashboardTraceTypes = {
  TraceType.coldWeapon,
  TraceType.firearm,
  TraceType.struggleSign,
  TraceType.footprint,
  TraceType.displacedObject,
  TraceType.detachedPart,
};

class _NextActionCard extends StatelessWidget {
  const _NextActionCard({
    required this.occurrence,
    required this.progress,
    required this.onAction,
    required this.onReview,
  });

  final FieldOccurrence occurrence;
  final OperationalProgress progress;
  final ValueChanged<String> onAction;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final step = _nextStep(progress, occurrence);
    final color = _stateColor(step.state);
    final resolved = progress.pendingItems.isEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
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
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.75)),
            ),
            child: Icon(
              resolved ? Icons.verified_outlined : _stepIcon(step.id),
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Proxima acao',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  resolved ? 'Concluir ou revisar a pericia' : step.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  resolved
                      ? 'Os marcos principais estao resolvidos.'
                      : step.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: resolved ? onReview : () => onAction(step.id),
            child: Text(resolved ? 'Revisar' : 'Abrir'),
          ),
        ],
      ),
    );
  }

  OperationalStep _nextStep(
    OperationalProgress progress,
    FieldOccurrence occurrence,
  ) {
    for (final step in progress.steps) {
      if (!step.resolved) {
        return step;
      }
    }
    if (!occurrence.hasExportRecord) {
      return progress.steps.firstWhere(
        (step) => step.id == OperationalItemIds.export,
        orElse: () => progress.steps.last,
      );
    }
    return progress.steps.firstWhere(
      (step) => step.id == OperationalItemIds.checklist,
      orElse: () => progress.steps.first,
    );
  }
}

class _PendingCompactPanel extends StatelessWidget {
  const _PendingCompactPanel({required this.progress, required this.onStepTap});

  final OperationalProgress progress;
  final ValueChanged<String> onStepTap;

  @override
  Widget build(BuildContext context) {
    final pendingItems = progress.pendingItems;
    final color = pendingItems.isEmpty ? AppColors.success : AppColors.gold;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(
            pendingItems.isEmpty
                ? Icons.verified_outlined
                : Icons.pending_actions_outlined,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pendingItems.isEmpty
                      ? 'Sem pendencias operacionais'
                      : '${pendingItems.length} pendencia(s) operacional(is)',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  pendingItems.isEmpty
                      ? 'A ocorrencia esta pronta para revisao ou exportacao.'
                      : pendingItems.first,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: pendingItems.isEmpty
                ? null
                : () => _showPendingSheet(context),
            child: const Text('Ver'),
          ),
        ],
      ),
    );
  }

  void _showPendingSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: AppColors.panel,
      builder: (context) {
        return SafeArea(
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.55,
            minChildSize: 0.32,
            maxChildSize: 0.9,
            builder: (context, controller) {
              final pendingSteps = progress.steps
                  .where((step) => !step.resolved)
                  .toList();
              return ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  Text(
                    'Pendencias operacionais',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Os itens abaixo orientam a coleta, mas nao bloqueiam o trabalho em campo.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 14),
                  for (final pending in progress.pendingItems)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.warning_amber_outlined,
                            size: 19,
                            color: AppColors.gold,
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(pending)),
                        ],
                      ),
                    ),
                  if (pendingSteps.isNotEmpty) ...[
                    const Divider(height: 24, color: AppColors.border),
                    for (final step in pendingSteps)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          _stepIcon(step.id),
                          color: AppColors.gold,
                        ),
                        title: Text(step.title),
                        subtitle: Text(step.description),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(context).pop();
                          onStepTap(step.id);
                        },
                      ),
                  ],
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _ExportInfoRow extends StatelessWidget {
  const _ExportInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          SelectableText(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.occurrence, required this.progress});

  final FieldOccurrence occurrence;
  final OperationalProgress progress;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(occurrence.status);
    final progressColor = progress.pendingItems.isEmpty
        ? AppColors.success
        : AppColors.gold;

    return Container(
      padding: const EdgeInsets.all(16),
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
              Expanded(
                child: Text(
                  occurrence.caseData.displayTitle,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              StatusChip(label: occurrence.status.label, color: statusColor),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            occurrence.caseData.displayLocation,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          Text(
            occurrence.metadata.summary,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Inicio ${_shortDateTime(occurrence.effectiveStartedAt)} - ${_durationLabel(occurrence.durationSeconds)}',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          if (occurrence.finishedAt != null) ...[
            const SizedBox(height: 4),
            Text(
              'Concluida ${_shortDateTime(occurrence.finishedAt)}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress.percent / 100,
                    minHeight: 4,
                    backgroundColor: AppColors.base,
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${progress.percent}%',
                style: TextStyle(
                  color: progressColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          if (occurrence.exportedAt != null) ...[
            const SizedBox(height: 10),
            StatusChip(
              label: 'Exportado ${_shortDateTime(occurrence.exportedAt)}',
              color: AppColors.active,
            ),
          ],
          const SizedBox(height: 4),
          Text(
            '${progress.completedRequiredItems}/${progress.totalRequiredItems} marcos operacionais resolvidos',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
