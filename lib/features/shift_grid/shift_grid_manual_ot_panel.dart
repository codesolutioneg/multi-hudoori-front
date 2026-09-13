import 'package:flutter/material.dart';

import '../../core/di/injection.dart';
import '../../core/theme/app_theme_v2.dart';
import '../../core/widgets/searchable_select_field.dart';
import '../../l10n/l10n_extension.dart';

/// Tab content: list of employee+day rows that earn manual overtime on the
/// punch report — formula (net − shift) / 9 days, only for listed pairs.
class ShiftGridManualOtPanel extends StatefulWidget {
  const ShiftGridManualOtPanel({
    super.key,
    required this.gridId,
    required this.dateFrom,
    required this.dateTo,
    required this.employees,
    this.readOnly = false,
  });

  final String gridId;
  final String dateFrom;
  final String dateTo;
  /// `{id, name, code, job}` for employees on this grid.
  final List<Map<String, String>> employees;
  final bool readOnly;

  @override
  State<ShiftGridManualOtPanel> createState() => _ShiftGridManualOtPanelState();
}

class _ShiftGridManualOtPanelState extends State<ShiftGridManualOtPanel> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _lines = [];
  String? _pickingEmployeeId;
  DateTime? _pickingDate;
  final _noteCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await api.shiftGridManualOtList(widget.gridId);
      final rows = ((r['lines'] as List?) ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      if (!mounted) return;
      setState(() {
        _lines = rows;
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

  DateTime get _minDate {
    final s = widget.dateFrom.length >= 10 ? widget.dateFrom.substring(0, 10) : widget.dateFrom;
    return DateTime.tryParse(s) ?? DateTime.now();
  }

  DateTime get _maxDate {
    final s = widget.dateTo.length >= 10 ? widget.dateTo.substring(0, 10) : widget.dateTo;
    return DateTime.tryParse(s) ?? DateTime.now();
  }

  String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _add() async {
    final empId = _pickingEmployeeId;
    final day = _pickingDate;
    if (empId == null || day == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('grid.manualOtNeedEmpDay'))),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await api.shiftGridManualOtAdd(
        widget.gridId,
        employeeId: empId,
        date: _iso(day),
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      );
      if (!mounted) return;
      _noteCtrl.clear();
      setState(() {
        _pickingEmployeeId = null;
        _pickingDate = null;
        _saving = false;
      });
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _delete(String id) async {
    try {
      await api.shiftGridManualOtDelete(widget.gridId, id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: Text(context.t('common.retry'))),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppThemeV2.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            context.t('grid.manualOtHint'),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        const SizedBox(height: 16),
        if (!widget.readOnly) ...[
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 320,
                child: SearchableSelectField<String>(
                  label: context.t('grid.manualOtEmployee'),
                  hint: context.t('grid.manualOtEmployeeSearchHint'),
                  allowNull: true,
                  allLabel: '—',
                  value: _pickingEmployeeId,
                  options: [
                    for (final e in widget.employees)
                      if ((e['id'] ?? '').isNotEmpty)
                        SearchableSelectOption(
                          value: e['id']!,
                          label: '${e['code'] ?? ''} — ${e['name'] ?? ''}',
                        ),
                  ],
                  onChanged: _saving
                      ? (_) {}
                      : (v) => setState(() => _pickingEmployeeId = v),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _saving
                    ? null
                    : () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _pickingDate ?? _minDate,
                          firstDate: _minDate,
                          lastDate: _maxDate,
                        );
                        if (picked != null) {
                          setState(() => _pickingDate = picked);
                        }
                      },
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(
                  _pickingDate == null
                      ? context.t('grid.manualOtPickDate')
                      : _iso(_pickingDate!),
                ),
              ),
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _noteCtrl,
                  enabled: !_saving,
                  decoration: InputDecoration(
                    labelText: context.t('grid.manualOtNote'),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: _saving ? null : _add,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add, size: 18),
                label: Text(context.t('grid.manualOtAdd')),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        if (_lines.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              context.t('grid.manualOtEmpty'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.black54,
                  ),
            ),
          )
        else
          Card(
            clipBehavior: Clip.antiAlias,
            child: DataTable(
              headingRowHeight: 40,
              dataRowMinHeight: 40,
              dataRowMaxHeight: 56,
              columns: [
                DataColumn(label: Text(context.t('grid.manualOtEmployee'))),
                DataColumn(label: Text(context.t('reports.column.code'))),
                DataColumn(label: Text(context.t('grid.manualOtDate'))),
                DataColumn(label: Text(context.t('grid.manualOtNote'))),
                if (!widget.readOnly)
                  const DataColumn(label: Text('')),
              ],
              rows: [
                for (final line in _lines)
                  DataRow(
                    cells: [
                      DataCell(Text(line['employeeName']?.toString() ?? '')),
                      DataCell(Text(line['employeeCode']?.toString() ?? '')),
                      DataCell(Text(line['date']?.toString() ?? '')),
                      DataCell(Text(line['note']?.toString() ?? '')),
                      if (!widget.readOnly)
                        DataCell(
                          IconButton(
                            tooltip: context.t('common.delete'),
                            icon: const Icon(Icons.delete_outline, size: 20),
                            onPressed: () => _delete(line['id']?.toString() ?? ''),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
