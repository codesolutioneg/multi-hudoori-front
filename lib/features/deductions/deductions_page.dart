import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/injection.dart';
import '../../core/layout/app_page_scaffold.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/file_download.dart';
import '../../core/utils/file_pick.dart';
import '../../core/utils/money_format.dart';
import '../../core/utils/payroll_month.dart';
import '../../core/widgets/employee_search_field.dart';
import '../../core/widgets/hr_local_data_info.dart';
import '../../core/widgets/list_picker_field.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/sellix_card.dart';
import '../../core/widgets/status_tag.dart';
import '../../l10n/l10n_extension.dart';
import 'deduction_import_skipped_panel.dart';
import 'deductions_wizard_dialog.dart';

String _fmtDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _locationLabel(Map<String, dynamic> d) {
  final loc = d['locationName']?.toString().trim();
  if (loc != null && loc.isNotEmpty) return loc;
  return d['name']?.toString() ?? d['alias']?.toString() ?? '';
}

class DeductionsPage extends StatefulWidget {
  const DeductionsPage({super.key});

  @override
  State<DeductionsPage> createState() => _DeductionsPageState();
}

class _DeductionsPageState extends State<DeductionsPage> {
  static const _listLimit = 2000;

  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _types = [];
  List<Map<String, dynamic>> _devices = [];
  bool _loading = true;
  int _total = 0;
  String? _stateFilter;
  String? _locationFilter;
  String? _typeFilter;
  final _searchController = TextEditingController();
  String? _importMessage;
  List<Map<String, dynamic>> _importSkipped = [];
  int _payrollMonthStartDay = 26;

  Map<String, String> get _typeLabels => {
        for (final t in _types) t['value']?.toString() ?? '': t['label']?.toString() ?? '',
      };

