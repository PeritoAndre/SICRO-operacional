import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/data/occurrence_repository.dart';
import '../../domain/models/checklist_item.dart';
import '../../domain/models/forensic_case_metadata.dart';
import '../../domain/models/occurrence.dart';
import '../../shared/widgets/empty_state.dart';

const _answerOptions = [
  ChecklistAnswer.yes,
  ChecklistAnswer.no,
  ChecklistAnswer.notApplicable,
  ChecklistAnswer.unchecked,
];

enum _ChecklistItemAction { edit, delete }

class ChecklistScreen extends StatefulWidget {
  const ChecklistScreen({
    required this.repository,
    required this.occurrenceId,
    super.key,
  });

  final OccurrenceRepository repository;
  final String occurrenceId;

  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends State<ChecklistScreen> {
  final Map<String, TextEditingController> _noteControllers = {};
  final Map<String, FocusNode> _noteFocusNodes = {};
  final Map<String, Timer> _noteTimers = {};
  final Map<String, String> _lastSavedNotes = {};

  @override
  void dispose() {
    for (final itemId in _noteControllers.keys) {
      _saveNoteNow(itemId);
    }
    for (final timer in _noteTimers.values) {
      timer.cancel();
    }
    for (final controller in _noteControllers.values) {
      controller.dispose();
    }
    for (final focusNode in _noteFocusNodes.values) {
      focusNode.dispose();
    }
    super.dispose();
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
              message: 'Nao foi possivel acessar o checklist deste dossie.',
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(title: Text(_screenTitle(occurrence))),
          body: SafeArea(
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              children: [
                _ChecklistHeader(occurrence: occurrence),
                const SizedBox(height: 12),
                _AddChecklistItemButton(
                  onPressed: () => _addChecklistItem(occurrence),
                ),
                const SizedBox(height: 14),
                for (final category in ChecklistCategory.values) ...[
                  if (_itemsFor(occurrence, category).isNotEmpty)
                    _ChecklistCategorySection(
                      category: category,
                      items: _itemsFor(occurrence, category),
                      controllerFor: _noteControllerFor,
                      focusNodeFor: _noteFocusNodeFor,
                      onAnswerChanged: _setAnswer,
                      onNoteChanged: _scheduleNoteSave,
                      onEditItem: _editChecklistItem,
                      onDeleteItem: _confirmDeleteChecklistItem,
                    ),
                  if (_itemsFor(occurrence, category).isNotEmpty)
                    const SizedBox(height: 14),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _addChecklistItem(FieldOccurrence occurrence) async {
    final draft = await showDialog<_ChecklistItemDraft>(
      context: context,
      builder: (context) => _ChecklistItemFormDialog(
        categoryOptions: _categoryOptionsFor(occurrence.metadata.type),
      ),
    );
    if (draft == null) {
      return;
    }
    await widget.repository.addChecklistItem(
      widget.occurrenceId,
      category: draft.category,
      question: draft.question,
      required: draft.required,
      defaultNote: draft.defaultNote,
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Item adicionado ao checklist.')),
    );
  }

  Future<void> _editChecklistItem(ChecklistItem item) async {
    _saveNoteNow(item.id);
    final occurrence = widget.repository.findById(widget.occurrenceId);
    final draft = await showDialog<_ChecklistItemDraft>(
      context: context,
      builder: (context) => _ChecklistItemFormDialog(
        item: item,
        categoryOptions: _categoryOptionsFor(
          occurrence?.metadata.type ?? ForensicCaseType.traffic,
        ),
      ),
    );
    if (draft == null) {
      return;
    }
    await widget.repository.updateChecklistQuestion(
      widget.occurrenceId,
      item.copyWith(
        category: draft.category,
        question: draft.question,
        required: draft.required,
        defaultNote: draft.defaultNote,
      ),
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Item do checklist atualizado.')),
    );
  }

  Future<void> _confirmDeleteChecklistItem(ChecklistItem item) async {
    final hasResponse =
        item.answer != ChecklistAnswer.unchecked || item.note.trim().isNotEmpty;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Excluir item?'),
          content: Text(
            hasResponse
                ? 'Este item ja possui resposta ou observacao. Ao excluir, a resposta sera removida junto.'
                : 'Este item sera removido apenas deste dossie.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    _noteTimers.remove(item.id)?.cancel();
    _noteControllers.remove(item.id)?.dispose();
    _noteFocusNodes.remove(item.id)?.dispose();
    _lastSavedNotes.remove(item.id);
    final removed = await widget.repository.removeChecklistItem(
      widget.occurrenceId,
      item.id,
    );
    if (!mounted || removed == null) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Item removido do checklist.')),
    );
  }

  List<ChecklistItem> _itemsFor(
    FieldOccurrence occurrence,
    ChecklistCategory category,
  ) {
    return occurrence.checklist
        .where((item) => item.category == category)
        .toList(growable: false);
  }

  TextEditingController _noteControllerFor(ChecklistItem item) {
    final existing = _noteControllers[item.id];
    if (existing != null) {
      return existing;
    }
    _lastSavedNotes[item.id] = item.note;
    final controller = TextEditingController(text: item.note);
    _noteControllers[item.id] = controller;
    return controller;
  }

  FocusNode _noteFocusNodeFor(ChecklistItem item) {
    final existing = _noteFocusNodes[item.id];
    if (existing != null) {
      return existing;
    }
    final focusNode = FocusNode();
    focusNode.addListener(() {
      if (!focusNode.hasFocus) {
        _saveNoteNow(item.id);
      }
    });
    _noteFocusNodes[item.id] = focusNode;
    return focusNode;
  }

  Future<void> _setAnswer(ChecklistItem item, ChecklistAnswer answer) async {
    if (item.answer == answer) {
      return;
    }
    await widget.repository.updateChecklistItem(
      widget.occurrenceId,
      item.id,
      answer: answer,
    );
  }

  void _scheduleNoteSave(String itemId, String _) {
    _noteTimers[itemId]?.cancel();
    _noteTimers[itemId] = Timer(
      const Duration(milliseconds: 450),
      () => _saveNoteNow(itemId),
    );
  }

  void _saveNoteNow(String itemId) {
    _noteTimers.remove(itemId)?.cancel();
    final controller = _noteControllers[itemId];
    if (controller == null) {
      return;
    }
    final note = controller.text;
    if (_lastSavedNotes[itemId] == note) {
      return;
    }
    _lastSavedNotes[itemId] = note;
    unawaited(
      widget.repository.updateChecklistItem(
        widget.occurrenceId,
        itemId,
        note: note,
      ),
    );
  }
}

class _ChecklistHeader extends StatelessWidget {
  const _ChecklistHeader({required this.occurrence});

  final FieldOccurrence occurrence;

  @override
  Widget build(BuildContext context) {
    final total = occurrence.checklist.length;
    final answered = occurrence.answeredChecklistItems;
    final pendingRequired = occurrence.pendingRequiredChecklistItems;
    final progress = occurrence.checklistProgress;

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
              const Icon(Icons.checklist_outlined, color: AppColors.gold),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Checklist operacional',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              _ProgressBadge(progress: progress),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.base,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.gold),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetricChip(
                icon: Icons.done_all_outlined,
                label: '$answered/$total respondidos',
                color: AppColors.success,
              ),
              _MetricChip(
                icon: Icons.priority_high_outlined,
                label: '$pendingRequired obrigatorios pendentes',
                color: pendingRequired == 0
                    ? AppColors.success
                    : AppColors.gold,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChecklistCategorySection extends StatelessWidget {
  const _ChecklistCategorySection({
    required this.category,
    required this.items,
    required this.controllerFor,
    required this.focusNodeFor,
    required this.onAnswerChanged,
    required this.onNoteChanged,
    required this.onEditItem,
    required this.onDeleteItem,
  });

  final ChecklistCategory category;
  final List<ChecklistItem> items;
  final TextEditingController Function(ChecklistItem item) controllerFor;
  final FocusNode Function(ChecklistItem item) focusNodeFor;
  final Future<void> Function(ChecklistItem item, ChecklistAnswer answer)
  onAnswerChanged;
  final void Function(String itemId, String note) onNoteChanged;
  final void Function(ChecklistItem item) onEditItem;
  final void Function(ChecklistItem item) onDeleteItem;

  @override
  Widget build(BuildContext context) {
    final answered = items
        .where((item) => item.answer != ChecklistAnswer.unchecked)
        .length;

    return Container(
      padding: const EdgeInsets.all(14),
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
              Icon(_categoryIcon(category), color: AppColors.gold),
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
                '$answered/${items.length}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < items.length; index++) ...[
            _ChecklistItemTile(
              item: items[index],
              noteController: controllerFor(items[index]),
              noteFocusNode: focusNodeFor(items[index]),
              onAnswerChanged: onAnswerChanged,
              onNoteChanged: onNoteChanged,
              onEdit: onEditItem,
              onDelete: onDeleteItem,
            ),
            if (index < items.length - 1)
              const Divider(height: 22, color: AppColors.border),
          ],
        ],
      ),
    );
  }
}

class _ChecklistItemTile extends StatelessWidget {
  const _ChecklistItemTile({
    required this.item,
    required this.noteController,
    required this.noteFocusNode,
    required this.onAnswerChanged,
    required this.onNoteChanged,
    required this.onEdit,
    required this.onDelete,
  });

  final ChecklistItem item;
  final TextEditingController noteController;
  final FocusNode noteFocusNode;
  final Future<void> Function(ChecklistItem item, ChecklistAnswer answer)
  onAnswerChanged;
  final void Function(String itemId, String note) onNoteChanged;
  final void Function(ChecklistItem item) onEdit;
  final void Function(ChecklistItem item) onDelete;

  @override
  Widget build(BuildContext context) {
    final pendingRequired =
        item.required && item.answer == ChecklistAnswer.unchecked;
    final dropdownSpec = _dropdownSpecFor(item.id);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: pendingRequired ? AppColors.gold : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.question,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              if (item.required) ...[
                const SizedBox(width: 8),
                const _RequiredBadge(),
              ],
              const SizedBox(width: 4),
              PopupMenuButton<_ChecklistItemAction>(
                tooltip: 'Opcoes do item',
                icon: const Icon(
                  Icons.more_vert,
                  color: AppColors.textSecondary,
                ),
                onSelected: (action) {
                  switch (action) {
                    case _ChecklistItemAction.edit:
                      onEdit(item);
                    case _ChecklistItemAction.delete:
                      onDelete(item);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: _ChecklistItemAction.edit,
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Editar'),
                    ),
                  ),
                  PopupMenuItem(
                    value: _ChecklistItemAction.delete,
                    child: ListTile(
                      leading: Icon(Icons.delete_outline),
                      title: Text('Excluir'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (item.defaultNote.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              item.defaultNote,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final answer in _answerOptions)
                _AnswerChip(
                  answer: answer,
                  selected: item.answer == answer,
                  onSelected: () => onAnswerChanged(item, answer),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (dropdownSpec != null) ...[
            _ChecklistDropdownField(
              spec: dropdownSpec,
              controller: noteController,
              onChanged: (value) {
                onNoteChanged(item.id, value);
                if (item.answer == ChecklistAnswer.unchecked) {
                  unawaited(onAnswerChanged(item, ChecklistAnswer.yes));
                }
              },
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: noteController,
            focusNode: noteFocusNode,
            onChanged: (note) => onNoteChanged(item.id, note),
            minLines: 1,
            maxLines: 3,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              labelText: dropdownSpec == null
                  ? 'Observacao opcional'
                  : 'Complemento opcional',
              prefixIcon: const Icon(Icons.notes_outlined),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChecklistDropdownSpec {
  const _ChecklistDropdownSpec({
    required this.label,
    required this.icon,
    required this.options,
  });

  final String label;
  final IconData icon;
  final List<String> options;
}

class _ChecklistDropdownField extends StatelessWidget {
  const _ChecklistDropdownField({
    required this.spec,
    required this.controller,
    required this.onChanged,
  });

  final _ChecklistDropdownSpec spec;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final current = controller.text.trim();
    final value = spec.options.contains(current) ? current : null;

    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: spec.label,
        prefixIcon: Icon(spec.icon),
      ),
      items: [
        for (final option in spec.options)
          DropdownMenuItem(value: option, child: Text(option)),
      ],
      onChanged: (value) {
        if (value == null) {
          return;
        }
        controller.text = value;
        onChanged(value);
      },
    );
  }
}

class _AddChecklistItemButton extends StatelessWidget {
  const _AddChecklistItemButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.add_task_outlined),
      label: const Text('Adicionar item'),
    );
  }
}

class _ChecklistItemDraft {
  const _ChecklistItemDraft({
    required this.category,
    required this.question,
    required this.required,
    required this.defaultNote,
  });

  final ChecklistCategory category;
  final String question;
  final bool required;
  final String defaultNote;
}

class _ChecklistItemFormDialog extends StatefulWidget {
  const _ChecklistItemFormDialog({required this.categoryOptions, this.item});

  final ChecklistItem? item;
  final List<ChecklistCategory> categoryOptions;

  @override
  State<_ChecklistItemFormDialog> createState() =>
      _ChecklistItemFormDialogState();
}

class _ChecklistItemFormDialogState extends State<_ChecklistItemFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late ChecklistCategory _category;
  late bool _required;
  late final TextEditingController _questionController;
  late final TextEditingController _defaultNoteController;

  List<ChecklistCategory> get _availableCategories {
    final categories = [...widget.categoryOptions];
    final current = widget.item?.category;
    if (current != null && !categories.contains(current)) {
      categories.add(current);
    }
    return categories;
  }

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _category = item?.category ?? _availableCategories.first;
    _required = item?.required ?? false;
    _questionController = TextEditingController(text: item?.question ?? '');
    _defaultNoteController = TextEditingController(
      text: item?.defaultNote ?? '',
    );
  }

  @override
  void dispose() {
    _questionController.dispose();
    _defaultNoteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.item != null;
    return AlertDialog(
      scrollable: true,
      title: Text(editing ? 'Editar item' : 'Adicionar item'),
      content: SafeArea(
        top: false,
        bottom: false,
        child: Form(
          key: _formKey,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _questionController,
                  minLines: 2,
                  maxLines: 4,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(
                    labelText: 'Pergunta',
                    prefixIcon: Icon(Icons.help_outline),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Informe a pergunta.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<ChecklistCategory>(
                  initialValue: _category,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Categoria',
                    prefixIcon: Icon(Icons.folder_outlined),
                  ),
                  items: [
                    for (final category in _availableCategories)
                      DropdownMenuItem(
                        value: category,
                        child: Text(category.label),
                      ),
                  ],
                  onChanged: (category) {
                    if (category == null) {
                      return;
                    }
                    setState(() => _category = category);
                  },
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _required,
                  onChanged: (value) => setState(() => _required = value),
                  title: const Text('Obrigatorio'),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _defaultNoteController,
                  minLines: 1,
                  maxLines: 3,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(
                    labelText: 'Observacao padrao opcional',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(editing ? 'Salvar' : 'Adicionar'),
        ),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    Navigator.of(context).pop(
      _ChecklistItemDraft(
        category: _category,
        question: _questionController.text.trim(),
        required: _required,
        defaultNote: _defaultNoteController.text.trim(),
      ),
    );
  }
}

class _AnswerChip extends StatelessWidget {
  const _AnswerChip({
    required this.answer,
    required this.selected,
    required this.onSelected,
  });

  final ChecklistAnswer answer;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final color = _answerColor(answer);
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onSelected(),
      label: Text(answer.label),
      selectedColor: color.withValues(alpha: 0.2),
      backgroundColor: AppColors.panel,
      side: BorderSide(color: selected ? color : AppColors.border),
      labelStyle: TextStyle(
        color: selected ? color : AppColors.textSecondary,
        fontWeight: FontWeight.w800,
      ),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _ProgressBadge extends StatelessWidget {
  const _ProgressBadge({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.7)),
      ),
      child: Text(
        '${(progress * 100).round()}%',
        style: const TextStyle(
          color: AppColors.gold,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _RequiredBadge extends StatelessWidget {
  const _RequiredBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.7)),
      ),
      child: const Text(
        'Obrigatorio',
        style: TextStyle(
          color: AppColors.gold,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

IconData _categoryIcon(ChecklistCategory category) {
  return switch (category) {
    ChecklistCategory.preservation => Icons.verified_user_outlined,
    ChecklistCategory.victims => Icons.personal_injury_outlined,
    ChecklistCategory.vehicles => Icons.directions_car_outlined,
    ChecklistCategory.roadConditions => Icons.alt_route_outlined,
    ChecklistCategory.sketchSurvey => Icons.map_outlined,
    ChecklistCategory.pavement => Icons.layers_outlined,
    ChecklistCategory.lighting => Icons.lightbulb_outline,
    ChecklistCategory.weatherVisibility => Icons.visibility_outlined,
    ChecklistCategory.signaling => Icons.signpost_outlined,
    ChecklistCategory.trafficLight => Icons.traffic_outlined,
    ChecklistCategory.traces => Icons.scatter_plot_outlined,
    ChecklistCategory.bodyVictim => Icons.accessibility_new_outlined,
    ChecklistCategory.biologicalTraces => Icons.biotech_outlined,
    ChecklistCategory.ballisticTraces => Icons.gps_fixed_outlined,
    ChecklistCategory.weaponsObjects => Icons.construction_outlined,
    ChecklistCategory.environment => Icons.home_work_outlined,
    ChecklistCategory.photographicRecord => Icons.photo_camera_outlined,
    ChecklistCategory.propertyGoods => Icons.inventory_2_outlined,
    ChecklistCategory.documentation => Icons.description_outlined,
    ChecklistCategory.damage => Icons.broken_image_outlined,
    ChecklistCategory.burglary => Icons.lock_open_outlined,
    ChecklistCategory.fire => Icons.local_fire_department_outlined,
    ChecklistCategory.environmentalPlanning => Icons.map_outlined,
    ChecklistCategory.environmentalScene => Icons.terrain_outlined,
    ChecklistCategory.environmentalDamage => Icons.eco_outlined,
    ChecklistCategory.environmentalSamples => Icons.science_outlined,
    ChecklistCategory.ballisticReceipt => Icons.inventory_2_outlined,
    ChecklistCategory.ballisticSafety => Icons.health_and_safety_outlined,
    ChecklistCategory.firearms => Icons.gps_fixed_outlined,
    ChecklistCategory.ammunition => Icons.adjust_outlined,
    ChecklistCategory.gsrCollection => Icons.science_outlined,
    ChecklistCategory.ballisticComparison => Icons.compare_arrows_outlined,
    ChecklistCategory.multimediaReceipt => Icons.inventory_2_outlined,
    ChecklistCategory.multimediaPreservation => Icons.shield_outlined,
    ChecklistCategory.multimediaAdequacy => Icons.fact_check_outlined,
    ChecklistCategory.multimediaProcessing => Icons.video_settings_outlined,
    ChecklistCategory.cctvCollection => Icons.videocam_outlined,
    ChecklistCategory.facialComparison => Icons.face_outlined,
    ChecklistCategory.speakerComparison => Icons.record_voice_over_outlined,
    ChecklistCategory.imageAuthenticity => Icons.verified_outlined,
    ChecklistCategory.papiloscopyBiosafety => Icons.health_and_safety_outlined,
    ChecklistCategory.papiloscopyCollection => Icons.fingerprint,
    ChecklistCategory.papiloscopyDevelopment => Icons.manage_search_outlined,
    ChecklistCategory.papiloscopyIdentification => Icons.badge_outlined,
    ChecklistCategory.papiloscopyLab => Icons.science_outlined,
    ChecklistCategory.papiloscopyNecro => Icons.accessibility_new_outlined,
    ChecklistCategory.chainOfCustody => Icons.inventory_outlined,
  };
}

List<ChecklistCategory> _categoryOptionsFor(ForensicCaseType type) {
  return switch (type) {
    ForensicCaseType.traffic => const [
      ChecklistCategory.preservation,
      ChecklistCategory.victims,
      ChecklistCategory.vehicles,
      ChecklistCategory.roadConditions,
      ChecklistCategory.sketchSurvey,
      ChecklistCategory.pavement,
      ChecklistCategory.lighting,
      ChecklistCategory.weatherVisibility,
      ChecklistCategory.signaling,
      ChecklistCategory.trafficLight,
      ChecklistCategory.traces,
      ChecklistCategory.photographicRecord,
    ],
    ForensicCaseType.violentDeath => const [
      ChecklistCategory.preservation,
      ChecklistCategory.environment,
      ChecklistCategory.photographicRecord,
      ChecklistCategory.traces,
      ChecklistCategory.chainOfCustody,
      ChecklistCategory.bodyVictim,
      ChecklistCategory.victims,
      ChecklistCategory.biologicalTraces,
      ChecklistCategory.ballisticTraces,
      ChecklistCategory.weaponsObjects,
      ChecklistCategory.vehicles,
    ],
    ForensicCaseType.property => const [
      ChecklistCategory.preservation,
      ChecklistCategory.propertyGoods,
      ChecklistCategory.documentation,
      ChecklistCategory.damage,
      ChecklistCategory.burglary,
      ChecklistCategory.fire,
      ChecklistCategory.traces,
      ChecklistCategory.environment,
      ChecklistCategory.photographicRecord,
    ],
    ForensicCaseType.environmental => const [
      ChecklistCategory.environmentalPlanning,
      ChecklistCategory.environmentalScene,
      ChecklistCategory.environmentalDamage,
      ChecklistCategory.traces,
      ChecklistCategory.environmentalSamples,
      ChecklistCategory.chainOfCustody,
      ChecklistCategory.documentation,
      ChecklistCategory.photographicRecord,
      ChecklistCategory.fire,
    ],
    ForensicCaseType.ballistics => const [
      ChecklistCategory.ballisticReceipt,
      ChecklistCategory.ballisticSafety,
      ChecklistCategory.firearms,
      ChecklistCategory.ammunition,
      ChecklistCategory.ballisticTraces,
      ChecklistCategory.gsrCollection,
      ChecklistCategory.ballisticComparison,
      ChecklistCategory.photographicRecord,
      ChecklistCategory.chainOfCustody,
      ChecklistCategory.documentation,
    ],
    ForensicCaseType.audioImage => const [
      ChecklistCategory.multimediaReceipt,
      ChecklistCategory.multimediaPreservation,
      ChecklistCategory.multimediaAdequacy,
      ChecklistCategory.multimediaProcessing,
      ChecklistCategory.cctvCollection,
      ChecklistCategory.facialComparison,
      ChecklistCategory.speakerComparison,
      ChecklistCategory.imageAuthenticity,
      ChecklistCategory.photographicRecord,
      ChecklistCategory.chainOfCustody,
      ChecklistCategory.documentation,
    ],
    ForensicCaseType.papiloscopy => const [
      ChecklistCategory.papiloscopyBiosafety,
      ChecklistCategory.papiloscopyCollection,
      ChecklistCategory.papiloscopyDevelopment,
      ChecklistCategory.papiloscopyIdentification,
      ChecklistCategory.papiloscopyLab,
      ChecklistCategory.papiloscopyNecro,
      ChecklistCategory.photographicRecord,
      ChecklistCategory.chainOfCustody,
      ChecklistCategory.documentation,
      ChecklistCategory.preservation,
    ],
  };
}

String _screenTitle(FieldOccurrence occurrence) {
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

_ChecklistDropdownSpec? _dropdownSpecFor(String itemId) {
  return switch (itemId) {
    'tipo_via_registrado' => const _ChecklistDropdownSpec(
      label: 'Tipo de via/pavimento',
      icon: Icons.alt_route_outlined,
      options: _roadTypeOptions,
    ),
    'sinalizacao_vertical' => const _ChecklistDropdownSpec(
      label: 'Placa/sinalizacao principal',
      icon: Icons.signpost_outlined,
      options: _trafficSignOptions,
    ),
    _ => null,
  };
}

const _roadTypeOptions = [
  'Asfalto urbano',
  'Asfalto rodoviario',
  'Concreto',
  'Paralelepipedo/bloquete',
  'Picarra/cascalho',
  'Terra/ramal',
  'Rural/estrada vicinal',
  'Ponte/viaduto',
  'Estacionamento/patio',
  'Outro',
];

const _trafficSignOptions = [
  'PARE (R-1)',
  'De a preferencia (R-2)',
  'Velocidade maxima',
  'Proibido ultrapassar',
  'Proibido estacionar',
  'Proibido parar e estacionar',
  'Sentido obrigatorio',
  'Proibido virar a esquerda',
  'Proibido virar a direita',
  'Passagem obrigatoria',
  'Area escolar',
  'Pedestre',
  'Semaforo a frente',
  'Intersecao a frente',
  'Curva acentuada',
  'Pista escorregadia',
  'Lombada',
  'Animais na pista',
  'Obras',
  'Outra',
];

Color _answerColor(ChecklistAnswer answer) {
  return switch (answer) {
    ChecklistAnswer.yes => AppColors.success,
    ChecklistAnswer.no => AppColors.danger,
    ChecklistAnswer.notApplicable => AppColors.textSecondary,
    ChecklistAnswer.unchecked => AppColors.gold,
  };
}
