import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/theme/app_theme.dart';
import '../../core/data/app_backup_restore_service.dart';
import '../../core/data/app_backup_service.dart';
import '../../core/data/app_settings_repository.dart';
import '../../core/data/duty_shift_repository.dart';
import '../../core/data/official_document_repository.dart';
import '../../core/data/occurrence_repository.dart';
import '../../core/services/backup_notification_service.dart';
import '../../core/services/document_picker_channel.dart';
import '../../core/services/duty_shift_notification_service.dart';
import '../../domain/models/app_settings.dart';
import '../../shared/utils/share_origin.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({
    required this.settingsRepository,
    required this.occurrenceRepository,
    required this.officialDocumentRepository,
    required this.dutyShiftRepository,
    this.backupService,
    this.restoreService,
    this.documentPicker,
    this.backupNotificationService,
    this.dutyShiftNotificationService,
    super.key,
  });

  final AppSettingsRepository settingsRepository;
  final OccurrenceRepository occurrenceRepository;
  final OfficialDocumentRepository officialDocumentRepository;
  final DutyShiftRepository dutyShiftRepository;
  final AppBackupService? backupService;
  final AppBackupRestoreService? restoreService;
  final DocumentPickerChannel? documentPicker;
  final BackupNotificationService? backupNotificationService;
  final DutyShiftNotificationService? dutyShiftNotificationService;

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  late final AppBackupService _backupService;
  late final AppBackupRestoreService _restoreService;
  late final DocumentPickerChannel _documentPicker;
  late Future<AppBackupInventory> _inventoryFuture;
  bool _exporting = false;
  bool _restoring = false;

  @override
  void initState() {
    super.initState();
    _backupService = widget.backupService ?? AppBackupService();
    _restoreService = widget.restoreService ?? AppBackupRestoreService();
    _documentPicker = widget.documentPicker ?? DocumentPickerChannel();
    _inventoryFuture = _loadInventory();
  }

  Future<AppBackupInventory> _loadInventory() {
    return _backupService.inventory(
      occurrences: widget.occurrenceRepository.occurrences,
      officialDocuments: widget.officialDocumentRepository.documents,
      dutyShifts: widget.dutyShiftRepository.shifts,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.settingsRepository,
      builder: (context, _) {
        final settings = widget.settingsRepository.settings;
        return Scaffold(
          appBar: AppBar(title: const Text('Backup do SICRO')),
          body: SafeArea(
            child: FutureBuilder<AppBackupInventory>(
              future: _inventoryFuture,
              builder: (context, snapshot) {
                final inventory = snapshot.data;
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _BackupHero(settings: settings, inventory: inventory),
                    const SizedBox(height: 14),
                    _BackupContentsCard(inventory: inventory),
                    const SizedBox(height: 14),
                    _BackupReminderCard(
                      settings: settings,
                      onChanged: _updateReminder,
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: _exporting || _restoring || inventory == null
                          ? null
                          : _exportBackup,
                      icon: _exporting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.backup_outlined),
                      label: Text(
                        _exporting
                            ? 'Gerando backup...'
                            : 'Gerar backup completo',
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _exporting || _restoring
                          ? null
                          : _selectAndRestoreBackup,
                      icon: _restoring
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.restore_outlined),
                      label: Text(
                        _restoring
                            ? 'Restaurando backup...'
                            : 'Restaurar backup completo',
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'O backup e gerado offline como arquivo .sicrobackup e pode ser salvo na nuvem, enviado para o computador ou guardado em outra pasta segura.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _exportBackup() async {
    setState(() => _exporting = true);
    try {
      final result = await _backupService.exportFullBackup(
        settings: widget.settingsRepository.settings,
        occurrences: widget.occurrenceRepository.occurrences,
        officialDocuments: widget.officialDocumentRepository.documents,
        dutyShifts: widget.dutyShiftRepository.shifts,
      );
      final backup = widget.settingsRepository.settings.backup.copyWith(
        lastBackupAt: result.generatedAt,
        lastBackupFileName: result.fileName,
        lastBackupSha256: result.sha256,
        lastBackupSizeBytes: result.sizeBytes,
        lastBackupOccurrenceCount: result.inventory.occurrenceCount,
        lastBackupOfficialDocumentCount: result.inventory.officialDocumentCount,
        lastBackupDutyShiftCount: result.inventory.dutyShiftCount,
        lastBackupPhotoCount: result.inventory.photoCount,
      );
      await widget.settingsRepository.updateBackup(backup);
      await widget.backupNotificationService?.requestPermission();
      await widget.backupNotificationService?.reschedule(backup);
      if (!mounted) {
        return;
      }
      setState(() {
        _inventoryFuture = _loadInventory();
      });
      await _showBackupResult(result);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Falha ao gerar backup: $error'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  Future<void> _selectAndRestoreBackup() async {
    final picked = await _documentPicker.pickBackup();
    if (picked == null) {
      return;
    }
    if (!picked.ok) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(picked.nativeError ?? 'Falha ao selecionar backup.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _restoring = true);
    try {
      final validation = await _restoreService.validate(
        File(picked.filePath),
        fileName: picked.originalName.isEmpty
            ? picked.fileName
            : picked.originalName,
      );
      if (!mounted) {
        return;
      }
      if (!validation.isValid) {
        await _showInvalidBackup(validation);
        return;
      }
      final confirmed = await _confirmRestore(validation);
      if (confirmed != true) {
        return;
      }

      final oldOccurrences = widget.occurrenceRepository.occurrences;
      final oldOfficialDocuments = widget.officialDocumentRepository.documents;
      final result = await _restoreService.restore(validation);
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
      setState(() {
        _inventoryFuture = _loadInventory();
      });
      await _showRestoreResult(result);
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

  Future<void> _updateReminder({
    bool? enabled,
    int? intervalDays,
    int? preferredHour,
  }) async {
    final backup = widget.settingsRepository.settings.backup.copyWith(
      reminderEnabled: enabled,
      reminderIntervalDays: intervalDays,
      preferredHour: preferredHour,
    );
    await widget.settingsRepository.updateBackup(backup);
    await widget.backupNotificationService?.requestPermission();
    await widget.backupNotificationService?.reschedule(backup);
  }

  Future<void> _showBackupResult(AppBackupResult result) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Backup .sicrobackup gerado'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DialogLine(label: 'Arquivo', value: result.fileName),
                _DialogLine(
                  label: 'Tamanho',
                  value: _sizeLabel(result.sizeBytes),
                ),
                _DialogLine(
                  label: 'Ocorrencias',
                  value: result.inventory.occurrenceCount.toString(),
                ),
                _DialogLine(
                  label: 'Oficios',
                  value: result.inventory.officialDocumentCount.toString(),
                ),
                _DialogLine(
                  label: 'Plantoes',
                  value: result.inventory.dutyShiftCount.toString(),
                ),
                _DialogLine(
                  label: 'Midias',
                  value:
                      '${result.mediaIncluded} incluida(s), ${result.mediaMissing} ausente(s)',
                ),
                _DialogLine(label: 'Hash', value: _shortHash(result.sha256)),
                if (result.warnings.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'Avisos',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  for (final warning in result.warnings.take(5))
                    Text(
                      '- $warning',
                      style: const TextStyle(color: AppColors.textSecondary),
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
                await _shareBackup(result);
              },
              icon: const Icon(Icons.ios_share_outlined),
              label: const Text('Compartilhar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showInvalidBackup(AppBackupValidationResult validation) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Backup invalido'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DialogLine(label: 'Arquivo', value: validation.fileName),
                const SizedBox(height: 8),
                for (final error in validation.errors)
                  Text(
                    '- $error',
                    style: const TextStyle(color: AppColors.danger),
                  ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Entendi'),
            ),
          ],
        );
      },
    );
  }

  Future<bool?> _confirmRestore(AppBackupValidationResult validation) async {
    final summary = validation.summary;
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Restaurar backup completo?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Esta acao substituira os dados locais atuais pelos dados do backup selecionado. Use quando estiver migrando para outro aparelho ou recuperando uma instalacao.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                if (summary != null) ...[
                  _DialogLine(label: 'Arquivo', value: validation.fileName),
                  _DialogLine(
                    label: 'Gerado em',
                    value: summary.generatedAt == null
                        ? 'Nao informado'
                        : _dateTimeLabel(summary.generatedAt!),
                  ),
                  _DialogLine(
                    label: 'Perito',
                    value: summary.operatorName.isEmpty
                        ? 'Nao informado'
                        : summary.operatorName,
                  ),
                  _DialogLine(
                    label: 'Ocorrencias',
                    value: summary.occurrenceCount.toString(),
                  ),
                  _DialogLine(
                    label: 'Oficios',
                    value: summary.officialDocumentCount.toString(),
                  ),
                  _DialogLine(
                    label: 'Plantoes',
                    value: summary.dutyShiftCount.toString(),
                  ),
                  _DialogLine(
                    label: 'Midias',
                    value: summary.mediaCount.toString(),
                  ),
                  _DialogLine(
                    label: 'Hashes',
                    value: summary.hashesPresent ? 'Verificados' : 'Ausentes',
                  ),
                ],
                if (validation.warnings.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'Avisos',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  for (final warning in validation.warnings.take(4))
                    Text(
                      '- $warning',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.restore_outlined),
              label: const Text('Restaurar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showRestoreResult(AppBackupRestoreResult result) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Backup restaurado'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DialogLine(
                  label: 'Ocorrencias',
                  value: result.occurrences.length.toString(),
                ),
                _DialogLine(
                  label: 'Oficios',
                  value: result.officialDocuments.length.toString(),
                ),
                _DialogLine(
                  label: 'Plantoes',
                  value: result.dutyShifts.length.toString(),
                ),
                _DialogLine(
                  label: 'Midias',
                  value:
                      '${result.mediaRestored} restaurada(s), ${result.mediaMissing} ausente(s)',
                ),
                _DialogLine(
                  label: 'Relatorios',
                  value: result.reportsRestored.toString(),
                ),
                if (result.warnings.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'Avisos',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  for (final warning in result.warnings.take(5))
                    Text(
                      '- $warning',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                ],
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Concluir'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _shareBackup(AppBackupResult result) async {
    if (!await result.file.exists()) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('O backup nao foi encontrado no aparelho.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    if (!mounted) {
      return;
    }
    await SharePlus.instance.share(
      ShareParams(
        title: 'Compartilhar backup SICRO',
        subject: result.fileName,
        text:
            'Backup completo do SICRO Operacional. Hash SHA256: ${result.sha256}',
        sharePositionOrigin: sharePositionOriginFor(context),
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
}

class _BackupHero extends StatelessWidget {
  const _BackupHero({required this.settings, required this.inventory});

  final AppSettings settings;
  final AppBackupInventory? inventory;

  @override
  Widget build(BuildContext context) {
    final backup = settings.backup;
    final now = DateTime.now();
    final stale = backup.isStale(now);
    final title = backup.hasBackup
        ? stale
              ? 'Backup recomendado'
              : 'Backup em dia'
        : 'Nenhum backup registrado';
    final subtitle = backup.hasBackup
        ? 'Ultimo backup: ${_dateTimeLabel(backup.lastBackupAt!)}'
        : 'Gere um arquivo unico para proteger ocorrencias, oficios, plantoes, fotos e relatorios.';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: stale ? AppColors.gold : AppColors.success),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                stale ? Icons.backup_outlined : Icons.verified_outlined,
                color: stale ? AppColors.gold : AppColors.success,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (backup.hasBackup && inventory != null) ...[
            const SizedBox(height: 12),
            _DeltaLine(
              label: 'Novas ocorrencias',
              value:
                  inventory!.occurrenceCount - backup.lastBackupOccurrenceCount,
            ),
            _DeltaLine(
              label: 'Novos oficios',
              value:
                  inventory!.officialDocumentCount -
                  backup.lastBackupOfficialDocumentCount,
            ),
            _DeltaLine(
              label: 'Novos plantoes',
              value:
                  inventory!.dutyShiftCount - backup.lastBackupDutyShiftCount,
            ),
            _DeltaLine(
              label: 'Novas fotos',
              value: inventory!.photoCount - backup.lastBackupPhotoCount,
            ),
          ],
        ],
      ),
    );
  }
}

class _BackupContentsCard extends StatelessWidget {
  const _BackupContentsCard({required this.inventory});

  final AppBackupInventory? inventory;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Conteudo do backup',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 10),
            if (inventory == null)
              const LinearProgressIndicator()
            else ...[
              _ContentRow(
                icon: Icons.assignment_outlined,
                label: 'Ocorrencias',
                value: inventory!.occurrenceCount.toString(),
              ),
              _ContentRow(
                icon: Icons.mark_email_read_outlined,
                label: 'Oficios',
                value: inventory!.officialDocumentCount.toString(),
              ),
              _ContentRow(
                icon: Icons.event_available_outlined,
                label: 'Plantoes',
                value: inventory!.dutyShiftCount.toString(),
              ),
              _ContentRow(
                icon: Icons.photo_library_outlined,
                label: 'Midias',
                value: inventory!.mediaCount.toString(),
              ),
              _ContentRow(
                icon: Icons.picture_as_pdf_outlined,
                label: 'Relatorios PDF',
                value: inventory!.reportCount.toString(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BackupReminderCard extends StatelessWidget {
  const _BackupReminderCard({required this.settings, required this.onChanged});

  final AppSettings settings;
  final Future<void> Function({
    bool? enabled,
    int? intervalDays,
    int? preferredHour,
  })
  onChanged;

  @override
  Widget build(BuildContext context) {
    final backup = settings.backup;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: backup.reminderEnabled,
              onChanged: (value) => onChanged(enabled: value),
              title: const Text(
                'Lembrete de backup',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text(
                'Recomendacao atual: a cada ${backup.reminderIntervalDays} dias, preferencialmente as ${_two(backup.preferredHour)}:00.',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Intervalo',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final days in const [7, 15, 30])
                  ChoiceChip(
                    label: Text('$days dias'),
                    selected: backup.reminderIntervalDays == days,
                    onSelected: (_) => onChanged(intervalDays: days),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'O backup automatico direto em nuvem depende de permissao de pasta do Android e fica preparado para a proxima etapa. Nesta versao, o app avisa e gera o pacote completo para voce salvar onde preferir.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContentRow extends StatelessWidget {
  const _ContentRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: Row(
        children: [
          Icon(icon, color: AppColors.gold, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _DeltaLine extends StatelessWidget {
  const _DeltaLine({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final normalized = value < 0 ? 0 : value;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Text(
            normalized.toString(),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _DialogLine extends StatelessWidget {
  const _DialogLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
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

String _sizeLabel(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }
  final kb = bytes / 1024;
  if (kb < 1024) {
    return '${kb.toStringAsFixed(1)} KB';
  }
  final mb = kb / 1024;
  if (mb < 1024) {
    return '${mb.toStringAsFixed(1)} MB';
  }
  final gb = mb / 1024;
  return '${gb.toStringAsFixed(2)} GB';
}

String _shortHash(String hash) {
  if (hash.length <= 16) {
    return hash;
  }
  return '${hash.substring(0, 16)}...';
}

String _two(int value) => value.toString().padLeft(2, '0');