  List<String> get _locationOptions {
    final values = _items
        .map((item) => item['locationName']?.toString().trim() ?? '')
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return values;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filteredItems() {
    final query = _searchController.text.trim().toLowerCase();
    return _items.where((item) {
      if (_locationFilter != null &&
          item['locationName']?.toString() != _locationFilter) {
        return false;
      }
      if (_typeFilter != null &&
          item['deductionType']?.toString() != _typeFilter) {
        return false;
      }
      if (query.isNotEmpty) {
        final haystack = [
          item['employeeName'],
          item['employeeCode'],
          item['reference'],
        ].map((v) => v?.toString().toLowerCase() ?? '').join(' ');
        if (!haystack.contains(query)) return false;
      }
      return true;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final types = await api.deductionTypes();
      final devices = await api.devicesList();
      var startDay = 26;
      try {
        final config = await api.configGet();
        startDay = (config['payrollMonthStartDay'] as num?)?.toInt() ?? 26;
      } catch (_) {}
      if (mounted) {
        setState(() {
          _types = types;
          _devices = devices;
          _payrollMonthStartDay = startDay;
        });
      }
    } catch (_) {}
    await _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final page = await api.deductionsListPage(
        state: _stateFilter,
        type: _typeFilter,
        limit: _listLimit,
      );
      if (mounted) {
        setState(() {
          _items = page.items;
          _total = page.total;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  StatusTagType _tag(String s) {
    if (s == 'applied') return StatusTagType.success;
    if (s == 'cancelled') return StatusTagType.danger;
    return StatusTagType.warning;
  }

  String _stateAr(String s) {
    switch (s) {
      case 'pending':
        return context.t('ded.state.pending');
      case 'applied':
        return context.t('ded.state.applied');
      case 'cancelled':
        return context.t('ded.state.cancelled');
      default:
        return s;
    }
  }

  String _typeLabel(String code) => _typeLabels[code] ?? code;

  Future<void> _add() async {
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _DeductionFormDialog(types: _types, devices: _devices),
    );
    if (ok == true) _load();
  }

  Future<void> _openWizard() async {
    try {
      final locations = await api.locationsList();
      if (!mounted) return;
      if (locations.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('ded.noLocations'))),
        );
        return;
      }
      final refreshed = await showDialog<bool>(
        context: context,
        builder: (_) => DeductionsWizardDialog(
          types: _types,
          locations: locations,
        ),
      );
      if (refreshed == true) await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _exportTemplate({required bool multi}) async {
    final cfg = await showDialog<_ExcelDialogResult>(
      context: context,
      builder: (_) => _ExcelConfigDialog(types: _types, devices: _devices, multi: multi),
    );
    if (cfg == null) return;
    try {
      final result = multi
          ? await api.deductionExportMultiTemplate(deviceId: cfg.deviceId, date: cfg.date)
          : await api.deductionExportTemplate(
              deductionType: cfg.deductionType!,
              deviceId: cfg.deviceId,
              date: cfg.date,
            );
      final base64 = result['base64']?.toString() ?? '';
      final filename = result['filename']?.toString() ?? 'deduction_template.xlsx';
      if (base64.isEmpty) throw Exception(context.t('common.emptyFile'));
      downloadBase64File(base64, filename, result['mimeType']?.toString() ?? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.t('common.downloaded', {'file': filename}))));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _importExcel({required bool multi}) async {
    final cfg = await showDialog<_ExcelDialogResult>(
      context: context,
      builder: (_) => _ExcelConfigDialog(types: _types, devices: _devices, multi: multi, importMode: true),
    );
    if (cfg == null) return;
    try {
      final base64 = await pickExcelBase64();
      if (base64 == null || base64.isEmpty) return;
      final result = multi
          ? await api.deductionImportMultiXlsx(base64: base64, deviceId: cfg.deviceId, date: cfg.date)
          : await api.deductionImportXlsx(
              base64: base64,
              deductionType: cfg.deductionType!,
              deviceId: cfg.deviceId,
              date: cfg.date,
            );
      final skipped = ((result['skipped'] as List?) ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      setState(() {
        _importMessage = result['message']?.toString() ?? context.t('common.imported');
        _importSkipped = skipped;
      });
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message']?.toString() ?? context.t('common.imported'))),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _cancel(Map<String, dynamic> d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t('ded.cancelDeduction')),
        content: Text(context.t('ded.cancelQuestion', {'name': d['employeeName'], 'amount': formatMoney(d['amount'])})),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.t('common.no'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(context.t('ded.cancelDeduction'))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await api.deductionCancel(d['id']);
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  void _showDeductionDetail(Map<String, dynamic> d) async {
    final state = d['state']?.toString() ?? '';
    final payrollId = d['payrollId']?.toString();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.paddingOf(ctx).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.t('ded.details'),
              style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (state == 'pending') ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  context.t('ded.pendingNote'),
                  style: TextStyle(fontSize: 13, height: 1.4),
                ),
              ),
              const SizedBox(height: 12),
            ],
            _deductionDetailRow(context.t('common.employee'), d['employeeName']?.toString() ?? '—'),
            _deductionDetailCopyRow(
              context,
              context.t('ded.employeeCode'),
              d['employeeCode']?.toString() ?? '',
            ),
            if ((d['reference']?.toString() ?? '').isNotEmpty)
              _deductionDetailRow(context.t('ded.reference'), d['reference']?.toString() ?? ''),
            _deductionDetailRow(context.t('common.status'), _stateAr(state)),
            _deductionDetailRow(context.t('ded.type'), d['deductionTypeLabel']?.toString() ?? _typeLabel(d['deductionType']?.toString() ?? '')),
            _deductionDetailRow(context.t('ded.amount'), _deductionMoney(d['amount'] as num?)),
            if ((d['appliedAmount'] as num?) != null && (d['appliedAmount'] as num?)! > 0)
              _deductionDetailRow(context.t('ded.applied'), _deductionMoney(d['appliedAmount'] as num?)),
            _deductionDetailRow(context.t('common.date'), d['date']?.toString() ?? '—'),
            _deductionDetailRow(
              context.t('ded.branch'),
              d['locationName']?.toString() ?? d['deviceName']?.toString() ?? '—',
            ),
            if (d['notes'] != null && d['notes'].toString().trim().isNotEmpty)
              _deductionDetailRow(context.t('ded.notes'), d['notes'].toString()),
            if (payrollId != null && payrollId.isNotEmpty)
              _deductionDetailRow(context.t('ded.payroll'), payrollId),
            const SizedBox(height: 16),
            Row(
              children: [
                if (state == 'pending')
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _cancel(d);
                      },
                      icon: const Icon(Icons.cancel_outlined, color: AppColors.danger, size: 18),
                      label: Text(context.t('ded.cancelDeduction')),
                    ),
                  ),
                if (state == 'pending' && payrollId != null && payrollId.isNotEmpty)
                  const SizedBox(width: 8),
                if (payrollId != null && payrollId.isNotEmpty)
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        context.go('${AppRoutes.hrPayroll}/$payrollId');
                      },
                      icon: const Icon(Icons.receipt_long_outlined, size: 18),
                      label: Text(context.t('ded.openPayroll')),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _deductionDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _deductionDetailCopyRow(BuildContext context, String label, String value) {
    final code = value.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
          Expanded(
            child: SelectableText(
              code.isEmpty ? '—' : code,
              style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.4),
            ),
          ),
          if (code.isNotEmpty)
            IconButton(
              tooltip: context.t('ded.copyCode'),
              icon: const Icon(Icons.copy_outlined, size: 18),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: code));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.t('ded.codeCopied', {'code': code}))),
                  );
                }
              },
            ),
        ],
      ),
    );
  }

  String _deductionMoney(num? v) => formatMoney(v ?? 0);

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredItems();
    final locations = _locationOptions;

    return AppPageScaffold(
      scrollable: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: context.t('deductions.title'),
            subtitle: _total > 0
                ? context.t('deductions.subtitleCount', {'n': _total})
                : context.t('deductions.subtitleLocal'),
            icon: Icons.remove_circle_outline_rounded,
            actions: [
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
              OutlinedButton.icon(
                onPressed: _openWizard,
                icon: const Icon(Icons.table_view_outlined, size: 18),
                label: Text(context.t('ded.excelWizard')),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  switch (v) {
                    case 'wizard':
                      _openWizard();
                    case 'export':
                      _exportTemplate(multi: false);
                    case 'export_multi':
                      _exportTemplate(multi: true);
                    case 'import':
                      _importExcel(multi: false);
                    case 'import_multi':
                      _importExcel(multi: true);
                    case 'loan':
                      context.push(AppRoutes.hrAdvanceLoanImport);
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'wizard', child: Text(context.t('ded.menu.wizard'))),
                  PopupMenuItem(value: 'export', child: Text(context.t('ded.menu.exportSingle'))),
                  PopupMenuItem(value: 'export_multi', child: Text(context.t('ded.menu.exportMulti'))),
                  PopupMenuItem(value: 'import', child: Text(context.t('ded.menu.importSingle'))),
                  PopupMenuItem(value: 'import_multi', child: Text(context.t('ded.menu.importMulti'))),
                  PopupMenuItem(value: 'loan', child: Text(context.t('ded.menu.importLoans'))),
                ],
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.more_vert),
                ),
              ),
              FilledButton.icon(
                onPressed: _add,
                icon: const Icon(Icons.add, size: 18),
                label: Text(context.t('deductions.new')),
              ),
            ],
          ),
          HrLocalDataBanner(
            title: context.t('ded.localTitle'),
            hint: context.t('ded.localHint'),
          ),
          if (_importSkipped.isNotEmpty) ...[
            const SizedBox(height: 12),
            DeductionImportSkippedPanel(
              message: _importMessage ?? '',
              skipped: _importSkipped,
              onClose: () => setState(() {
                _importSkipped = [];
                _importMessage = null;
              }),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: context.t('grid.searchNameOrCode'),
              prefixIcon: Icon(Icons.search, size: 20),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: Text(context.t('common.all')),
                selected: _stateFilter == null,
                onSelected: (_) {
                  setState(() => _stateFilter = null);
                  _load();
                },
              ),
              FilterChip(
                label: Text(context.t('ded.state.pending')),
                selected: _stateFilter == 'pending',
                onSelected: (_) {
                  setState(() => _stateFilter = 'pending');
                  _load();
                },
              ),
              FilterChip(
                label: Text(context.t('ded.state.applied')),
                selected: _stateFilter == 'applied',
                onSelected: (_) {
                  setState(() => _stateFilter = 'applied');
                  _load();
                },
              ),
              if (locations.isNotEmpty)
                SizedBox(
                  width: 210,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('deduction-location-$_locationFilter'),
                    initialValue: _locationFilter,
                    decoration: InputDecoration(labelText: context.t('ded.branch')),
                    items: [
                      DropdownMenuItem(value: null, child: Text(context.t('common.all'))),
                      for (final location in locations)
                        DropdownMenuItem(value: location, child: Text(location)),
                    ],
                    onChanged: (value) => setState(() => _locationFilter = value),
                  ),
                ),
              if (_types.isNotEmpty)
                DropdownMenu<String?>(
                  initialSelection: _typeFilter,
                  label: Text(context.t('ded.typeFilter')),
                  dropdownMenuEntries: [
                    DropdownMenuEntry(value: null, label: context.t('ded.allTypes')),
                    for (final t in _types)
                      DropdownMenuEntry(
                        value: t['value']?.toString(),
                        label: t['label']?.toString() ?? '',
                      ),
                  ],
                  onSelected: (v) {
                    setState(() => _typeFilter = v);
                    _load();
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? HrEmptyListCard(
                        message: context.t('deductions.emptyList'),
                        actionLabel: context.t('deductions.new'),
                        onAction: _add,
                      )
                    : _DeductionGroupedList(
                        items: filtered,
                        payrollMonthStartDay: _payrollMonthStartDay,
                        typeLabel: _typeLabel,
                        stateAr: _stateAr,
                        stateTag: _tag,
                        onTapItem: _showDeductionDetail,
                        onAdd: _add,
                        emptyActionLabel: context.t('deductions.new'),
                      ),
          ),
        ],
      ),
    );
  }
}

