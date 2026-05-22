import 'dart:io';

import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../domain/models/field_photo.dart';

class LinkedPhotosPanel extends StatelessWidget {
  const LinkedPhotosPanel({
    required this.title,
    required this.allPhotos,
    required this.linkedPhotoIds,
    required this.onChanged,
    super.key,
  });

  final String title;
  final List<FieldPhoto> allPhotos;
  final List<String> linkedPhotoIds;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    final linkedPhotos = _linkedPhotos();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.photo_library_outlined, color: AppColors.gold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                '${linkedPhotos.length}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (linkedPhotos.isEmpty)
            const Text(
              'Nenhuma foto vinculada a este item.',
              style: TextStyle(color: AppColors.textSecondary),
            )
          else
            SizedBox(
              height: 118,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: linkedPhotos.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final photo = linkedPhotos[index];
                  return _LinkedPhotoThumbnail(
                    photo: photo,
                    onRemove: () => _remove(photo.id),
                  );
                },
              ),
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: allPhotos.isEmpty
                ? null
                : () async {
                    final selected = await _openPicker(context);
                    if (selected != null) {
                      onChanged(selected);
                    }
                  },
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text(
              allPhotos.isEmpty ? 'Nenhuma foto capturada' : 'Vincular foto',
            ),
          ),
        ],
      ),
    );
  }

  List<FieldPhoto> _linkedPhotos() {
    final linked = <FieldPhoto>[];
    for (final id in linkedPhotoIds) {
      for (final photo in allPhotos) {
        if (photo.id == id) {
          linked.add(photo);
          break;
        }
      }
    }
    return linked;
  }

  void _remove(String photoId) {
    onChanged(linkedPhotoIds.where((id) => id != photoId).toList());
  }

  Future<List<String>?> _openPicker(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    return showModalBottomSheet<List<String>>(
      context: context,
      backgroundColor: AppColors.panel,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: BoxConstraints(maxHeight: screenHeight * 0.88),
      builder: (context) {
        return _PhotoLinkPicker(
          photos: allPhotos,
          initiallySelectedIds: linkedPhotoIds,
        );
      },
    );
  }
}

class _LinkedPhotoThumbnail extends StatelessWidget {
  const _LinkedPhotoThumbnail({required this.photo, required this.onRemove});

  final FieldPhoto photo;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 108,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.panel,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(
                File(photo.filePath),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: AppColors.textSecondary,
                    ),
                  );
                },
              ),
              Positioned(
                top: 5,
                right: 5,
                child: Material(
                  color: AppColors.base.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(999),
                  child: IconButton(
                    tooltip: 'Remover vinculo',
                    onPressed: onRemove,
                    icon: const Icon(Icons.close, size: 18),
                    color: AppColors.textPrimary,
                    constraints: const BoxConstraints(
                      minWidth: 30,
                      minHeight: 30,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
              Positioned(
                left: 6,
                right: 6,
                bottom: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.base.withValues(alpha: 0.76),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    photo.category.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoLinkPicker extends StatefulWidget {
  const _PhotoLinkPicker({
    required this.photos,
    required this.initiallySelectedIds,
  });

  final List<FieldPhoto> photos;
  final List<String> initiallySelectedIds;

  @override
  State<_PhotoLinkPicker> createState() => _PhotoLinkPickerState();
}

class _PhotoLinkPickerState extends State<_PhotoLinkPicker> {
  late final Set<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = {...widget.initiallySelectedIds};
  }

  @override
  Widget build(BuildContext context) {
    final photos = [...widget.photos]
      ..sort((a, b) => b.capturedAt.compareTo(a.capturedAt));

    return SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Vincular fotos',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      '${_selectedIds.length} selecionada(s)',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: constraints.maxWidth >= 520 ? 3 : 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.82,
                  ),
                  itemCount: photos.length,
                  itemBuilder: (context, index) {
                    final photo = photos[index];
                    final selected = _selectedIds.contains(photo.id);
                    return _PickerPhotoCard(
                      photo: photo,
                      selected: selected,
                      onTap: () => _toggle(photo.id),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop(_orderedSelection());
                        },
                        icon: const Icon(Icons.check),
                        label: const Text('Salvar vinculos'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _toggle(String photoId) {
    setState(() {
      if (_selectedIds.contains(photoId)) {
        _selectedIds.remove(photoId);
      } else {
        _selectedIds.add(photoId);
      }
    });
  }

  List<String> _orderedSelection() {
    return widget.photos
        .where((photo) => _selectedIds.contains(photo.id))
        .map((photo) => photo.id)
        .toList();
  }
}

class _PickerPhotoCard extends StatelessWidget {
  const _PickerPhotoCard({
    required this.photo,
    required this.selected,
    required this.onTap,
  });

  final FieldPhoto photo;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.gold : AppColors.border,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(8),
                    ),
                    child: Image.file(
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
                  ),
                  Positioned(
                    top: 7,
                    right: 7,
                    child: Icon(
                      selected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: selected ? AppColors.gold : AppColors.textPrimary,
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
                    photo.category.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _dateLabel(photo.capturedAt),
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

String _dateLabel(DateTime value) {
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day/$month $hour:$minute';
}
