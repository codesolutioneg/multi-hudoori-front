import 'package:flutter/material.dart';

import '../../../core/di/injection.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/entity_id.dart';
import '../../../l10n/l10n_extension.dart';

/// «تدرج الوظائف» — the seniority ladder the org chart derives its reporting
/// lines from. Levels run from the most senior on the left; job titles are
/// dragged between them. A title left in the «غير مصنفة» pool falls back to the
/// built-in guess, so a half-finished ladder is still safe.
class JobLadderSettingsSection extends StatefulWidget {
  const JobLadderSettingsSection({super.key});

  @override
  State<JobLadderSettingsSection> createState() =>
      _JobLadderSettingsSectionState();
}

class _JobLadderSettingsSectionState extends State<JobLadderSettingsSection> {
  List<Map<String, dynamic>> _levels = [];
  List<Map<String, dynamic>> _unassigned = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _apply(Map<String, dynamic> data) {
    _levels = (data['levels'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    _unassigned = (data['unassigned'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await api.jobLevelsList();
      if (!mounted) return;
      setState(() {
        _apply(data);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  /// Every write returns the whole ladder, so the UI never guesses the new state.
  Future<void> _mutate(Future<Map<String, dynamic>> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final data = await action();
      if (!mounted) return;
      setState(() {
        _apply(data);
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(e.toString(), isError: true);
    }
  }

  void _toast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.danger : AppColors.success,
      ),
    );
  }

  Future<void> _addLevel() async {
    final result = await showDialog<_LevelDraft>(
      context: context,
      builder: (_) => const _LevelDialog(),
    );
    if (result == null) return;
    await _mutate(
      () => api.jobLevelCreate(
        name: result.name,
        nameEn: result.nameEn,
        code: result.code,
      ),
    );
  }

  Future<void> _editLevel(Map<String, dynamic> level) async {
    final result = await showDialog<_LevelDraft>(
      context: context,
      builder: (_) => _LevelDialog(
        initialName: level['name']?.toString() ?? '',
        initialNameEn: level['nameEn']?.toString() ?? '',
        initialCode: level['code']?.toString() ?? '',
      ),
    );
    if (result == null) return;
    await _mutate(
      () => api.jobLevelUpdate(
        id: EntityId.parse(level['id']) ?? '',
        name: result.name,
        nameEn: result.nameEn,
        code: result.code,
      ),
    );
  }

  Future<void> _deleteLevel(Map<String, dynamic> level) async {
    final titles = (level['titles'] as List? ?? []).length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t('ladder.deleteLevel')),
        content: Text(
          titles == 0
              ? context.t('ladder.deleteAsk', {'name': level['name']})
              : context.t('ladder.deleteAskTitles', {
                  'name': level['name'],
                  'count': titles,
                }),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.t('common.cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.t('common.delete')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _mutate(() => api.jobLevelDelete(EntityId.parse(level['id']) ?? ''));
  }

  Future<void> _moveLevel(int index, int delta) async {
    final target = index + delta;
    if (target < 0 || target >= _levels.length) return;
    final ids = _levels.map((l) => EntityId.parse(l['id']) ?? '').toList();
    final moved = ids.removeAt(index);
    ids.insert(target, moved);
    await _mutate(() => api.jobLevelsReorder(ids));
  }

  Future<void> _assign(String titleId, String? levelId) => _mutate(
    () => api.jobLevelAssignTitle(jobTitleId: titleId, levelId: levelId),
  );

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.danger),
              ),
            ),
            TextButton(onPressed: _load, child: Text(context.t('common.retry'))),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(),
        const SizedBox(height: 16),
        _ladder(),
        const SizedBox(height: 20),
        _unassignedPool(),
      ],
    );
  }

