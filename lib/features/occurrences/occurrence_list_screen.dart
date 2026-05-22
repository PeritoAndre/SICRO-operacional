import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/data/app_settings_repository.dart';
import '../../core/data/occurrence_repository.dart';
import '../../domain/models/occurrence.dart';
import '../../features/duty_report/duty_report_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/start/start_expertise_screen.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/status_chip.dart';
import 'new_occurrence_screen.dart';
import 'occurrence_delete_flow.dart';
import 'occurrence_dashboard_screen.dart';

class OccurrenceListScreen extends StatefulWidget {
  const OccurrenceListScreen({
    required this.repository,
    this.settingsRepository,
    super.key,
  });

  final OccurrenceRepository repository;
  final AppSettingsRepository? settingsRepository;

  @override
  State<OccurrenceListScreen> createState() => _OccurrenceListScreenState();
}

class _OccurrenceListScreenState extends State<OccurrenceListScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SICRO Operacional'),
        actions: [
          IconButton(
            tooltip: 'Relatorio de plantao',
            onPressed: widget.settingsRepository == null
                ? null
                : () => _openDutyReport(),
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
          IconButton(
            tooltip: 'Configurar perfil',
            onPressed: widget.settingsRepository == null
                ? null
                : () => _openSettings(),
            icon: const Icon(Icons.person_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.repository,
          builder: (context, _) {
            final occurrences = _filter(widget.repository.occurrences);
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _Header(onChanged: _setQuery)),
                if (occurrences.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.assignment_outlined,
                      title: 'Nenhuma ocorrencia em andamento',
                      message:
                          'Crie uma ocorrencia para registrar dados, fotos, checklist e medicoes em campo.',
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    sliver: SliverList.separated(
                      itemCount: occurrences.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        return _OccurrenceCard(
                          occurrence: occurrences[index],
                          onTap: () => _openDashboard(occurrences[index].id),
                          onDelete: () =>
                              _confirmDeleteOccurrence(occurrences[index]),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewOccurrence,
        icon: const Icon(Icons.add),
        label: const Text('Iniciar'),
      ),
    );
  }

  List<FieldOccurrence> _filter(List<FieldOccurrence> occurrences) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) {
      return occurrences;
    }
    return occurrences.where((occurrence) {
      final data = occurrence.caseData;
      return data.bo.toLowerCase().contains(query) ||
          data.protocol.toLowerCase().contains(query) ||
          data.municipality.toLowerCase().contains(query) ||
          data.street.toLowerCase().contains(query);
    }).toList();
  }

  void _setQuery(String value) {
    setState(() => _query = value);
  }

  void _openNewOccurrence() {
    final settingsRepository = widget.settingsRepository;
    if (settingsRepository != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => StartExpertiseScreen(
            repository: widget.repository,
            settingsRepository: settingsRepository,
          ),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NewOccurrenceScreen(repository: widget.repository),
      ),
    );
  }

  void _openDashboard(String occurrenceId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OccurrenceDashboardScreen(
          repository: widget.repository,
          occurrenceId: occurrenceId,
        ),
      ),
    );
  }

  void _openSettings() {
    final settingsRepository = widget.settingsRepository;
    if (settingsRepository == null) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(settingsRepository: settingsRepository),
      ),
    );
  }

  void _openDutyReport() {
    final settingsRepository = widget.settingsRepository;
    if (settingsRepository == null) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DutyReportScreen(
          repository: widget.repository,
          settingsRepository: settingsRepository,
        ),
      ),
    );
  }

  Future<void> _confirmDeleteOccurrence(FieldOccurrence occurrence) async {
    await confirmAndDeleteOccurrence(
      context: context,
      repository: widget.repository,
      occurrence: occurrence,
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Coleta pericial offline',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Organize o dossie operacional e gere um pacote para o SICRO desktop.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          TextField(
            onChanged: onChanged,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Buscar por BO, protocolo, municipio ou local',
            ),
          ),
        ],
      ),
    );
  }
}

class _OccurrenceCard extends StatelessWidget {
  const _OccurrenceCard({
    required this.occurrence,
    required this.onTap,
    required this.onDelete,
  });

  final FieldOccurrence occurrence;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (occurrence.status) {
      OccurrenceStatus.inProgress => AppColors.gold,
      OccurrenceStatus.completed => AppColors.success,
      OccurrenceStatus.exported => AppColors.active,
      OccurrenceStatus.pendingReview => AppColors.gold,
      OccurrenceStatus.incomplete => AppColors.danger,
      OccurrenceStatus.archived => AppColors.textSecondary,
    };

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      occurrence.caseData.displayTitle,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  StatusChip(
                    label: occurrence.status.label,
                    color: statusColor,
                  ),
                  const SizedBox(width: 2),
                  PopupMenuButton<_OccurrenceCardAction>(
                    tooltip: 'Opcoes da ocorrencia',
                    icon: const Icon(Icons.more_vert),
                    onSelected: (action) {
                      switch (action) {
                        case _OccurrenceCardAction.delete:
                          onDelete();
                      }
                    },
                    itemBuilder: (context) {
                      return const [
                        PopupMenuItem(
                          value: _OccurrenceCardAction.delete,
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline,
                                color: AppColors.danger,
                              ),
                              SizedBox(width: 10),
                              Text('Excluir'),
                            ],
                          ),
                        ),
                      ];
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                occurrence.caseData.displayLocation,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                occurrence.metadata.summary,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 14,
                runSpacing: 8,
                children: [
                  _Metric(
                    icon: Icons.photo_camera_outlined,
                    value: '${occurrence.photos.length} fotos',
                  ),
                  _Metric(
                    icon: Icons.directions_car_outlined,
                    value: '${occurrence.vehicles.length} veiculos',
                  ),
                  _Metric(
                    icon: Icons.rule_outlined,
                    value: '${occurrence.measurements.length} medicoes',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _OccurrenceCardAction { delete }

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.gold),
        const SizedBox(width: 4),
        Text(value, style: const TextStyle(color: AppColors.textSecondary)),
      ],
    );
  }
}
