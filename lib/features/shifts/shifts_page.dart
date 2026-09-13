import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/injection.dart';
import '../../core/layout/app_page_scaffold.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/entity_id.dart';
import '../../core/utils/file_download.dart';
import '../../core/utils/file_pick.dart';
import '../../core/utils/shift_calculations.dart';
import '../../core/widgets/alert_banner.dart';
import '../../core/widgets/employee_search_field.dart';
import '../../core/widgets/hr_local_data_info.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/sellix_card.dart';
import '../../l10n/l10n_extension.dart';
import '../auth/auth_cubit.dart';
import 'widgets/shift_card.dart';

class ShiftsPage extends StatefulWidget {
  const ShiftsPage({super.key});

  @override
  State<ShiftsPage> createState() => _ShiftsPageState();
}

class _ShiftsPageState extends State<ShiftsPage> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await api.shiftsList();
      ShiftCalculations.sortShiftsForDisplay(items);
      if (mounted) setState(() { _items = items; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      _snack(e.toString());
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _exportExcel() async {
    try {
      final r = await api.shiftsExportXlsx();
      final base64 = r['base64']?.toString() ?? r['file']?.toString() ?? '';
      final filename = r['filename']?.toString() ?? 'shifts.xlsx';
      if (base64.isEmpty) throw Exception(context.t('common.emptyFile'));
      downloadBase64File(base64, filename, r['mimeType']?.toString() ?? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      _snack(context.t('common.downloaded', {'file': filename}));
    } catch (e) {
      _snack(e.toString());
    }
  }

  Future<void> _importExcel() async {
    try {
      final base64 = await pickExcelBase64();
      if (base64 == null || base64.isEmpty) return;
      final r = await api.shiftsImportXlsx(base64);
      final items = (r['shifts'] as List?)?.cast<Map<String, dynamic>>();
      if (items != null) {
        ShiftCalculations.sortShiftsForDisplay(items);
        setState(() => _items = items);
      } else {
        await _load();
      }
      _snack(r['message']?.toString() ?? context.t('common.imported'));
      final errors = (r['errors'] as List?) ?? [];
      if (errors.isNotEmpty) {
        _snack(context.t('common.warningList', {'items': errors.take(3).join(' — ')}));
      }
    } catch (e) {
      _snack(e.toString());
    }
  }

  Future<void> _openForm([Map<String, dynamic>? shift]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _ShiftFormDialog(shift: shift),
    );
    if (saved == true) _load();
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _items;
    return _items.where((s) {
      final name = s['name']?.toString().toLowerCase() ?? '';
      final code = s['code']?.toString().toLowerCase() ?? '';
      return name.contains(q) || code.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = context.watch<AuthCubit>().state.roles.isHrStaff;

    return AppPageScaffold(
      scrollable: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: context.t('shifts.title'),
            subtitle: canEdit
                ? context.t('shifts.subtitleManage', {'n': _items.length})
                : context.t('shifts.subtitleViewOnly', {'n': _items.length}),
            icon: Icons.schedule_outlined,
            showRefresh: !_loading,
            onRefresh: _load,
            actions: [
              if (canEdit) ...[
                OutlinedButton.icon(
                  onPressed: _exportExcel,
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: Text(context.t('shifts.exportExcel')),
                ),
                OutlinedButton.icon(
                  onPressed: _importExcel,
                  icon: const Icon(Icons.upload_file_rounded, size: 18),
                  label: Text(context.t('shifts.importExcel')),
                ),
                FilledButton.icon(
                  onPressed: () => _openForm(),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(context.t('shifts.newShift')),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          AlertBanner(
            tone: AlertBannerTone.info,
            message: context.t('shifts.infoBanner'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: context.t('shifts.searchHint'),
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? HrEmptyListCard(message: context.t('shifts.emptyHint'))
                    : _filtered.isEmpty
                        ? SellixCard(
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 32),
                                child: Text(
                                  context.t('shifts.noSearchResults'),
                                  style: const TextStyle(color: AppColors.textSecondary),
                                ),
                              ),
                            ),
                          )
                        : LayoutBuilder(
                            builder: (context, c) {
                              final cols = c.maxWidth >= 1200
                                  ? 3
                                  : (c.maxWidth >= 700 ? 2 : 1);
                              return GridView.builder(
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: cols,
                                  mainAxisSpacing: 16,
                                  crossAxisSpacing: 16,
                                  // Keep cards closer to their content height to avoid
                                  // large empty space at the bottom of simple shift cards.
                                  childAspectRatio: cols == 1 ? 2.35 : 1.9,
                                ),
                                itemCount: _filtered.length,
                                itemBuilder: (context, i) {
                                  final s = _filtered[i];
                                  return ShiftCard(
                                    shift: s,
                                    onTap: canEdit ? () => _openForm(s) : null,
                                    onDelete: canEdit
                                        ? () => _confirmDelete(s)
                                        : null,
                                  );
                                },
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(Map<String, dynamic> s) async {
    final shiftId = EntityId.parse(s['id']);
    if (shiftId == null) {
      _snack(context.t('shifts.invalidId'));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t('shifts.deleteTitle')),
        content: Text(
          context.t('shifts.deleteConfirm', {
            'name': s['name']?.toString() ?? '',
          }),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.t('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: Text(context.t('common.delete')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await api.shiftDelete(shiftId);
      _load();
    } catch (e) {
      _snack(e.toString());
    }
  }
}

class _ShiftFormDialog extends StatefulWidget {
  const _ShiftFormDialog({this.shift});
  final Map<String, dynamic>? shift;

  @override
  State<_ShiftFormDialog> createState() => _ShiftFormDialogState();
}

class _ShiftFormDialogState extends State<_ShiftFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _code = TextEditingController();
  final _start = TextEditingController(text: '8');
  final _end = TextEditingController(text: '17');
  final _breakDuration = TextEditingController(text: '0');
  final _checkInGrace = TextEditingController(text: '20');
  final _checkOutGrace = TextEditingController(text: '15');
  String _workDateReference = 'start';
  final _earlyCheckinThreshold = TextEditingController(text: '2');
  final _lateCheckoutThreshold = TextEditingController(text: '4');
  final _restDays = TextEditingController();
  bool _active = true;
  bool _assignEmployee = false;
  String? _employeeId;
  DateTime _assignFrom = DateTime.now();
  DateTime _assignTo = DateTime.now().add(const Duration(days: 30));
  bool _saving = false;

  double get _startFloat => ShiftCalculations.parseTimeToFloat(_start.text, fallback: 8);
  double get _endFloat => ShiftCalculations.parseTimeToFloat(_end.text, fallback: 17);
  double get _breakFloat => ShiftCalculations.parseTimeToFloat(_breakDuration.text, fallback: 0);
  bool get _isOvernight => ShiftCalculations.computeIsOvernight(_startFloat, _endFloat);
  double get _totalHours => ShiftCalculations.computeTotalHours(_startFloat, _endFloat, breakHours: _breakFloat);

  @override
  void initState() {
    super.initState();
    final s = widget.shift;
    if (s != null) {
      _name.text = s['name']?.toString() ?? '';
      _code.text = s['code']?.toString() ?? '';
      _start.text = '${s['startTime'] ?? 8}';
      _end.text = '${s['endTime'] ?? 17}';
      _breakDuration.text = '${s['breakDuration'] ?? 0}';
      _checkInGrace.text = '${s['gracePeriodIn'] ?? s['checkInGrace'] ?? 20}';
      _checkOutGrace.text = '${s['gracePeriodOut'] ?? s['checkOutGrace'] ?? 15}';
      _workDateReference = s['workDateReference']?.toString() ?? 'start';
      _earlyCheckinThreshold.text = '${s['earlyCheckinThreshold'] ?? 2}';
      _lateCheckoutThreshold.text = '${s['lateCheckoutThreshold'] ?? 2}';
      _restDays.text = s['restDays']?.toString() ?? '';
      _active = s['active'] != false;
    }
    for (final c in [_start, _end, _breakDuration]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _start.dispose();
    _end.dispose();
    _breakDuration.dispose();
    _checkInGrace.dispose();
    _checkOutGrace.dispose();
    _earlyCheckinThreshold.dispose();
    _lateCheckoutThreshold.dispose();
    _restDays.dispose();
    super.dispose();
  }

  String _fmt(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> _shiftBody() => {
        'name': _name.text.trim(),
        'code': _code.text.trim(),
        'startTime': _startFloat,
        'endTime': _endFloat,
        'breakDuration': _breakFloat,
        'gracePeriodIn': int.tryParse(_checkInGrace.text.trim()) ?? 20,
        'gracePeriodOut': int.tryParse(_checkOutGrace.text.trim()) ?? 15,
        'checkInGrace': int.tryParse(_checkInGrace.text.trim()) ?? 20,
        'checkOutGrace': int.tryParse(_checkOutGrace.text.trim()) ?? 15,
        'isOvernight': _isOvernight,
        'workDateReference': _workDateReference,
        'earlyCheckinThreshold': double.tryParse(_earlyCheckinThreshold.text.trim()) ?? 2,
        'lateCheckoutThreshold': double.tryParse(_lateCheckoutThreshold.text.trim()) ?? 4,
        if (_restDays.text.trim().isNotEmpty) 'restDays': _restDays.text.trim(),
        'active': _active,
      };

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_assignEmployee && _employeeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('shift.pickEmployeeFromResults'))),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      Map<String, dynamic> created;
      if (widget.shift != null) {
        created = await api.shiftUpdate(widget.shift!['id'], _shiftBody());
      } else {
        created = await api.shiftCreate(_shiftBody());
      }

      if (_assignEmployee && _employeeId != null && widget.shift == null) {
        final shiftId = EntityId.parse(created['id'] ?? created['shift']?['id']);
        if (shiftId != null) {
          await api.shiftAssignmentCreate({
            'employeeId': _employeeId,
            'shiftId': shiftId,
            'assignmentType': 'date_range',
            'dateFrom': _fmt(_assignFrom),
            'dateTo': _fmt(_assignTo),
          });
        }
      }

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
    final isNew = widget.shift == null;

    return AlertDialog(
      title: Text(isNew ? context.t('shift.new') : context.t('shift.edit')),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _name,
                  decoration: InputDecoration(labelText: context.t('shift.name')),
                  validator: (v) => (v?.trim().isEmpty ?? true) ? context.t('common.required') : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _code,
                  decoration: InputDecoration(labelText: context.t('shift.code')),
                  validator: (v) => (v?.trim().isEmpty ?? true) ? context.t('common.required') : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _start,
                        decoration: InputDecoration(
                          labelText: context.t('shift.startHours'),
                          hintText: context.t('shift.startHoursHint'),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) => ShiftCalculations.validateTimes(_startFloat, _endFloat),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _end,
                        decoration: InputDecoration(
                          labelText: context.t('shift.endHours'),
                          hintText: context.t('shift.endHoursHint'),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SellixCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.t('shift.preview', {'from': ShiftCalculations.floatToDisplay(_startFloat), 'to': ShiftCalculations.floatToDisplay(_endFloat)}),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(context.t('shift.totalHours', {'hours': _totalHours})),
                      Text(_isOvernight ? context.t('shift.overnight') : context.t('shift.dayShift')),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _breakDuration,
                  decoration: InputDecoration(labelText: context.t('shift.breakHours')),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _checkInGrace,
                        decoration: InputDecoration(labelText: context.t('shift.lateGrace')),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _checkOutGrace,
                        decoration: InputDecoration(labelText: context.t('shift.earlyLeaveGrace')),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _workDateReference,
                  decoration: InputDecoration(labelText: context.t('shift.workDateBasis')),
                  items: [
                    DropdownMenuItem(value: 'start', child: Text(context.t('shift.workDateStart'))),
                    DropdownMenuItem(value: 'end', child: Text(context.t('shift.workDateEnd'))),
                  ],
                  onChanged: (v) => setState(() => _workDateReference = v ?? 'start'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _earlyCheckinThreshold,
                        decoration: InputDecoration(labelText: context.t('shift.earlyPunchLimit')),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _lateCheckoutThreshold,
                        decoration: InputDecoration(labelText: context.t('shift.latePunchLimit')),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _restDays,
                  decoration: InputDecoration(
                    labelText: context.t('shift.restDays'),
                    hintText: context.t('shift.restDaysHint'),
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: _active,
                  onChanged: (v) => setState(() => _active = v),
                  title: Text(context.t('common.active'), style: TextStyle(fontSize: 14)),
                  contentPadding: EdgeInsets.zero,
                ),
                if (isNew) ...[
                  const Divider(height: 24),
                  SwitchListTile(
                    value: _assignEmployee,
                    onChanged: (v) => setState(() => _assignEmployee = v),
                    title: Text(context.t('shift.assignAfterSave'), style: TextStyle(fontSize: 14)),
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (_assignEmployee) ...[
                    EmployeeSearchField(onSelected: (id, _) => setState(() => _employeeId = id)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final p = await showDatePicker(
                                context: context,
                                initialDate: _assignFrom,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2035),
                              );
                              if (p != null) setState(() => _assignFrom = p);
                            },
                            child: Text(context.t('common.fromDate', {'date': _fmt(_assignFrom)})),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final p = await showDatePicker(
                                context: context,
                                initialDate: _assignTo,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2035),
                              );
                              if (p != null) setState(() => _assignTo = p);
                            },
                            child: Text(context.t('common.toDate', {'date': _fmt(_assignTo)})),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ],
            ),
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