  Widget _header() {
    return Row(
      children: [
        Expanded(
          child: Text(
            context.t('ladder.hint'),
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
        ),
        const SizedBox(width: 12),
        if (_busy)
          const Padding(
            padding: EdgeInsets.only(left: 12),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        OutlinedButton.icon(
          onPressed: _busy ? null : _addLevel,
          icon: const Icon(Icons.add, size: 16),
          label: Text(context.t('ladder.newLevel')),
        ),
      ],
    );
  }

  Widget _ladder() {
    if (_levels.isEmpty) {
      return _emptyBox(context.t('ladder.noLevels'));
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < _levels.length; i++) ...[
            if (i > 0)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Padding(
                  padding: EdgeInsets.only(top: 44),
                  child: Icon(
                    Icons.arrow_back,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            _LevelCard(
              level: _levels[i],
              index: i,
              total: _levels.length,
              busy: _busy,
              onEdit: () => _editLevel(_levels[i]),
              onDelete: () => _deleteLevel(_levels[i]),
              onMove: (delta) => _moveLevel(i, delta),
              onAcceptTitle: (titleId) =>
                  _assign(titleId, EntityId.parse(_levels[i]['id'])),
            ),
          ],
        ],
      ),
    );
  }

  Widget _unassignedPool() {
    return DragTarget<String>(
      onWillAcceptWithDetails: (_) => !_busy,
      onAcceptWithDetails: (d) => _assign(d.data, null),
      builder: (context, candidate, _) {
        final hot = candidate.isNotEmpty;
        return AnimatedContainer(
          duration: Duration(milliseconds: 120),
          padding: EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: hot ? AppColors.primarySoft : AppColors.muted,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hot ? AppColors.primary : AppColors.border,
              width: hot ? 1.4 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.inbox_outlined,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    context.t('ladder.unassigned', {'count': _unassigned.length}),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                context.t('ladder.unassignedHint'),
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
              const SizedBox(height: 10),
              if (_unassigned.isEmpty)
                Text(
                  context.t('ladder.allAssigned'),
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                )
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final t in _unassigned)
                      _TitleChip(title: t, enabled: !_busy),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _emptyBox(String message) => Container(
    padding: const EdgeInsets.symmetric(vertical: 28),
    decoration: BoxDecoration(
      color: AppColors.muted,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.border),
    ),
    child: Center(
      child: Text(
        message,
        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
      ),
    ),
  );
}

/// One tier in the ladder, styled after the workflow-state cards: a small kind
/// badge, the level name, its code in mono, then the titles it holds.
class _LevelCard extends StatelessWidget {
  const _LevelCard({
    required this.level,
    required this.index,
    required this.total,
    required this.busy,
    required this.onEdit,
    required this.onDelete,
    required this.onMove,
    required this.onAcceptTitle,
  });

  final Map<String, dynamic> level;
  final int index;
  final int total;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final void Function(int delta) onMove;
  final void Function(String titleId) onAcceptTitle;

  String _kind(BuildContext context) {
    if (index == 0) return context.t('ladder.top');
    if (index == total - 1) return context.t('ladder.bottom');
    return context.t('ladder.middle');
  }

  Color get _kindColor {
    if (index == 0) return AppColors.primary;
    if (index == total - 1) return AppColors.textMuted;
    return AppColors.info;
  }

  @override
  Widget build(BuildContext context) {
    final titles = (level['titles'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final code = level['code']?.toString() ?? '';

    return DragTarget<String>(
      onWillAcceptWithDetails: (_) => !busy,
      onAcceptWithDetails: (d) => onAcceptTitle(d.data),
      builder: (context, candidate, _) {
        final hot = candidate.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 250,
          constraints: const BoxConstraints(minHeight: 150),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: hot ? AppColors.primarySoft : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hot ? AppColors.primary : AppColors.border,
              width: hot ? 1.4 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    _kind(context),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: _kindColor,
                    ),
                  ),
                  const Spacer(),
                  _iconBtn(
                    Icons.chevron_right,
                    busy || index == 0,
                    () => onMove(-1),
                    context.t('ladder.moveUp'),
                  ),
                  _iconBtn(
                    Icons.chevron_left,
                    busy || index == total - 1,
                    () => onMove(1),
                    context.t('ladder.moveDown'),
                  ),
                  _iconBtn(Icons.edit_outlined, busy, onEdit, context.t('common.edit')),
                  _iconBtn(Icons.delete_outline, busy, onDelete, context.t('common.delete')),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                level['name']?.toString() ?? '',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              if (code.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  code,
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: AppColors.textMuted,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              if (titles.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.muted,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.border,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      context.t('ladder.dropHere'),
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                )
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final t in titles)
                      _TitleChip(title: t, enabled: !busy),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _iconBtn(
    IconData icon,
    bool disabled,
    VoidCallback onTap,
    String tip,
  ) {
    return Tooltip(
      message: tip,
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Icon(
            icon,
            size: 15,
            color: disabled ? AppColors.border : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// A draggable job title. Carries the title id as the drag payload.
class _TitleChip extends StatelessWidget {
  const _TitleChip({required this.title, required this.enabled});

  final Map<String, dynamic> title;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final id = EntityId.parse(title['id']) ?? '';
    final name = title['name']?.toString() ?? '';
    final count = (title['employeeCount'] as num?)?.toInt() ?? 0;
    final chip = _chip(name, count, dragging: false);

    if (!enabled || id.isEmpty) return Opacity(opacity: 0.5, child: chip);

    return Draggable<String>(
      data: id,
      feedback: Material(
        color: Colors.transparent,
        child: _chip(name, count, dragging: true),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: chip),
      child: MouseRegion(cursor: SystemMouseCursors.grab, child: chip),
    );
  }

  Widget _chip(String name, int count, {required bool dragging}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: dragging ? AppColors.primary : AppColors.primarySoft,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: dragging ? AppColors.primary : AppColors.border,
        ),
        boxShadow: dragging
            ? const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.drag_indicator,
            size: 13,
            color: dragging ? Colors.white70 : AppColors.textMuted,
          ),
          const SizedBox(width: 3),
          Text(
            name,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: dragging ? Colors.white : AppColors.textPrimary,
            ),
          ),
          if (count > 0) ...[
            const SizedBox(width: 5),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 10,
                color: dragging ? Colors.white70 : AppColors.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LevelDraft {
  const _LevelDraft(this.name, this.nameEn, this.code);
  final String name;
  final String nameEn;
  final String code;
}

class _LevelDialog extends StatefulWidget {
  const _LevelDialog({
    this.initialName = '',
    this.initialNameEn = '',
    this.initialCode = '',
  });

  final String initialName;
  final String initialNameEn;
  final String initialCode;

  @override
  State<_LevelDialog> createState() => _LevelDialogState();
}

class _LevelDialogState extends State<_LevelDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initialName,
  );
  late final TextEditingController _nameEn = TextEditingController(
    text: widget.initialNameEn,
  );
  late final TextEditingController _code = TextEditingController(
    text: widget.initialCode,
  );

  @override
  void dispose() {
    _name.dispose();
    _nameEn.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initialName.isNotEmpty;
    return AlertDialog(
      title: Text(editing ? context.t('ladder.editLevel') : context.t('ladder.newLevel')),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              decoration: InputDecoration(
                labelText: context.t('common.name'),
                hintText: context.t('ladder.nameExample'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameEn,
              decoration: InputDecoration(
                labelText: context.t('ladder.nameEn'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _code,
              decoration: InputDecoration(
                labelText: context.t('set.jobTitleCodeOpt'),
                hintText: 'supervisor',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.t('common.cancel')),
        ),
        FilledButton(
          onPressed: () {
            final name = _name.text.trim();
            if (name.isEmpty) return;
            Navigator.pop(
              context,
              _LevelDraft(name, _nameEn.text.trim(), _code.text.trim()),
            );
          },
          child: Text(editing ? context.t('common.save') : context.t('common.add')),
        ),
      ],
    );
  }
}
