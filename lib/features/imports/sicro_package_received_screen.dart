import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/data/occurrence_repository.dart';
import '../../core/data/sicroapp_import_service.dart';
import '../occurrences/occurrence_dashboard_screen.dart';

class SicroPackageReceivedScreen extends StatefulWidget {
  SicroPackageReceivedScreen({
    required this.result,
    required this.repository,
    SicroAppImportService? importService,
    super.key,
  }) : importService = importService ?? SicroAppImportService();

  final SicroAppPackageImportResult result;
  final OccurrenceRepository repository;
  final SicroAppImportService importService;

  @override
  State<SicroPackageReceivedScreen> createState() =>
      _SicroPackageReceivedScreenState();
}

class _SicroPackageReceivedScreenState
    extends State<SicroPackageReceivedScreen> {
  bool _importing = false;

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final summary = result.summary;
    return Scaffold(
      appBar: AppBar(title: const Text('Pacote SICRO recebido')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ValidationHeader(result: result),
            const SizedBox(height: 12),
            if (summary != null) _SummaryCard(summary: summary),
            if (summary != null) const SizedBox(height: 12),
            _FileCard(result: result),
            if (result.warnings.isNotEmpty) ...[
              const SizedBox(height: 12),
              _MessagesCard(
                title: 'Avisos',
                icon: Icons.info_outline,
                color: AppColors.gold,
                messages: result.warnings,
              ),
            ],
            if (result.errors.isNotEmpty) ...[
              const SizedBox(height: 12),
              _MessagesCard(
                title: 'Problemas encontrados',
                icon: Icons.error_outline,
                color: AppColors.danger,
                messages: result.errors,
              ),
            ],
            const SizedBox(height: 12),
            const _FutureImportCard(),
            const SizedBox(height: 20),
            if (result.isValid) ...[
              FilledButton.icon(
                onPressed: _importing ? null : _importPackage,
                icon: _importing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.file_download_outlined),
                label: Text(
                  _importing ? 'Importando...' : 'Importar ocorrencia',
                ),
              ),
              const SizedBox(height: 10),
            ],
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.check),
              label: const Text('Fechar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _importPackage() async {
    if (_importing) {
      return;
    }
    setState(() => _importing = true);
    try {
      final importResult = await widget.importService.importPackage(
        validation: widget.result,
        repository: widget.repository,
      );
      if (!mounted) {
        return;
      }
      if (!importResult.imported || importResult.occurrence == null) {
        await _showImportErrors(importResult.errors);
        return;
      }
      final occurrence = importResult.occurrence!;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ocorrencia importada com sucesso.'),
          backgroundColor: AppColors.success,
        ),
      );
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => OccurrenceDashboardScreen(
            repository: widget.repository,
            occurrenceId: occurrence.id,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _importing = false);
      }
    }
  }

  Future<void> _showImportErrors(List<String> errors) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Importacao nao concluida'),
          content: Text(
            errors.isEmpty
                ? 'Nao foi possivel importar este pacote.'
                : errors.join('\n'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fechar'),
            ),
          ],
        );
      },
    );
  }
}

class _ValidationHeader extends StatelessWidget {
  const _ValidationHeader({required this.result});

  final SicroAppPackageImportResult result;

  @override
  Widget build(BuildContext context) {
    final color = result.isValid ? AppColors.success : AppColors.danger;
    final icon = result.isValid
        ? Icons.verified_outlined
        : Icons.warning_amber_outlined;
    final title = result.isValid
        ? 'Pacote .sicroapp validado'
        : 'Pacote nao validado';
    final message = result.isValid
        ? 'O arquivo foi recebido, copiado para o armazenamento interno e possui manifest.json valido.'
        : 'O arquivo foi copiado para o app, mas precisa de revisao antes de ser importado.';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.75)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final SicroAppPackageSummary summary;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Resumo do dossie',
      icon: Icons.assignment_outlined,
      children: [
        _InfoRow(label: 'Tipo de pericia', value: summary.caseType),
        _InfoRow(label: 'Natureza', value: summary.nature),
        _InfoRow(label: 'Resultado', value: summary.result),
        _InfoRow(label: 'Gerado em', value: _dateTime(summary.generatedAt)),
        _InfoRow(label: 'BO', value: _valueOrDash(summary.bo)),
        _InfoRow(label: 'Protocolo', value: _valueOrDash(summary.protocol)),
        _InfoRow(label: 'Local', value: summary.locationLabel),
        const Divider(color: AppColors.border),
        _CounterGrid(summary: summary),
      ],
    );
  }
}

