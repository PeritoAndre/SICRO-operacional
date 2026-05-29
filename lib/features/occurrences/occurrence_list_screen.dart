import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/data/app_settings_repository.dart';
import '../../core/data/official_document_repository.dart';
import '../../core/data/occurrence_repository.dart';
import '../../domain/models/occurrence.dart';
import '../../features/duty_report/duty_report_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/start/start_expertise_screen.dart';
import '../../shared/widgets/empty_state.dart';
import 'new_occurrence_screen.dart';
import 'occurrence_delete_flow.dart';
import 'occurrence_dashboard_screen.dart';
import 'operational_diary_widgets.dart';

class OccurrenceListScreen extends StatefulWidget {
  const OccurrenceListScreen({
    required this.repository,
    this.officialDocumentRepository,
    this.settingsRepository,
    super.key,
  });

  final OccurrenceRepository repository;
  final OfficialDocumentRepository? officialDocumentRepository;
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
        title: const Text('Diario Operacional'),
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
            final groups = groupOccurrencesByMonth(occurrences);

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _DiarySearchHeader(
                    total: widget.repository.occurrences.length,
                    filtered: occurrences.length,
                    onChanged: _setQuery,
                  ),
                ),
                if (groups.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _query.trim().isEmpty
                        ? const OperationalDiaryEmpty()
                        : const EmptyState(
                            icon: Icons.search_off_outlined,
                            title: 'Nenhum registro encontrado',
                            message:
                                'Tente buscar por BO, protocolo, municipio ou local.',
                          ),
                  )
                else ...[
                  for (final group in groups)
                    OperationalDiarySection(
                      group: group,
                      onOpen: (occurrence) => _openDashboard(occurrence.id),
                      onDelete: _confirmDeleteOccurrence,
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 96)),
                ],
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewOccurrence,
        icon: const Icon(Icons.add),
        label: const Text('Nova pericia'),
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
          data.district.toLowerCase().contains(query) ||
          data.street.toLowerCase().contains(query) ||
          occurrence.metadata.summary.toLowerCase().contains(query);
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
          officialDocumentRepository: widget.officialDocumentRepository,
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

class _DiarySearchHeader extends StatelessWidget {
  const _DiarySearchHeader({
    required this.total,
    required this.filtered,
    required this.onChanged,
  });

  final int total;
  final int filtered;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Linha do tempo',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            filtered == total
                ? '$total registro(s) no diario operacional'
                : '$filtered de $total registro(s) encontrados',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
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
