import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/injection.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme_v2.dart';
import '../../l10n/l10n_extension.dart';
import 'shift_grid_helpers.dart';

/// Lists every shift grid (weekly + merged) that contains employees matching [query].
class EmployeeGridsSearchDialog extends StatefulWidget {
  const EmployeeGridsSearchDialog({super.key, required this.query});

  final String query;

  @override
  State<EmployeeGridsSearchDialog> createState() =>
      _EmployeeGridsSearchDialogState();
}

class _EmployeeGridsSearchDialogState extends State<EmployeeGridsSearchDialog> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _employees = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await api.shiftGridSearchEmployee(widget.query);
      if (!mounted) return;
      setState(() {
        _employees = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _openGrid(String id) {
    Navigator.of(context).pop();
    context.go('${AppRoutes.hrShiftGrid}/$id');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${context.t('grid.empSearch.title')} — ${widget.query}'),
      content: SizedBox(
        width: 720,
        height: 520,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(child: Text(_error!, textAlign: TextAlign.center))
            : _employees.isEmpty
            ? Center(child: Text(context.t('grid.empSearch.noEmployee')))
            : ListView(
                children: [
                  for (final emp in _employees) _buildEmployee(emp),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.t('common.close')),
        ),
      ],
    );
  }

  Widget _buildEmployee(Map<String, dynamic> emp) {
    final grids = (emp['grids'] as List? ?? [])
        .whereType<Map>()
        .map((g) => Map<String, dynamic>.from(g))
        .toList();
    final active = emp['active'] == true;
    final location = emp['locationName']?.toString() ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${emp['code'] ?? ''} — ${emp['name'] ?? ''}'
                  '${location.isNotEmpty ? '  •  $location' : ''}',
                  style: AppThemeV2.title,
                ),
              ),
              if (!active)
                Chip(
                  label: Text(context.t('grid.empSearch.archived')),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (grids.isEmpty)
            Text(
              context.t('grid.empSearch.noGrids'),
              style: AppThemeV2.caption,
            )
          else
            for (final g in grids) _buildGridRow(g),
          const Divider(height: 24),
        ],
      ),
    );
  }

  Widget _buildGridRow(Map<String, dynamic> g) {
    final id = g['id']?.toString() ?? '';
    final isMerged = g['isMerged'] == true;
    final mergedInto = g['mergedIntoName']?.toString();
    final lineCount = (g['lineCount'] as num?)?.toInt() ?? 0;
    final subtitleParts = <String>[
      formatDateRange(g['dateFrom']?.toString(), g['dateTo']?.toString()),
      if ((g['locationName']?.toString() ?? '').isNotEmpty)
        g['locationName'].toString(),
      if (lineCount > 0)
        context.t('grid.empSearch.days', {'count': lineCount}),
      if (!isMerged)
        mergedInto != null && mergedInto.isNotEmpty
            ? context.t('grid.empSearch.mergedInto', {'name': mergedInto})
            : context.t('grid.empSearch.notMerged'),
    ];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          isMerged ? Icons.merge_type_rounded : Icons.view_week_outlined,
          color: isMerged ? AppThemeV2.primary : AppThemeV2.textMuted,
        ),
        title: Text(
          '${g['name'] ?? ''}  •  ${context.t(isMerged ? 'grid.empSearch.merged' : 'grid.empSearch.weekly')}',
        ),
        subtitle: Text(subtitleParts.join('  •  ')),
        trailing: FilledButton(
          onPressed: id.isEmpty ? null : () => _openGrid(id),
          child: Text(context.t('grid.empSearch.open')),
        ),
      ),
    );
  }
}