class _CounterGrid extends StatelessWidget {
  const _CounterGrid({required this.summary});

  final SicroAppPackageSummary summary;

  @override
  Widget build(BuildContext context) {
    final counters = [
      _CounterData('Fotos', summary.photosCount, Icons.photo_camera_outlined),
      _CounterData(
        'Vestigios',
        summary.tracesCount,
        Icons.scatter_plot_outlined,
      ),
      _CounterData(
        'Vitimas',
        summary.victimsCount,
        Icons.personal_injury_outlined,
      ),
      _CounterData(
        'Veiculos',
        summary.vehiclesCount,
        Icons.directions_car_outlined,
      ),
      _CounterData('Medicoes', summary.measurementsCount, Icons.straighten),
      _CounterData('Observacoes', summary.notesCount, Icons.notes_outlined),
    ];

    return GridView.builder(
      itemCount: counters.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.9,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (context, index) {
        final item = counters[index];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.base,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(item.icon, color: AppColors.gold, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Text(
                item.value.toString(),
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FileCard extends StatelessWidget {
  const _FileCard({required this.result});

  final SicroAppPackageImportResult result;

  @override
  Widget build(BuildContext context) {
    final package = result.packageFile;
    return _Panel(
      title: 'Arquivo recebido',
      icon: Icons.inventory_2_outlined,
      children: [
        _InfoRow(
          label: 'Nome original',
          value: _valueOrDash(package.originalName),
        ),
        _InfoRow(label: 'Copia interna', value: _valueOrDash(package.fileName)),
        _InfoRow(label: 'Tamanho', value: _size(package.sizeBytes)),
        _InfoRow(label: 'MIME recebido', value: _valueOrDash(package.mimeType)),
        _InfoRow(label: 'ZIP valido', value: result.validZip ? 'Sim' : 'Nao'),
        _InfoRow(
          label: 'Manifest',
          value: result.validManifest ? 'Valido' : 'Pendente',
        ),
        _InfoRow(
          label: 'Hashes',
          value: result.summary?.hashesPresent == true ? 'Presente' : 'Ausente',
        ),
      ],
    );
  }
}

class _FutureImportCard extends StatelessWidget {
  const _FutureImportCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.sync_alt_outlined, color: AppColors.gold),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Ao importar, o SICRO criara uma nova ocorrencia local editavel, copiando fotos para o armazenamento privado do app.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessagesCard extends StatelessWidget {
  const _MessagesCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.messages,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<String> messages;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: title,
      icon: icon,
      iconColor: color,
      children: messages
          .map(
            (message) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.icon,
    required this.children,
    this.iconColor = AppColors.gold,
  });

  final String title;
  final IconData icon;
  final Color iconColor;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
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
              Icon(icon, color: iconColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _CounterData {
  const _CounterData(this.label, this.value, this.icon);

  final String label;
  final int value;
  final IconData icon;
}

String _valueOrDash(String value) {
  return value.trim().isEmpty ? '-' : value;
}

String _dateTime(DateTime? value) {
  if (value == null) {
    return '-';
  }
  final local = value.toLocal();
  return '${_two(local.day)}/${_two(local.month)}/${local.year} '
      '${_two(local.hour)}:${_two(local.minute)}';
}

String _size(int bytes) {
  if (bytes <= 0) {
    return '-';
  }
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

String _two(int value) => value.toString().padLeft(2, '0');