class _DeductionGroupedList extends StatefulWidget {
  const _DeductionGroupedList({
    required this.items,
    required this.payrollMonthStartDay,
    required this.typeLabel,
    required this.stateAr,
    required this.stateTag,
    required this.onTapItem,
    required this.onAdd,
    required this.emptyActionLabel,
  });

  final List<Map<String, dynamic>> items;
  final int payrollMonthStartDay;
  final String Function(String) typeLabel;
  final String Function(String) stateAr;
  final StatusTagType Function(String) stateTag;
  final void Function(Map<String, dynamic>) onTapItem;
  final VoidCallback onAdd;
  final String emptyActionLabel;

  @override
  State<_DeductionGroupedList> createState() => _DeductionGroupedListState();
}

class _DeductionGroupedListState extends State<_DeductionGroupedList> {
  final Set<String> _expandedPeriods = {};
  final Set<String> _expandedBranches = {};

  Map<String, Map<String, List<Map<String, dynamic>>>> _tree() {
    final tree = <String, Map<String, List<Map<String, dynamic>>>>{};
    for (final item in widget.items) {
      final date = parseIsoDate(item['date']?.toString()) ?? DateTime.now();
      final range = payrollMonthRange(date, widget.payrollMonthStartDay);
      final periodKey =
          '${formatIsoDate(range.dateFrom)}|${formatIsoDate(range.dateTo)}';
      final branch = item['locationName']?.toString().trim();
      final branchKey =
          (branch != null && branch.isNotEmpty) ? branch : context.t('shiftGrid.unknownBranch');
      tree.putIfAbsent(periodKey, () => {});
      tree[periodKey]!.putIfAbsent(branchKey, () => []).add(item);
    }
    return tree;
  }

