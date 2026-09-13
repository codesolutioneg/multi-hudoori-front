import 'package:flutter/material.dart';
import '../../l10n/l10n_extension.dart';

import '../../core/di/injection.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/utils/entity_id.dart';
import '../../core/widgets/hr_local_data_info.dart';
import '../../core/widgets/list_picker_field.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/sellix_card.dart';
import '../../core/widgets/status_tag.dart';

class ShiftAssignmentsPage extends StatefulWidget {
  const ShiftAssignmentsPage({super.key});

  @override
  State<ShiftAssignmentsPage> createState() => _ShiftAssignmentsPageState();
}

class _ShiftAssignmentsPageState extends State<ShiftAssignmentsPage> {
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _shifts = [];
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final items = await api.shiftAssignmentsList();
      final shifts = await api.shiftsList();
      if (mounted) {
        setState(() {
          _items = items;
          _shifts = shifts;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = e.toString();
        });
      }
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _typeLabel(String t) {
    switch (t) {
      case 'permanent':
        return tr('shiftAsg.type.permanent');
      case 'date_range':
        return tr('shiftAsg.type.dateRange');
      case 'weekly':
        return tr('shiftAsg.type.weekly');
      case 'weekly_period':
        return tr('shiftAsg.type.weeklyPeriod');
      default:
        return t;
    }
  }

  String _formatDate(dynamic value) {
    if (value == null || value == false) return '—';
    final text = value.toString();
    return text.length >= 10 ? text.substring(0, 10) : text;
  }

  String _assignmentSubtitle(Map<String, dynamic> a) {
    final from = _formatDate(a['dateFrom']);
    final to = _formatDate(a['dateTo']);
    final shift = a['shiftCode']?.toString().isNotEmpty == true
        ? a['shiftCode'].toString()
        : a['shiftName']?.toString() ?? '—';
    return '${_typeLabel(a['assignmentType']?.toString() ?? '')} • $shift • $from → $to';
  }

  Future<void> _openForm() async {
    if (_shifts.isEmpty) {
      _snack(context.t('shiftAsg.createShiftFirst'));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _AssignmentFormDialog(shifts: _shifts),
    );
    if (ok == true) _load();
  }

