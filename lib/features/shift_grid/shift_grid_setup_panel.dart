import 'package:flutter/material.dart';

import '../../l10n/l10n_extension.dart';
import '../../core/config/api_config.dart';
import '../../core/di/injection.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/entity_id.dart';
import '../../core/widgets/list_picker_field.dart';
import '../../core/widgets/searchable_select_field.dart';
import '../../core/widgets/sellix_card.dart';

enum ShiftGridSelectionMode { department, manual, device, location }

class ShiftGridSetupPanel extends StatefulWidget {
  const ShiftGridSetupPanel({
    super.key,
    required this.grid,
    required this.onGenerated,
  });

  final Map<String, dynamic> grid;
  final VoidCallback onGenerated;

  @override
  State<ShiftGridSetupPanel> createState() => _ShiftGridSetupPanelState();
}

class _ShiftGridSetupPanelState extends State<ShiftGridSetupPanel> {
  late ShiftGridSelectionMode _mode;
  late DateTime _from;
  late DateTime _to;
  late String _conflictAction;
  String? _deviceId;
  String? _locationId;
  List<String> _departmentIds = [];
  final Set<String> _selectedEmployeeIds = {};

  List<Map<String, dynamic>> _devices = [];
  List<Map<String, dynamic>> _locations = [];
  List<Map<String, dynamic>> _departments = [];
  List<Map<String, dynamic>> _employees = [];
  bool _loadingOptions = true;
  bool _loadingEmployees = false;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _mode = _parseMode(
      widget.grid['selectionMethod']?.toString() ?? 'location',
    );
    _from =
        DateTime.tryParse(widget.grid['dateFrom']?.toString() ?? '') ??
        DateTime.now();
    _to =
        DateTime.tryParse(widget.grid['dateTo']?.toString() ?? '') ??
        _from.add(const Duration(days: 6));
    _conflictAction = widget.grid['conflictAction']?.toString() ?? 'replace';
    _deviceId = EntityId.parse(widget.grid['deviceId']);
    _locationId = EntityId.parse(widget.grid['locationId']);
    _departmentIds =
        (widget.grid['departmentIds'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    _selectedEmployeeIds.addAll(
      (widget.grid['employeeIds'] as List?)
              ?.map((e) => e.toString())
              .where((id) => id.isNotEmpty) ??
          [],
    );
    _loadOptions();
  }

  ShiftGridSelectionMode _parseMode(String raw) {
    if (!ApiConfig.showBiotimeDeviceUi) {
      if (raw == 'device') return ShiftGridSelectionMode.location;
    }
    return switch (raw) {
      'device' => ShiftGridSelectionMode.device,
      'location' => ShiftGridSelectionMode.location,
      'department' => ShiftGridSelectionMode.department,
      'manual' => ShiftGridSelectionMode.manual,
      _ => ShiftGridSelectionMode.location,
    };
  }

  String get _modeValue => switch (_mode) {
    ShiftGridSelectionMode.device => 'device',
    ShiftGridSelectionMode.location => 'location',
    ShiftGridSelectionMode.department => 'department',
    ShiftGridSelectionMode.manual => 'manual',
  };

  Future<void> _loadOptions() async {
    setState(() => _loadingOptions = true);
    try {
      if (ApiConfig.showBiotimeDeviceUi) {
        final devices = await api.devicesList();
        if (mounted) _devices = devices;
      }
      final locations = await api.locationsList();
      final departments = await api.departmentsList();
      if (!mounted) return;
      setState(() {
        _locations = locations;
        _departments = departments;
        _loadingOptions = false;
      });
      await _loadEmployees();
    } catch (_) {
      if (mounted) setState(() => _loadingOptions = false);
    }
  }

  Future<void> _loadEmployees() async {
    setState(() => _loadingEmployees = true);
    try {
      List<Map<String, dynamic>> employees = [];
      if (_mode == ShiftGridSelectionMode.device && _deviceId != null) {
        final page = await api.employeesList(
          biotimeDeviceId: _deviceId,
          limit: 500,
        );
        employees = page.items;
      } else if (_mode == ShiftGridSelectionMode.location &&
          _locationId != null) {
        var offset = 0;
        const limit = 100;
        while (true) {
          final page = await api.employeesList(
            locationId: _locationId,
            limit: limit,
            offset: offset,
          );
          employees.addAll(page.items);
          if (!page.hasMore) break;
          offset += limit;
        }
      } else if (_mode == ShiftGridSelectionMode.department &&
          _departmentIds.isNotEmpty) {
        final page = await api.employeesList(limit: 500);
        employees = page.items
            .where(
              (e) => _departmentIds.contains(e['departmentId']?.toString()),
            )
            .toList();
      } else if (_mode == ShiftGridSelectionMode.manual) {
        final page = await api.employeesList(limit: 500);
        employees = page.items;
      }
      if (!mounted) return;
      setState(() {
        _employees = employees;
        if (_mode != ShiftGridSelectionMode.manual &&
            _selectedEmployeeIds.isEmpty) {
          _selectedEmployeeIds
            ..clear()
            ..addAll(
              employees.map((e) => EntityId.parse(e['id'])).whereType<String>(),
            );
        }
        _loadingEmployees = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingEmployees = false);
    }
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _from : _to,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _from = picked;
        if (_to.isBefore(_from)) _to = _from.add(const Duration(days: 6));
      } else {
        _to = picked;
      }
    });
  }

  void _setMode(ShiftGridSelectionMode mode) {
    setState(() => _mode = mode);
    _loadEmployees();
  }

  Future<void> _generate() async {
    if (_mode == ShiftGridSelectionMode.device && _deviceId == null) {
      _snack(context.t('shiftGrid.pickDevice'));
      return;
    }
    if (_mode == ShiftGridSelectionMode.location && _locationId == null) {
      _snack(context.t('shiftGrid.pickLocation'));
      return;
    }
    if (_mode == ShiftGridSelectionMode.department && _departmentIds.isEmpty) {
      _snack(context.t('shiftGrid.pickDepartment'));
      return;
    }
    if (_mode == ShiftGridSelectionMode.manual &&
        _selectedEmployeeIds.isEmpty) {
      _snack(context.t('shiftGrid.pickEmployee'));
      return;
    }

    setState(() => _generating = true);
    try {
      await api.shiftGridUpdate(
        widget.grid['id'],
        dateFrom: _fmt(_from),
        dateTo: _fmt(_to),
        selectionMethod: _modeValue,
        conflictAction: _conflictAction,
        deviceId: _mode == ShiftGridSelectionMode.device ? _deviceId : null,
        locationId: _mode == ShiftGridSelectionMode.location
            ? _locationId
            : null,
        departmentIds: _mode == ShiftGridSelectionMode.department
            ? _departmentIds
            : null,
        employeeIds: _selectedEmployeeIds.isNotEmpty
            ? _selectedEmployeeIds.toList()
            : null,
      );
      await api.shiftGridGenerate(
        widget.grid['id'],
        dateFrom: _fmt(_from),
        dateTo: _fmt(_to),
        conflictAction: _conflictAction,
        employeeIds: _selectedEmployeeIds.isNotEmpty
            ? _selectedEmployeeIds.toList()
            : null,
        departmentIds: _mode == ShiftGridSelectionMode.department
            ? _departmentIds
            : null,
      );
      if (mounted) widget.onGenerated();
    } catch (e) {
      if (mounted) _snack(e.toString());
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingOptions) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return SellixCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.t('grid.setup.title'),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            context.t('grid.setup.subtitle'),
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.t('grid.setup.selectionMethod'),
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          Wrap(
            spacing: 4,
            children: [
              ChoiceChip(
                label: Text(context.t('grid.setup.department')),
                selected: _mode == ShiftGridSelectionMode.department,
                onSelected: (_) => _setMode(ShiftGridSelectionMode.department),
              ),
              ChoiceChip(
                label: Text(context.t('grid.setup.manual')),
                selected: _mode == ShiftGridSelectionMode.manual,
                onSelected: (_) => _setMode(ShiftGridSelectionMode.manual),
              ),
              if (ApiConfig.showBiotimeDeviceUi)
                ChoiceChip(
                  label: Text(context.t('grid.device')),
                  selected: _mode == ShiftGridSelectionMode.device,
                  onSelected: (_) => _setMode(ShiftGridSelectionMode.device),
                ),
              ChoiceChip(
                label: Text(context.t('grid.setup.location')),
                selected: _mode == ShiftGridSelectionMode.location,
                onSelected: (_) => _setMode(ShiftGridSelectionMode.location),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (ApiConfig.showBiotimeDeviceUi &&
              _mode == ShiftGridSelectionMode.device)
            ListPickerField<String>(
              label: context.t('grid.device'),
              value: _deviceId,
              options: [
                for (final d in _devices)
                  (
                    value: EntityId.parse(d['id']) ?? '',
                    label: d['name']?.toString() ?? '',
                  ),
              ],
              onChanged: (v) {
                setState(() => _deviceId = v);
                _loadEmployees();
              },
            )
          else if (_mode == ShiftGridSelectionMode.location)
            SearchableSelectField<String>(
              label: context.t('grid.location'),
              allowNull: false,
              value: _locationId,
              options: [
                for (final l in _locations)
                  SearchableSelectOption(
                    value: EntityId.parse(l['id']) ?? '',
                    label: l['name']?.toString() ?? '',
                  ),
              ],
              onChanged: (v) {
                setState(() {
                  _locationId = v;
                  _employees = [];
                  _selectedEmployeeIds.clear();
                });
                _loadEmployees();
              },
            )
          else if (_mode == ShiftGridSelectionMode.department)
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final d in _departments)
                  FilterChip(
                    label: Text(d['name']?.toString() ?? ''),
                    selected: _departmentIds.contains(d['id']?.toString()),
                    onSelected: (sel) {
                      setState(() {
                        final id = d['id']?.toString() ?? '';
                        if (sel) {
                          _departmentIds.add(id);
                        } else {
                          _departmentIds.remove(id);
                        }
                      });
                      _loadEmployees();
                    },
                  ),
              ],
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickDate(true),
                  child: Text(
                    context.t('grid.setup.from', {'date': _fmt(_from)}),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickDate(false),
                  child: Text(context.t('grid.setup.to', {'date': _fmt(_to)})),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            context.t('grid.setup.conflictTitle'),
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          RadioListTile<String>(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(
              context.t('grid.setup.replaceExisting'),
              style: const TextStyle(fontSize: 13),
            ),
            value: 'replace',
            groupValue: _conflictAction,
            onChanged: (v) => setState(() => _conflictAction = v ?? 'replace'),
          ),
          RadioListTile<String>(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(
              context.t('grid.setup.skipAssigned'),
              style: const TextStyle(fontSize: 13),
            ),
            value: 'skip',
            groupValue: _conflictAction,
            onChanged: (v) => setState(() => _conflictAction = v ?? 'skip'),
          ),
          if (_mode == ShiftGridSelectionMode.manual ||
              _employees.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _mode == ShiftGridSelectionMode.manual
                        ? context.t('grid.setup.employees')
                        : context.t('grid.setup.preview', {
                            'n': _employees.length,
                          }),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (_mode == ShiftGridSelectionMode.manual) ...[
                  TextButton(
                    onPressed: _employees.isEmpty
                        ? null
                        : () => setState(() {
                            _selectedEmployeeIds
                              ..clear()
                              ..addAll(
                                _employees
                                    .map((e) => EntityId.parse(e['id']))
                                    .whereType<String>(),
                              );
                          }),
                    child: Text(context.t('common.all')),
                  ),
                  TextButton(
                    onPressed: () =>
                        setState(() => _selectedEmployeeIds.clear()),
                    child: Text(context.t('common.none')),
                  ),
                ],
              ],
            ),
            if (_loadingEmployees)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_employees.isEmpty)
              Text(
                _mode == ShiftGridSelectionMode.device
                    ? context.t('grid.setup.noDeviceEmployees')
                    : context.t('grid.setup.noSelectionEmployees'),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _employees.length,
                  itemBuilder: (_, i) {
                    final e = _employees[i];
                    final id = EntityId.parse(e['id']);
                    if (id == null) return const SizedBox.shrink();
                    if (_mode != ShiftGridSelectionMode.manual) {
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          e['displayName']?.toString() ??
                              e['name']?.toString() ??
                              '',
                        ),
                        subtitle: Text(e['code']?.toString() ?? ''),
                      );
                    }
                    return CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: _selectedEmployeeIds.contains(id),
                      title: Text(
                        e['displayName']?.toString() ??
                            e['name']?.toString() ??
                            '',
                      ),
                      subtitle: Text(e['code']?.toString() ?? ''),
                      onChanged: (checked) => setState(() {
                        if (checked == true) {
                          _selectedEmployeeIds.add(id);
                        } else {
                          _selectedEmployeeIds.remove(id);
                        }
                      }),
                    );
                  },
                ),
              ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _generating ? null : _generate,
            icon: _generating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.table_chart_outlined),
            label: Text(context.t('grid.setup.generate')),
          ),
        ],
      ),
    );
  }
}
