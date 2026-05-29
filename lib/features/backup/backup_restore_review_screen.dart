import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/data/app_backup_restore_service.dart';
import '../../core/data/app_settings_repository.dart';
import '../../core/data/duty_shift_repository.dart';
import '../../core/data/official_document_repository.dart';
import '../../core/data/occurrence_repository.dart';
import '../../core/services/backup_notification_service.dart';
import '../../core/services/duty_shift_notification_service.dart';

class BackupRestoreReviewScreen extends StatefulWidget {
  const BackupRestoreReviewScreen({
    required this.validation,
    required this.settingsRepository,
    required this.occurrenceRepository,
    required this.officialDocumentRepository,
    required this.dutyShiftRepository,
    this.restoreService,
    this.backupNotificationService,
    this.dutyShiftNotificationService,
    super.key,
  });

  final AppBackupValidationResult validation;
  final AppSettingsRepository settingsRepository;
  final OccurrenceRepository occurrenceRepository;
  final OfficialDocumentRepository officialDocumentRepository;
  final DutyShiftRepository dutyShiftRepository;
  final AppBackupRestoreService? restoreService;
  final BackupNotificationService? backupNotificationService;
  final DutyShiftNotificationService? dutyShiftNotificationService;

  @override
  State<BackupRestoreReviewScreen> createState() =>
      _BackupRestoreReviewScreenState();
}

class _BackupRestoreReviewScreenState extends State<BackupRestoreReviewScreen> {
  late final AppBackupRestoreService _restoreService;
  bool _restoring = false;

  @override
  void initState() {
    super.initState();
    _restoreService = widget.restoreService ?? AppBackupRestoreService();
  }

  @override
  Widget build(BuildContext context) {
    final validation = widget.validation;
    final summary = validation.summary;
    return Scaffold(
      appBar: AppBar(title: const Text('Backup recebido')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.panel,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: validation.isValid
                      ? AppColors.success
                      : AppColors.danger,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        validation.isValid
                            ? Icons.verified_outlined
                            : Icons.error_outline,
                        color: validation.isValid
                            ? AppColors.success
                            : AppColors.danger,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          validation.isValid
                              ? 'Backup valido'
                              : 'Backup nao pode ser restaurado',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    validation.fileName,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (summary != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Resumo do backup',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _Line(
                        label: 'Gerado em',
                        value: summary.generatedAt == null
                            ? 'Nao informado'
                            : _dateTimeLabel(summary.generatedAt!),
                      ),
                      _Line(
                        label: 'Perito',
                        value: summary.operatorName.isEmpty
                            ? 'Nao informado'
                            : summary.operatorName,
                      ),
                      _Line(
                        label: 'Ocorrencias',
                        value: summary.occurrenceCount.toString(),
                      ),
                      _Line(
                        label: 'Oficios',
                        value: summary.officialDocumentCount.toString(),
                      ),
                      _Line(
                        label: 'Plantoes',
                        value: summary.dutyShiftCount.toString(),
                      ),
                      _Line(
                        label: 'Midias',
                        value: summary.mediaCount.toString(),
                      ),
                      _Line(
                        label: 'Relatorios',
                        value: summary.reportCount.toString(),
                      ),
                    ],
                  ),
                ),
              ),
            if (validation.errors.isNotEmpty) ...[
              const SizedBox(height: 14),
              _MessageCard(
                title: 'Erros',
                color: AppColors.danger,
                items: validation.errors,
              ),
            ],
            if (validation.warnings.isNotEmpty) ...[
              const SizedBox(height: 14),
              _MessageCard(
                title: 'Avisos',
                color: AppColors.gold,
                items: validation.warnings,
              ),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: validation.isValid && !_restoring
                  ? _confirmAndRestore
                  : null,
              icon: _restoring
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.restore_outlined),
              label: Text(_restoring ? 'Restaurando...' : 'Restaurar backup'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAndRestore() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Substituir dados locais?'),
          content: const Text(
            'A restauracao completa substitui ocorrencias, oficios, plantoes e configuracoes deste aparelho pelos dados do backup.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Restaurar'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }

    setState(() => _restoring = true);
    try {
      final oldOccurrences = widget.occurrenceRepository.occurrences;
      final oldOfficialDocuments = widget.officialDocumentRepository.documents;
      final result = await _restoreService.restore(widget.validation);
      await widget.settingsRepository.restoreSettings(result.settings);
      await widget.occurrenceRepository.restoreOccurrences(result.occurrences);
      await widget.officialDocumentRepository.restoreDocuments(
        result.officialDocuments,
      );
      await widget.dutyShiftRepository.restoreShifts(result.dutyShifts);
      await widget.backupNotificationService?.requestPermission();
      await widget.backupNotificationService?.reschedule(
        result.settings.backup,
      );
      await widget.dutyShiftNotificationService?.requestPermission();
      await widget.dutyShiftNotificationService?.rescheduleAll(
        result.dutyShifts,
      );
      await _restoreService.cleanupReplacedLocalFiles(
        oldOccurrences: oldOccurrences,
        oldOfficialDocuments: oldOfficialDocuments,
        restored: result,
      );

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup restaurado com sucesso.')),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Falha ao restaurar backup: $error'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _restoring = false);
      }
    }
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.title,
    required this.color,
    required this.items,
  });

  final String title;
  final Color color;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(color: color, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '- $item',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

String _dateTimeLabel(DateTime value) {
  final local = value.toLocal();
  return '${_two(local.day)}/${_two(local.month)}/${local.year} '
      '${_two(local.hour)}:${_two(local.minute)}';
}

String _two(int value) => value.toString().padLeft(2, '0');