  Future<void> _deleteAssignment(Map<String, dynamic> assignment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t('shiftAsg.deleteTitle')),
        content: Text(
          context.t('shiftAsg.deleteQuestion', {
            'name': assignment['displayName'] ??
                assignment['employeeName'] ??
                context.t('shiftAsg.theEmployee'),
          }),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.t('common.cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(context.t('common.delete'))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await api.shiftAssignmentDelete(assignment['id']);
      _load();
    } catch (e) {
      _snack(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: context.t('shiftAsg.title'),
            subtitle: context.t('shiftAsg.subtitle'),
            icon: Icons.event_available_outlined,
            actions: [
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
              FilledButton.icon(
                onPressed: _openForm,
                icon: const Icon(Icons.add, size: 18),
                label: Text(context.t('shiftAsg.new')),
              ),
            ],
          ),
          const SizedBox(height: 12),
          HrLocalDataBanner(
            title: context.t('shiftAsg.localTitle'),
            hint: context.t('shiftAsg.localHint'),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_loadError != null)
            SellixCard(
              child: Column(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 40),
                  const SizedBox(height: 12),
                  Text(_loadError!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _load, child: Text(context.t('common.retry'))),
                ],
              ),
            )
          else if (_items.isEmpty)
            HrEmptyListCard(
              message: context.t('shiftAsg.empty'),
              actionLabel: context.t('shiftAsg.new'),
              onAction: _openForm,
            )
          else
            SellixCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final a in _items)
                    ListTile(
                      title: Text(
                        a['displayName']?.toString() ?? a['employeeName']?.toString() ?? '—',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(_assignmentSubtitle(a)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          StatusTag(
                            label: a['shiftCode']?.toString().isNotEmpty == true
                                ? a['shiftCode'].toString()
                                : a['shiftName']?.toString() ?? '-',
                            type: StatusTagType.info,
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _deleteAssignment(a),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _AssignmentFormDialog extends StatefulWidget {
  const _AssignmentFormDialog({required this.shifts});
  final List<Map<String, dynamic>> shifts;

  @override
  State<_AssignmentFormDialog> createState() => _AssignmentFormDialogState();
}

class _AssignmentFormDialogState extends State<_AssignmentFormDialog> {
  String? _locationId;
  String? _employeeId;
  List<Map<String, dynamic>> _locations = [];
  List<Map<String, dynamic>> _locationEmployees = [];
  String _type = 'date_range';
  String? _shiftId;
  DateTime _from = DateTime.now();
  DateTime _to = DateTime.now().add(const Duration(days: 30));
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  Future<void> _loadLocations() async {
    try {
      final locations = await api.locationsList();
      if (mounted) {
        setState(() {
          _locations = locations;
          if (locations.isNotEmpty) _locationId = EntityId.parse(locations.first['id']);
          _loading = false;
        });
        if (_locationId != null) _loadEmployees();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadEmployees() async {
    if (_locationId == null) return;
    try {
      final employees = await api.locationEmployees(_locationId!);
      if (mounted) {
        setState(() {
          _locationEmployees = employees;
          _employeeId = null;
        });
      }
    } catch (_) {}
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  List<({String value, String label})> get _shiftOptions => [
        for (final s in widget.shifts)
          (
            value: EntityId.parse(s['id']) ?? '',
            label: '${s['code'] ?? ''} — ${s['name'] ?? ''}'.trim(),
          ),
      ];

  bool get _needsShift => _type == 'permanent' || _type == 'date_range';
  bool get _needsWeekly => _type == 'weekly' || _type == 'weekly_period';

  static const _weekdays = [
    ('monday', 'settings.weekday.1'),
    ('tuesday', 'settings.weekday.2'),
    ('wednesday', 'settings.weekday.3'),
    ('thursday', 'settings.weekday.4'),
    ('friday', 'settings.weekday.5'),
    ('saturday', 'settings.weekday.6'),
    ('sunday', 'settings.weekday.0'),
  ];

  final Map<String, String?> _weeklyShiftIds = {};
  final Map<String, bool> _weeklyOff = {
    for (final d in _weekdays) d.$1: d.$1 == 'friday',
  };

  Map<String, dynamic> _weeklyBody() {
    final weekly = <String, dynamic>{};
    for (final (key, _) in _weekdays) {
      weekly[key] = {
        'shiftId': _weeklyOff[key] == true ? null : _weeklyShiftIds[key],
        'isOff': _weeklyOff[key] == true,
      };
    }
    return weekly;
  }

  Future<void> _save() async {
    if (_employeeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('shift.pickEmployeeFromResults'))),
      );
      return;
    }
    if (_needsShift && (_shiftId == null || _shiftId!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('shiftAsg.pickShift'))),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await api.shiftAssignmentCreate({
        'employeeId': _employeeId,
        'locationId': _locationId,
        'assignmentType': _type,
        if (_shiftId != null && _shiftId!.isNotEmpty) 'shiftId': _shiftId,
        'dateFrom': _fmt(_from),
        'dateTo': _fmt(_to),
        if (_needsWeekly) 'weekly': _weeklyBody(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.t('shiftAsg.newTitle')),
      content: SizedBox(
        width: 420,
        child: _loading
            ? Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListPickerField<String>(
                label: context.t('common.locationBranch'),
                value: _locationId,
                options: [
                  for (final l in _locations)
                    (value: EntityId.parse(l['id']) ?? '', label: l['name']?.toString() ?? ''),
                ],
                onChanged: (v) {
                  setState(() => _locationId = v);
                  _loadEmployees();
                },
              ),
              SizedBox(height: 12),
              ListPickerField<String>(
                label: context.t('common.employee'),
                value: _employeeId,
                options: [
                  for (final e in _locationEmployees)
                    (
                      value: EntityId.parse(e['id']) ?? '',
                      label: '${e['displayName'] ?? e['name']} (${e['code'] ?? ''})',
                    ),
                ],
                onChanged: (v) => setState(() => _employeeId = v),
              ),
              SizedBox(height: 12),
              ListPickerField<String>(
                label: context.t('shiftAsg.typeLabel'),
                value: _type,
                options: [
                  (value: 'date_range', label: context.t('shiftAsg.type.dateRangeLong')),
                  (value: 'permanent', label: context.t('shiftAsg.type.permanent')),
                  (value: 'weekly_period', label: context.t('shiftAsg.type.weeklyPeriodLong')),
                  (value: 'weekly', label: context.t('shiftAsg.type.weeklyLong')),
                ],
                onChanged: (v) => setState(() => _type = v),
              ),
              if (_needsShift) ...[
                const SizedBox(height: 12),
                ListPickerField<String>(
                  label: context.t('shiftAsg.shift'),
                  value: _shiftId,
                  options: _shiftOptions,
                  onChanged: (v) => setState(() => _shiftId = v),
                ),
              ] else if (_needsWeekly) ...[
                const SizedBox(height: 12),
                Text(
                  context.t('shiftAsg.weeklyHeader'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                for (final (key, label) in _weekdays)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        SizedBox(width: 72, child: Text(context.t(label))),
                        Checkbox(
                          value: _weeklyOff[key] ?? false,
                          onChanged: (v) => setState(() => _weeklyOff[key] = v == true),
                        ),
                        Text(context.t('shiftAsg.off'), style: const TextStyle(fontSize: 12)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _weeklyShiftIds[key],
                            decoration: InputDecoration(isDense: true, labelText: context.t('shiftAsg.shift')),
                            items: [
                              const DropdownMenuItem(value: null, child: Text('—')),
                              for (final o in _shiftOptions)
                                DropdownMenuItem(value: o.value, child: Text(o.label)),
                            ],
                            onChanged: (_weeklyOff[key] ?? false)
                                ? null
                                : (v) => setState(() => _weeklyShiftIds[key] = v),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final p = await showDatePicker(
                          context: context,
                          initialDate: _from,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (p != null) setState(() => _from = p);
                      },
                      child: Text(context.t('common.fromDate', {'date': _fmt(_from)})),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final p = await showDatePicker(
                          context: context,
                          initialDate: _to,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (p != null) setState(() => _to = p);
                      },
                      child: Text(context.t('common.toDate', {'date': _fmt(_to)})),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: Text(context.t('common.cancel'))),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(context.t('common.save')),
        ),
      ],
    );
  }
}
