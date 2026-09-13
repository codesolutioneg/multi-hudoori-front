import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/sellix_card.dart';
import '../../l10n/l10n_extension.dart';

class ShiftGridUntrackedUser {
  const ShiftGridUntrackedUser({
    required this.excelRow,
    required this.code,
    required this.excelName,
    required this.excelJob,
    required this.filledShiftCells,
    required this.reason,
  });

  final int excelRow;
  final String code;
  final String excelName;
  final String excelJob;
  final int filledShiftCells;
  final String reason;

  factory ShiftGridUntrackedUser.fromJson(Map<String, dynamic> json) {
    return ShiftGridUntrackedUser(
      excelRow: (json['excelRow'] as num?)?.toInt() ?? 0,
      code: json['code']?.toString() ?? '',
      excelName: json['excelName']?.toString() ?? '',
      excelJob: json['excelJob']?.toString() ?? '',
      filledShiftCells: (json['filledShiftCells'] as num?)?.toInt() ?? 0,
      reason: json['reason']?.toString() ?? '',
    );
  }
}

/// Banner shown on the grid page after import when Excel rows reference unknown codes.
class ShiftGridImportUntrackedBanner extends StatelessWidget {
  const ShiftGridImportUntrackedBanner({
    super.key,
    required this.users,
    required this.importMessage,
    required this.onShowDetails,
    required this.onDismiss,
  });

  final List<ShiftGridUntrackedUser> users;
  final String importMessage;
  final VoidCallback onShowDetails;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final uniqueCodes = users.map((u) => u.code).where((c) => c.isNotEmpty).toSet().length;
    return Card(
      color: const Color(0xFFFFF8E1),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.person_off_outlined, color: Color(0xFFE65100), size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t('grid.untrackedUsersTitle', {'n': users.length}),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.t('grid.untrackedUsersHint', {'codes': uniqueCodes}),
                    style: TextStyle(color: Colors.grey.shade800, height: 1.35),
                  ),
                  if (importMessage.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      importMessage,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FilledButton.icon(
                  onPressed: onShowDetails,
                  icon: const Icon(Icons.table_rows, size: 18),
                  label: Text(context.t('grid.untrackedUsersOpen')),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE65100),
                    foregroundColor: Colors.white,
                  ),
                ),
                TextButton(onPressed: onDismiss, child: Text(context.t('grid.untrackedUsersDismiss'))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showShiftGridUntrackedUsersPanel(
  BuildContext context, {
  required List<ShiftGridUntrackedUser> users,
  String importMessage = '',
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'untracked-users',
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, _, __) => const SizedBox.shrink(),
    transitionBuilder: (ctx, animation, _, __) {
      final slide = Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
      return Align(
        alignment: AlignmentDirectional.centerEnd,
        child: SlideTransition(
          position: slide,
          child: _UntrackedUsersSidePanel(
            users: users,
            importMessage: importMessage,
            onClose: () => Navigator.of(ctx).pop(),
          ),
        ),
      );
    },
  );
}

/// Returns accepted employee codes to create + apply, or null if user skipped.
Future<List<String>?> showShiftGridOnboardUntrackedDialog(
  BuildContext context, {
  required List<ShiftGridUntrackedUser> users,
}) {
  // Unique by code (keep first Excel row per code).
  final byCode = <String, ShiftGridUntrackedUser>{};
  for (final u in users) {
    if (u.code.isEmpty) continue;
    byCode.putIfAbsent(u.code, () => u);
  }
  final unique = byCode.values.toList();
  if (unique.isEmpty) return Future.value(const <String>[]);

  return showDialog<List<String>>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _OnboardUntrackedDialog(users: unique),
  );
}

class _OnboardUntrackedDialog extends StatefulWidget {
  const _OnboardUntrackedDialog({required this.users});

  final List<ShiftGridUntrackedUser> users;

  @override
  State<_OnboardUntrackedDialog> createState() => _OnboardUntrackedDialogState();
}

class _OnboardUntrackedDialogState extends State<_OnboardUntrackedDialog> {
  late final Set<String> _selected =
      widget.users.map((u) => u.code).where((c) => c.isNotEmpty).toSet();

