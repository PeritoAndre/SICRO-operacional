import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/data/occurrence_repository.dart';
import '../../domain/models/field_note.dart';
import '../../domain/models/occurrence.dart';
import '../../shared/widgets/empty_state.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({
    required this.repository,
    required this.occurrenceId,
    super.key,
  });

  final OccurrenceRepository repository;
  final String occurrenceId;

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  String _query = '';
  NoteCategory? _categoryFilter;
  bool _creating = false;

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
              message: 'Nao foi possivel acessar as observacoes deste dossie.',
            ),
          );
        }

        final notes = _filteredNotes(occurrence);

        return Scaffold(
          appBar: AppBar(title: const Text('Observacoes')),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 96),
              children: [
                _NotesHeader(occurrence: occurrence),
                const SizedBox(height: 14),
                TextField(
                  onChanged: (value) => setState(() => _query = value),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Buscar nas observacoes',
                  ),
                ),
                const SizedBox(height: 10),
                _CategoryFilterBar(
                  selected: _categoryFilter,
                  onChanged: (category) {
                    setState(() => _categoryFilter = category);
                  },
                ),
                const SizedBox(height: 14),
                if (notes.isEmpty)
                  const EmptyState(
                    icon: Icons.notes_outlined,
                    title: 'Nenhuma observacao encontrada',
                    message:
                        'Registre anotacoes livres sobre o local, dinamica, pendencias ou pontos de atencao.',
                  )
                else
                  for (final note in notes) ...[
                    _NoteCard(
                      note: note,
                      onTap: () => _openEditor(note),
                      onDelete: () => _confirmDelete(note),
                    ),
                    const SizedBox(height: 10),
                  ],
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _creating ? null : _createNote,
            icon: _creating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add),
            label: const Text('Adicionar'),
          ),
        );
      },
    );
  }

  List<FieldNote> _filteredNotes(FieldOccurrence occurrence) {
    final query = _query.trim().toLowerCase();
    final notes = occurrence.notes.where((note) {
      final matchesQuery =
          query.isEmpty ||
          note.text.toLowerCase().contains(query) ||
          note.category.label.toLowerCase().contains(query) ||
          note.priority.label.toLowerCase().contains(query);
      final matchesCategory =
          _categoryFilter == null || note.category == _categoryFilter;
      return matchesQuery && matchesCategory;
    }).toList();
    notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return notes;
  }

  Future<void> _createNote() async {
    setState(() => _creating = true);
    try {
      final note = await widget.repository.createNote(widget.occurrenceId);
      if (!mounted || note == null) {
        return;
      }
      _openEditor(note);
    } finally {
      if (mounted) {
        setState(() => _creating = false);
      }
    }
  }

  void _openEditor(FieldNote note) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _NoteEditorScreen(
          repository: widget.repository,
          occurrenceId: widget.occurrenceId,
          noteId: note.id,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(FieldNote note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remover observacao?'),
          content: const Text('A nota sera removida deste dossie.'),
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

    if (confirmed == true) {
      await widget.repository.removeNote(widget.occurrenceId, note.id);
    }
  }
}

class _NoteEditorScreen extends StatefulWidget {
  const _NoteEditorScreen({
    required this.repository,
    required this.occurrenceId,
    required this.noteId,
  });

  final OccurrenceRepository repository;
  final String occurrenceId;
  final String noteId;

