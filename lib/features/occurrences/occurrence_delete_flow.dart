import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/data/occurrence_repository.dart';
import '../../core/data/photo_file_storage.dart';
import '../../core/data/sicrocampo_export_service.dart';
import '../../domain/models/occurrence.dart';

Future<bool> confirmAndDeleteOccurrence({
  required BuildContext context,
  required OccurrenceRepository repository,
  required FieldOccurrence occurrence,
  PhotoFileStorage? photoStorage,
  SicroCampoExportService? exportService,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Excluir ocorrencia?'),
        content: const Text(
          'Esta acao removera os dados locais, fotos e vinculos desta ocorrencia. Nao podera ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      );
    },
  );

  if (confirmed != true || !context.mounted) {
    return false;
  }

  try {
    final removed = await repository.deleteOccurrence(occurrence.id);
    if (removed == null) {
      throw StateError('Ocorrencia nao encontrada.');
    }

    await (photoStorage ?? PhotoFileStorage()).deleteOccurrencePhotos(
      occurrenceId: removed.id,
      photos: removed.photos,
    );
    await (exportService ?? SicroCampoExportService()).deleteExportedPackage(
      removed.exportedPackageName,
    );

    if (!context.mounted) {
      return true;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Ocorrencia excluida com sucesso.')),
      );
    return true;
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Falha ao excluir ocorrencia: $error'),
            backgroundColor: AppColors.danger,
          ),
        );
    }
    return false;
  }
}