  @override
  Widget build(BuildContext context) {
    final allSelected = _selected.length == widget.users.length;
    return AlertDialog(
      title: Text(context.t('grid.onboardUntrackedTitle')),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.t('grid.onboardUntrackedBody', {'n': widget.users.length}),
              style: const TextStyle(height: 1.45),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton(
                  onPressed: () => setState(() {
                    _selected
                      ..clear()
                      ..addAll(widget.users.map((u) => u.code));
                  }),
                  child: Text(context.t('grid.onboardSelectAll')),
                ),
                TextButton(
                  onPressed: () => setState(_selected.clear),
                  child: Text(context.t('grid.onboardSelectNone')),
                ),
                const Spacer(),
                Text(
                  context.t('grid.onboardSelectedCount', {
                    'n': _selected.length,
                    'total': widget.users.length,
                  }),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: Material(
                type: MaterialType.transparency,
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: widget.users.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final u = widget.users[i];
                    final checked = _selected.contains(u.code);
                    return CheckboxListTile(
                      value: checked,
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(
                        u.code,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        [
                          if (u.excelName.isNotEmpty) u.excelName,
                          if (u.excelJob.isNotEmpty) u.excelJob,
                          if (u.filledShiftCells > 0)
                            context.t('grid.onboardCellsCount', {
                              'n': u.filledShiftCells,
                            }),
                        ].join(' · '),
                        style: const TextStyle(fontSize: 12, height: 1.35),
                      ),
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _selected.add(u.code);
                        } else {
                          _selected.remove(u.code);
                        }
                      }),
                    );
                  },
                ),
              ),
            ),
            if (!allSelected && _selected.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                context.t('grid.onboardPartialHint'),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, <String>[]),
          child: Text(context.t('grid.onboardSkip')),
        ),
        FilledButton.icon(
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.pop(context, _selected.toList()),
          icon: const Icon(Icons.person_add_alt_1, size: 18),
          label: Text(context.t('grid.onboardAccept')),
        ),
      ],
    );
  }
}

class _UntrackedUsersSidePanel extends StatelessWidget {
  const _UntrackedUsersSidePanel({
    required this.users,
    required this.importMessage,
    required this.onClose,
  });

  final List<ShiftGridUntrackedUser> users;
  final String importMessage;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final panelWidth = width > 900 ? 480.0 : (width * 0.92).clamp(320.0, 480.0);

    return Material(
      elevation: 12,
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SizedBox(
        width: panelWidth,
        height: MediaQuery.sizeOf(context).height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
              color: const Color(0xFFFFF3E0),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFE65100)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.t('grid.untrackedUsersPanelTitle'),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          context.t('grid.untrackedUsersPanelSubtitle', {'n': users.length}),
                          style: TextStyle(color: Colors.grey.shade800),
                        ),
                      ],
                    ),
                  ),
                  IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: SellixCard(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.t('grid.untrackedUsersWhatHappened'),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        context.t('grid.untrackedUsersExplanation'),
                        style: TextStyle(color: Colors.grey.shade800, height: 1.4, fontSize: 13),
                      ),
                      if (importMessage.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(importMessage, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                context.t('grid.untrackedUsersTableTitle'),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minWidth: constraints.maxWidth),
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(const Color(0xFF343A40)),
                            headingTextStyle: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            dataTextStyle: const TextStyle(fontSize: 13),
                            columnSpacing: 20,
                            columns: [
                              DataColumn(label: Text(context.t('grid.untrackedColRow'))),
                              DataColumn(label: Text(context.t('grid.untrackedColCode'))),
                              DataColumn(label: Text(context.t('grid.untrackedColName'))),
                              DataColumn(label: Text(context.t('grid.untrackedColJob'))),
                              DataColumn(label: Text(context.t('grid.untrackedColCells'))),
                              DataColumn(label: Text(context.t('grid.untrackedColReason'))),
                            ],
                            rows: [
                              for (final u in users)
                                DataRow(
                                  cells: [
                                    DataCell(Text('${u.excelRow}')),
                                    DataCell(
                                      Text(
                                        u.code,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.danger,
                                        ),
                                      ),
                                    ),
                                    DataCell(Text(u.excelName.isEmpty ? '—' : u.excelName)),
                                    DataCell(Text(u.excelJob.isEmpty ? '—' : u.excelJob)),
                                    DataCell(Text('${u.filledShiftCells}')),
                                    DataCell(
                                      SizedBox(
                                        width: 180,
                                        child: Text(
                                          u.reason,
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: OutlinedButton.icon(
                onPressed: onClose,
                icon: const Icon(Icons.check),
                label: Text(context.t('grid.untrackedUsersDismiss')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