  String _branchKey(String periodKey, String branch) => '$periodKey|$branch';

  bool _isCancelled(Map<String, dynamic> item) =>
      item['state']?.toString() == 'cancelled';

  /// Totals / chips ignore cancelled rows (still listed under the branch).
  List<Map<String, dynamic>> _activeItems(List<Map<String, dynamic>> items) =>
      items.where((item) => !_isCancelled(item)).toList();

  double _sumAmount(List<Map<String, dynamic>> items) =>
      _activeItems(items).fold<double>(
        0,
        (sum, item) => sum + ((item['amount'] as num?)?.toDouble() ?? 0),
      );

  List<({String code, String label, int count, double amount})> _typeTotals(
    List<Map<String, dynamic>> items,
  ) {
    final byType = <String, ({int count, double amount})>{};
    for (final item in _activeItems(items)) {
      final code = item['deductionType']?.toString().trim() ?? '';
      final key = code.isEmpty ? '_' : code;
      final prev = byType[key] ?? (count: 0, amount: 0);
      byType[key] = (
        count: prev.count + 1,
        amount: prev.amount + ((item['amount'] as num?)?.toDouble() ?? 0),
      );
    }
    final rows = byType.entries
        .map(
          (e) => (
            code: e.key,
            label: e.key == '_'
                ? context.t('ded.noType')
                : widget.typeLabel(e.key),
            count: e.value.count,
            amount: e.value.amount,
          ),
        )
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
    return rows;
  }

