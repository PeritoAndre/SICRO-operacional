import 'dart:io';

import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/data/occurrence_repository.dart';
import '../../core/data/photo_file_storage.dart';
import '../../core/services/photo_capture_service.dart';
import '../../domain/models/field_photo.dart';
import '../../domain/models/occurrence.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/operational_applicability_card.dart';

const _mvpCategories = [
  PhotoCategory.overview,
  PhotoCategory.vehicle,
  PhotoCategory.victim,
  PhotoCategory.trace,
  PhotoCategory.detail,
];

class PhotosScreen extends StatefulWidget {
  const PhotosScreen({
    required this.repository,
    required this.occurrenceId,
    this.captureService,
    this.fileStorage,
    super.key,
  });

  final OccurrenceRepository repository;
  final String occurrenceId;
  final PhotoCaptureService? captureService;
  final PhotoFileStorage? fileStorage;

  @override
  State<PhotosScreen> createState() => _PhotosScreenState();
}

class _PhotosScreenState extends State<PhotosScreen> {
  late final PhotoCaptureService _captureService;
  late final PhotoFileStorage _fileStorage;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _captureService = widget.captureService ?? PhotoCaptureService();
    _fileStorage = widget.fileStorage ?? PhotoFileStorage();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.repository,
      builder: (context, _) {
        final occurrence = widget.repository.findById(widget.occurrenceId);
        if (occurrence == null) {
          return const Scaffold(
            body: EmptyState(
              icon: Icons.error_outline,
              title: 'Ocorrencia nao encontrada',
              message: 'Nao foi possivel acessar as fotos deste dossie.',
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Fotos categorizadas')),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              children: [
                _PhotoHeader(occurrence: occurrence),
                const SizedBox(height: 14),
                OperationalApplicabilityCard(
                  title: 'Fotos de vestigio',
                  message:
                      'Use quando nao havia vestigio relevante a fotografar.',
                  notApplicable: occurrence.isNotApplicable(
                    OperationalItemIds.tracePhotos,
                  ),
                  onChanged: (value) =>
                      widget.repository.setOperationalItemNotApplicable(
                        widget.occurrenceId,
                        OperationalItemIds.tracePhotos,
                        value,
                      ),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _busy ? null : _capturePhoto,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.photo_camera_outlined),
                  label: const Text('Capturar foto'),
                ),
                const SizedBox(height: 18),
                if (occurrence.photos.isEmpty)
                  const EmptyState(
                    icon: Icons.photo_library_outlined,
                    title: 'Nenhuma foto no dossie',
                    message:
                        'Capture fotos por categoria para organizar a coleta pericial desde o local.',
                  )
                else
                  ..._buildSections(occurrence),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildSections(FieldOccurrence occurrence) {
    final sections = <Widget>[];
    for (final category in _mvpCategories) {
      final photos =
          occurrence.photos
              .where((photo) => photo.category == category)
              .toList()
            ..sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
      if (photos.isEmpty) {
        continue;
      }
      sections.add(
        _CategorySection(
          category: category,
          photos: photos,
          onDelete: _confirmDelete,
        ),
      );
      sections.add(const SizedBox(height: 14));
    }
    return sections;
  }

  Future<void> _capturePhoto() async {
    setState(() => _busy = true);
    try {
      final captured = await _captureService.capturePhoto();
      if (captured == null) {
        return;
      }
      if (!mounted) {
        return;
      }
      final category = await _chooseCategory(context);
      if (category == null) {
        return;
      }
      final photo = await _fileStorage.saveCapturedPhoto(
        occurrenceId: widget.occurrenceId,
        capturedFile: captured,
        category: category,
      );
      await widget.repository.addPhoto(widget.occurrenceId, photo);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Foto salva em ${category.label}.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Falha ao capturar foto: $error'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<PhotoCategory?> _chooseCategory(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    return showModalBottomSheet<PhotoCategory>(
      context: context,
      backgroundColor: AppColors.panel,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: BoxConstraints(maxHeight: screenHeight * 0.86),
      builder: (context) => const _CategoryPicker(),
    );
  }

  Future<void> _confirmDelete(FieldPhoto photo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remover foto?'),
          content: const Text(
            'A foto sera removida do dossie local desta ocorrencia.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Remover'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final removed = await widget.repository.removePhoto(
      widget.occurrenceId,
      photo.id,
    );
    if (removed != null) {
      await _fileStorage.deletePhoto(removed);
    }
  }
}

class _PhotoHeader extends StatelessWidget {
  const _PhotoHeader({required this.occurrence});

  final FieldOccurrence occurrence;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.photo_camera_outlined, color: AppColors.gold),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${occurrence.photos.length} foto(s) no dossie',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Fotos salvas localmente por ocorrencia e categoria.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Classificar foto',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (final category in _mvpCategories)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        child: ListTile(
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          onTap: () => Navigator.of(context).pop(category),
                          leading: Icon(
                            _iconFor(category),
                            color: AppColors.gold,
                          ),
                          title: Text(
                            category.label,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.category,
    required this.photos,
    required this.onDelete,
  });

  final PhotoCategory category;
  final List<FieldPhoto> photos;
  final ValueChanged<FieldPhoto> onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
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
              Icon(_iconFor(category), color: AppColors.gold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  category.label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${photos.length}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.82,
            ),
            itemCount: photos.length,
            itemBuilder: (context, index) {
              return _PhotoCard(photo: photos[index], onDelete: onDelete);
            },
          ),
        ],
      ),
    );
  }
}

class _PhotoCard extends StatelessWidget {
  const _PhotoCard({required this.photo, required this.onDelete});

  final FieldPhoto photo;
  final ValueChanged<FieldPhoto> onDelete;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(
                    File(photo.filePath),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const ColoredBox(
                        color: AppColors.panel,
                        child: Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      );
                    },
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Material(
                      color: AppColors.base.withValues(alpha: 0.78),
                      borderRadius: BorderRadius.circular(999),
                      child: IconButton(
                        tooltip: 'Remover foto',
                        onPressed: () => onDelete(photo),
                        icon: const Icon(Icons.delete_outline, size: 20),
                        color: AppColors.danger,
                        constraints: const BoxConstraints(
                          minWidth: 34,
                          minHeight: 34,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _dateLabel(photo.capturedAt),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    photo.sha256.isEmpty
                        ? 'Hash pendente'
                        : 'SHA ${_shortHash(photo.sha256)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
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

IconData _iconFor(PhotoCategory category) {
  return switch (category) {
    PhotoCategory.overview => Icons.landscape_outlined,
    PhotoCategory.vehicle => Icons.directions_car_outlined,
    PhotoCategory.victim => Icons.personal_injury_outlined,
    PhotoCategory.trace => Icons.scatter_plot_outlined,
    PhotoCategory.detail => Icons.center_focus_strong_outlined,
    _ => Icons.photo_outlined,
  };
}

String _dateLabel(DateTime value) {
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day/$month $hour:$minute';
}

String _shortHash(String hash) {
  if (hash.length <= 8) {
    return hash;
  }
  return hash.substring(0, 8);
}