  @override
  State<_NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<_NoteEditorScreen> {
  final _textController = TextEditingController();
  Timer? _saveTimer;
  NoteCategory _category = NoteCategory.general;
  NotePriority _priority = NotePriority.normal;
  bool _initialized = false;
  String? _lastSavedSignature;

  @override
  void dispose() {
    _saveNow();
    _saveTimer?.cancel();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.repository,
      builder: (context, _) {
        final note = _findNote();
        if (note == null) {
          return const Scaffold(
            body: EmptyState(
              icon: Icons.error_outline,
              title: 'Observacao nao encontrada',
              message: 'A nota pode ter sido removida deste dossie.',
            ),
          );
        }
        _initialize(note);

        return Scaffold(
          appBar: AppBar(title: const Text('Editar observacao')),
          body: SafeArea(
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              children: [
                _EditorHeader(note: note),
                const SizedBox(height: 14),
                DropdownButtonFormField<NoteCategory>(
                  initialValue: _category,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Categoria',
                    prefixIcon: Icon(Icons.sell_outlined),
                  ),
                  items: NoteCategory.values.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category.label),
                    );
                  }).toList(),
                  onChanged: (category) {
                    if (category == null) {
                      return;
                    }
                    setState(() => _category = category);
                    _saveNow();
                  },
                ),
                const SizedBox(height: 12),
                const Text(
                  'Prioridade',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final priority in NotePriority.values)
                      ChoiceChip(
                        selected: _priority == priority,
                        label: Text(priority.label),
                        onSelected: (_) {
                          setState(() => _priority = priority);
                          _saveNow();
                        },
                        selectedColor: _priorityColor(
                          priority,
                        ).withValues(alpha: 0.2),
                        backgroundColor: AppColors.panel,
                        side: BorderSide(
                          color: _priority == priority
                              ? _priorityColor(priority)
                              : AppColors.border,
                        ),
                        labelStyle: TextStyle(
                          color: _priority == priority
                              ? _priorityColor(priority)
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _textController,
                  onChanged: _scheduleSave,
                  minLines: 8,
                  maxLines: 16,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(
                    labelText: 'Texto da observacao',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _initialize(FieldNote note) {
    if (_initialized) {
      return;
    }
    _textController.text = note.text;
    _category = note.category;
    _priority = note.priority;
    _lastSavedSignature = _signature(note);
    _initialized = true;
  }

  FieldNote? _findNote() {
    final occurrence = widget.repository.findById(widget.occurrenceId);
    if (occurrence == null) {
      return null;
    }
    for (final note in occurrence.notes) {
      if (note.id == widget.noteId) {
        return note;
      }
    }
    return null;
  }

  void _scheduleSave(String _) {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 450), _saveNow);
  }

  void _saveNow() {
    _saveTimer?.cancel();
    final current = _findNote();
    if (current == null || !_initialized) {
      return;
    }
    final updated = current.copyWith(
      text: _textController.text.trim(),
      category: _category,
      priority: _priority,
    );
    final signature = _signature(updated);
    if (_lastSavedSignature == signature) {
      return;
    }
    _lastSavedSignature = signature;
    unawaited(widget.repository.updateNote(widget.occurrenceId, updated));
  }
}

class _NotesHeader extends StatelessWidget {
  const _NotesHeader({required this.occurrence});

  final FieldOccurrence occurrence;

  @override
  Widget build(BuildContext context) {
    final highlighted = occurrence.notes
        .where((note) => note.priority != NotePriority.normal)
        .length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.notes_outlined, color: AppColors.gold),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${occurrence.notes.length} observacao(oes)',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '$highlighted importante(s)/critica(s)',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryFilterBar extends StatelessWidget {
  const _CategoryFilterBar({required this.selected, required this.onChanged});

  final NoteCategory? selected;
  final ValueChanged<NoteCategory?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              selected: selected == null,
              label: const Text('Todas'),
              onSelected: (_) => onChanged(null),
              selectedColor: AppColors.gold.withValues(alpha: 0.2),
              backgroundColor: AppColors.panel,
              side: BorderSide(
                color: selected == null ? AppColors.gold : AppColors.border,
              ),
            ),
          ),
          for (final category in NoteCategory.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                selected: selected == category,
                label: Text(category.label),
                onSelected: (_) => onChanged(category),
                selectedColor: AppColors.gold.withValues(alpha: 0.2),
                backgroundColor: AppColors.panel,
                side: BorderSide(
                  color: selected == category
                      ? AppColors.gold
                      : AppColors.border,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.note,
    required this.onTap,
    required this.onDelete,
  });

  final FieldNote note;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final color = _priorityColor(note.priority);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: color, width: 4)),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_categoryIcon(note.category), color: AppColors.gold),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      note.category.label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  _PriorityBadge(priority: note.priority),
                  IconButton(
                    tooltip: 'Remover observacao',
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                    color: AppColors.danger,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                note.text.isEmpty ? 'Observacao sem texto' : note.text,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoChip(
                    icon: Icons.schedule_outlined,
                    label: 'Criada ${_dateLabel(note.createdAt)}',
                  ),
                  _InfoChip(
                    icon: Icons.edit_outlined,
                    label: 'Editada ${_dateLabel(note.updatedAt)}',
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

class _EditorHeader extends StatelessWidget {
  const _EditorHeader({required this.note});

  final FieldNote note;

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
          Icon(_categoryIcon(note.category), color: AppColors.gold),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.category.label,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'Criada ${_dateLabel(note.createdAt)}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          _PriorityBadge(priority: note.priority),
        ],
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.priority});

  final NotePriority priority;

  @override
  Widget build(BuildContext context) {
    final color = _priorityColor(priority);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Text(
        priority.label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.gold),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

IconData _categoryIcon(NoteCategory category) {
  return switch (category) {
    NoteCategory.general => Icons.notes_outlined,
    NoteCategory.location => Icons.place_outlined,
    NoteCategory.vehicle => Icons.directions_car_outlined,
    NoteCategory.victim => Icons.personal_injury_outlined,
    NoteCategory.trace => Icons.scatter_plot_outlined,
    NoteCategory.dynamics => Icons.route_outlined,
    NoteCategory.pending => Icons.pending_actions_outlined,
    NoteCategory.other => Icons.more_horiz_outlined,
  };
}

Color _priorityColor(NotePriority priority) {
  return switch (priority) {
    NotePriority.normal => AppColors.textSecondary,
    NotePriority.important => AppColors.gold,
    NotePriority.critical => AppColors.danger,
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

String _signature(FieldNote note) {
  return [note.text, note.category.code, note.priority.code].join('|');
}