  Widget _periodTypeBreakdown(List<Map<String, dynamic>> periodItems) {
    final rows = _typeTotals(periodItems);
    if (rows.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final row in rows)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.18),
                ),
              ),
              child: Text(
                '${row.label}  •  ${row.count}  •  ${formatMoney(row.amount)}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }

  void _expandAll() {
    final tree = _tree();
    setState(() {
      _expandedPeriods
        ..clear()
        ..addAll(tree.keys);
      _expandedBranches
        ..clear()
        ..addAll([
          for (final period in tree.entries)
            for (final branch in period.value.keys)
              _branchKey(period.key, branch),
        ]);
    });
  }

  void _collapseAll() {
    setState(() {
      _expandedPeriods.clear();
      _expandedBranches.clear();
    });
  }

  void _togglePeriod(String periodKey) {
    setState(() {
      if (_expandedPeriods.contains(periodKey)) {
        _expandedPeriods.remove(periodKey);
        _expandedBranches.removeWhere((k) => k.startsWith('$periodKey|'));
      } else {
        _expandedPeriods.add(periodKey);
      }
    });
  }

  void _toggleBranch(String periodKey, String branch) {
    final key = _branchKey(periodKey, branch);
    setState(() {
      if (!_expandedPeriods.contains(periodKey)) {
        _expandedPeriods.add(periodKey);
      }
      if (_expandedBranches.contains(key)) {
        _expandedBranches.remove(key);
      } else {
        _expandedBranches.add(key);
      }
    });
  }

  Widget _collapseHeader({
    required bool expanded,
    required VoidCallback onTap,
    required IconData leadingIcon,
    required String title,
    required String subtitle,
    double indent = 0,
  }) {
    return Material(
      color: AppColors.muted.withValues(alpha: indent > 0 ? 0.25 : 0.45),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(12 + indent, 10, 12, 10),
          child: Row(
            children: [
              Icon(
                expanded ? Icons.expand_less : Icons.expand_more,
                size: 22,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Icon(leadingIcon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: indent > 0 ? FontWeight.w700 : FontWeight.w800,
                        fontSize: indent > 0 ? 14 : 15,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _employeeTile(Map<String, dynamic> d) {
    final ref = d['reference']?.toString();
    return ListTile(
      dense: true,
      onTap: () => widget.onTapItem(d),
      title: Text(
        d['employeeName']?.toString() ?? '—',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        [
          if ((d['employeeCode']?.toString() ?? '').isNotEmpty)
            context.t('common.codeValue', {'code': d['employeeCode']}),
          if (ref != null && ref.isNotEmpty) ref,
          d['deductionTypeLabel'] ??
              widget.typeLabel(d['deductionType']?.toString() ?? ''),
        ].where((s) => s.toString().isNotEmpty).join('  •  '),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatMoney(d['amount']),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 8),
          StatusTag(
            label: widget.stateAr(d['state']?.toString() ?? ''),
            type: widget.stateTag(d['state']?.toString() ?? ''),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return HrEmptyListCard(
        message: context.t('ded.noMatches'),
        actionLabel: widget.emptyActionLabel,
        onAction: widget.onAdd,
      );
    }

    final tree = _tree();
    final periodKeys = tree.keys.toList()..sort((a, b) => b.compareTo(a));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 4,
            children: [
              TextButton.icon(
                onPressed: _expandAll,
                icon: const Icon(Icons.unfold_more, size: 18),
                label: Text(context.t('common.expandAll')),
              ),
              TextButton.icon(
                onPressed: _collapseAll,
                icon: const Icon(Icons.unfold_less, size: 18),
                label: Text(context.t('common.collapseAll')),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: SellixCard(
            padding: EdgeInsets.zero,
            child: ListView(
              children: [
                for (final periodKey in periodKeys) ...[
                  () {
                    final branches = tree[periodKey]!;
                    final periodItems =
                        branches.values.expand((list) => list).toList();
                    final periodActive = _activeItems(periodItems);
                    final parts = periodKey.split('|');
                    final from = parts.first;
                    final to = parts.length > 1 ? parts[1] : parts.first;
                    final periodExpanded = _expandedPeriods.contains(periodKey);
                    final branchKeys = branches.keys.toList()..sort();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _collapseHeader(
                          expanded: periodExpanded,
                          onTap: () => _togglePeriod(periodKey),
                          leadingIcon: Icons.date_range_outlined,
                          title: context.t('ded.cycle', {'from': from, 'to': to}),
                          subtitle:
                              context.t('ded.periodSummary', {'count': periodActive.length, 'amount': formatMoney(_sumAmount(periodItems)), 'branches': branchKeys.length}),
                        ),
                        if (periodExpanded) ...[
                          _periodTypeBreakdown(periodItems),
                          for (final branch in branchKeys) ...[
                            () {
                              final branchItems = branches[branch]!;
                              final branchActive = _activeItems(branchItems);
                              final cancelledN =
                                  branchItems.length - branchActive.length;
                              final branchExpanded = _expandedBranches.contains(
                                _branchKey(periodKey, branch),
                              );
                              final branchSub = cancelledN > 0
                                  ? context.t('ded.branchSummaryCancelled', {'count': branchActive.length, 'amount': formatMoney(_sumAmount(branchItems)), 'cancelled': cancelledN})
                                  : context.t('ded.branchSummary', {'count': branchActive.length, 'amount': formatMoney(_sumAmount(branchItems))});
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _collapseHeader(
                                    expanded: branchExpanded,
                                    onTap: () => _toggleBranch(periodKey, branch),
                                    leadingIcon: Icons.storefront_outlined,
                                    title: branch,
                                    subtitle: branchSub,
                                    indent: 16,
                                  ),
                                  if (branchExpanded)
                                    for (final item in branchItems) _employeeTile(item),
                                ],
                              );
                            }(),
                          ],
                        ],
                        const Divider(height: 1),
                      ],
                    );
                  }(),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DeductionFormDialog extends StatefulWidget {
  const _DeductionFormDialog({required this.types, required this.devices});
  final List<Map<String, dynamic>> types;
  final List<Map<String, dynamic>> devices;

  @override
  State<_DeductionFormDialog> createState() => _DeductionFormDialogState();
}

class _DeductionFormDialogState extends State<_DeductionFormDialog> {
  String? _employeeId;
  late String _type;
  String? _deviceId;
  final _amount = TextEditingController();
  final _note = TextEditingController();
  final _dateCtrl = TextEditingController(text: _fmtDate(DateTime.now()));
  bool _saving = false;

  List<({String value, String label})> get _typeOptions => [
        for (final t in widget.types)
          (value: t['value']?.toString() ?? '', label: t['label']?.toString() ?? ''),
      ];

  List<({String value, String label})> get _locationOptions => [
        (value: '', label: context.t('shiftGrid.allLocations')),
        for (final d in widget.devices)
          (
            value: d['id']?.toString() ?? '',
            label: _locationLabel(d),
          ),
      ];

  @override
  void initState() {
    super.initState();
    _type = widget.types.isNotEmpty ? widget.types.first['value']?.toString() ?? 'manual_debit' : 'manual_debit';
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    _dateCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final initial = DateTime.tryParse(_dateCtrl.text.trim()) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) _dateCtrl.text = _fmtDate(picked);
  }

  Future<void> _save() async {
    if (_employeeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('shift.pickEmployeeFromResults'))),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await api.deductionCreate({
        'employeeId': _employeeId,
        'type': _type,
        'amount': parseMoney(_amount.text) ?? 0,
        'notes': _note.text.trim(),
        'date': _dateCtrl.text.trim(),
        if (_deviceId != null && _deviceId!.isNotEmpty) 'deviceId': _deviceId,
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
      title: Text(context.t('ded.new')),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              EmployeeSearchField(onSelected: (id, _) => setState(() => _employeeId = id)),
              const SizedBox(height: 12),
              ListPickerField<String>(
                label: context.t('ded.typeFilter'),
                value: _type,
                options: _typeOptions,
                onChanged: (v) => setState(() => _type = v),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _dateCtrl,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: context.t('ded.date'),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_today_outlined),
                    onPressed: _pickDate,
                  ),
                ),
                onTap: _pickDate,
              ),
              const SizedBox(height: 8),
              if (_locationOptions.length > 1)
                ListPickerField<String>(
                  label: context.t('shiftGrid.location'),
                  value: _deviceId ?? '',
                  options: _locationOptions,
                  onChanged: (v) => setState(() => _deviceId = v.isEmpty ? null : v),
                ),
              const SizedBox(height: 8),
              TextField(
                controller: _amount,
                decoration: InputDecoration(labelText: context.t('ded.amount')),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 8),
              TextField(controller: _note, decoration: InputDecoration(labelText: context.t('ded.notes'))),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(context.t('common.cancel'))),
        FilledButton(onPressed: _saving ? null : _save, child: Text(context.t('common.save'))),
      ],
    );
  }
}

class _ExcelDialogResult {
  _ExcelDialogResult({this.deductionType, this.deviceId, this.date});
  final String? deductionType;
  final String? deviceId;
  final String? date;
}

class _ExcelConfigDialog extends StatefulWidget {
  const _ExcelConfigDialog({
    required this.types,
    required this.devices,
    required this.multi,
    this.importMode = false,
  });

  final List<Map<String, dynamic>> types;
  final List<Map<String, dynamic>> devices;
  final bool multi;
  final bool importMode;

  @override
  State<_ExcelConfigDialog> createState() => _ExcelConfigDialogState();
}

class _ExcelConfigDialogState extends State<_ExcelConfigDialog> {
  late String _type;
  String? _deviceId;
  final _dateCtrl = TextEditingController(text: _fmtDate(DateTime.now()));

  @override
  void initState() {
    super.initState();
    _type = widget.types.isNotEmpty ? widget.types.first['value']?.toString() ?? 'manual_debit' : 'manual_debit';
  }

  @override
  void dispose() {
    _dateCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final initial = DateTime.tryParse(_dateCtrl.text.trim()) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) _dateCtrl.text = _fmtDate(picked);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.importMode
        ? (widget.multi ? context.t('ded.importMultiTitle') : context.t('ded.importTitle'))
        : (widget.multi ? context.t('ded.exportMultiTitle') : context.t('ded.exportTitle'));

    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!widget.multi && widget.types.isNotEmpty)
              ListPickerField<String>(
                label: context.t('ded.typeFilter'),
                value: _type,
                options: [
                  for (final t in widget.types)
                    (value: t['value']?.toString() ?? '', label: t['label']?.toString() ?? ''),
                ],
                onChanged: (v) => setState(() => _type = v),
              ),
            if (!widget.multi) const SizedBox(height: 8),
            if (widget.devices.isNotEmpty)
              ListPickerField<String>(
                label: context.t('shiftGrid.location'),
                value: _deviceId ?? '',
                options: [
                  (value: '', label: context.t('shiftGrid.allLocations')),
                  for (final d in widget.devices)
                    (
                      value: d['id']?.toString() ?? '',
                      label: _locationLabel(d),
                    ),
                ],
                onChanged: (v) => setState(() => _deviceId = v.isEmpty ? null : v),
              ),
            const SizedBox(height: 8),
            TextField(
              controller: _dateCtrl,
              readOnly: true,
              decoration: InputDecoration(
                labelText: context.t('ded.deductionsDate'),
                suffixIcon: IconButton(icon: Icon(Icons.calendar_today_outlined), onPressed: _pickDate),
              ),
              onTap: _pickDate,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(context.t('common.cancel'))),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            _ExcelDialogResult(
              deductionType: widget.multi ? null : _type,
              deviceId: _deviceId,
              date: _dateCtrl.text.trim(),
            ),
          ),
          child: Text(widget.importMode ? context.t('common.continue') : context.t('common.export')),
        ),
      ],
    );
  }
}

class _DeductionImportPreviewDialog extends StatefulWidget {
  const _DeductionImportPreviewDialog({required this.lines});
  final List<Map<String, dynamic>> lines;

  @override
  State<_DeductionImportPreviewDialog> createState() => _DeductionImportPreviewDialogState();
}

class _DeductionImportPreviewDialogState extends State<_DeductionImportPreviewDialog> {
  late final List<Map<String, dynamic>> _lines;

  @override
  void initState() {
    super.initState();
    _lines = widget.lines.map((e) {
      final m = Map<String, dynamic>.from(e);
      m['selected'] = m['ok'] == true;
      return m;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final okCount = _lines.where((l) => l['ok'] == true && l['selected'] == true).length;
    return AlertDialog(
      title: Text(context.t('ded.previewTitle')),
      content: SizedBox(
        width: 680,
        height: 440,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.t('ded.previewHint', {'count': okCount}),
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: DataTable(
                    columns: [
                      DataColumn(label: Text(context.t('ded.approve'))),
                      DataColumn(label: Text(context.t('common.code'))),
                      DataColumn(label: Text(context.t('common.name'))),
                      DataColumn(label: Text(context.t('ded.type'))),
                      DataColumn(label: Text(context.t('ded.amount'))),
                      DataColumn(label: Text(context.t('common.status'))),
                    ],
                    rows: [
                      for (var i = 0; i < _lines.length; i++)
                        DataRow(
                          cells: [
                            DataCell(
                              Checkbox(
                                value: _lines[i]['ok'] == true && _lines[i]['selected'] == true,
                                onChanged: _lines[i]['ok'] == true
                                    ? (v) => setState(() => _lines[i]['selected'] = v ?? false)
                                    : null,
                              ),
                            ),
                            DataCell(Text(_lines[i]['employeeCode']?.toString() ?? '')),
                            DataCell(Text(_lines[i]['employeeName']?.toString() ?? '')),
                            DataCell(Text(_lines[i]['typeLabel']?.toString() ?? '')),
                            DataCell(Text(formatMoney(_lines[i]['amount']))),
                            DataCell(
                              Text(
                                _lines[i]['ok'] == true
                                    ? context.t('ded.ready')
                                    : (_lines[i]['reason']?.toString() ?? context.t('common.error')),
                                style: TextStyle(
                                  color: _lines[i]['ok'] == true ? AppColors.success : AppColors.danger,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(context.t('common.cancel'))),
        FilledButton(
          onPressed: okCount == 0
              ? null
              : () {
                  final selected = _lines
                      .where((l) => l['ok'] == true && l['selected'] == true)
                      .map((l) => {
                            'employeeId': l['employeeId'],
                            'type': l['type'],
                            'amount': l['amount'],
                            'note': l['note'] ?? '',
                          })
                      .toList();
                  Navigator.pop(context, selected);
                },
          child: Text(context.t('ded.approveCount', {'count': okCount})),
        ),
      ],
    );
  }
}
