import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/injection.dart';
import '../../core/layout/app_page_scaffold.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/utils/file_download.dart';
import '../../core/utils/money_format.dart';
import '../../core/widgets/hr_local_data_info.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/sellix_card.dart';
import '../../core/widgets/skeleton_box.dart';
import '../../core/widgets/status_tag.dart';
import '../../l10n/l10n_extension.dart';

class PayrollListPage extends StatefulWidget {
  const PayrollListPage({super.key});

  @override
  State<PayrollListPage> createState() => _PayrollListPageState();
}

class _PayrollListPageState extends State<PayrollListPage> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  /// Period keys currently expanded (all collapsed by default).
  final Set<String> _expandedPeriods = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await api.payrollList(limit: 100);
      if (mounted) {
        setState(() {
          _items = items;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  StatusTagType _tag(String s) {
    if (s == 'confirmed') return StatusTagType.success;
    if (s == 'calculated') return StatusTagType.info;
    return StatusTagType.warning;
  }

  String _stateAr(String s) {
    switch (s) {
      case 'draft':
        return context.t('pay.draft');
      case 'calculated':
        return context.t('pay.computed');
      case 'confirmed':
        return context.t('pay.confirmedState');
      default:
        return s;
    }
  }

  String _periodKey(Map<String, dynamic> p) =>
      '${p['dateFrom'] ?? ''}|${p['dateTo'] ?? ''}';

  List<MapEntry<String, List<Map<String, dynamic>>>> _groupedByPeriod() {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final p in _items) {
      final key = _periodKey(p);
      (map[key] ??= []).add(p);
    }
    final entries = map.entries.toList();
    entries.sort((a, b) {
      final aTo = a.key.split('|').last;
      final bTo = b.key.split('|').last;
      return bTo.compareTo(aTo);
    });
    return entries;
  }

  double _num(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _create() async {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, 1);
    final to = DateTime(now.year, now.month + 1, 0);
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _PayrollCreateDialog(
        initialDateFrom: _fmtDate(from),
        initialDateTo: _fmtDate(to),
      ),
    );
    if (result == null) return;
    try {
      final p = await api.payrollCreate(
        name: result['name']?.toString(),
        dateFrom: result['dateFrom']?.toString(),
        dateTo: result['dateTo']?.toString(),
        shiftGridId: result['shiftGridId'],
        deviceId: result['deviceId'],
      );
      if (mounted && p['id'] != null) {
        context.go('${AppRoutes.hrPayroll}/${p['id']}');
      } else {
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  static ButtonStyle get headerActionStyle => FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        ),
      );

  Widget _periodHeader({
    required String from,
    required String to,
    required int branchCount,
    required double cash,
    required double fawryApproved,
    required double fawryCommission,
    required double fawryGrand,
    required double grandTotalSum,
    required int employees,
  }) {
    final netTotal = _round2(cash + fawryApproved);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.t('payL.cycle', {'from': from, 'to': to}),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        const SizedBox(height: 4),
        Text(
          context.t('payL.cycleSummary', {
            'branches': branchCount,
            'employees': employees,
            'grand': formatMoney(grandTotalSum, fallback: '0'),
            'net': formatMoney(netTotal, fallback: '0'),
            'cash': formatMoney(cash, fallback: '0'),
            'fawry': formatMoney(fawryApproved, fallback: '0'),
            'commission': formatMoney(fawryCommission, fallback: '0'),
            'fawryGrand': formatMoney(fawryGrand, fallback: '0'),
          }),
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            OutlinedButton.icon(
              onPressed: () => _openPeriodReportDialog(
                kind: _PeriodReportKind.zeroBasic,
                dateFrom: from,
                dateTo: to,
              ),
              icon: const Icon(Icons.money_off_outlined, size: 16),
              label: Text(context.t('payL.zeroBasic')),
            ),
            OutlinedButton.icon(
              onPressed: () => _openPeriodReportDialog(
                kind: _PeriodReportKind.negativeNet,
                dateFrom: from,
                dateTo: to,
              ),
              icon: const Icon(Icons.trending_down, size: 16),
              label: Text(context.t('payL.negativeNet')),
            ),
            OutlinedButton.icon(
              onPressed: () => _openPeriodReportDialog(
                kind: _PeriodReportKind.duplicates,
                dateFrom: from,
                dateTo: to,
              ),
              icon: const Icon(Icons.content_copy_outlined, size: 16),
              label: Text(context.t('payL.dupInGrids')),
            ),
            OutlinedButton.icon(
              onPressed: () => _downloadPeriodFile(
                call: () => api.payrollPeriodCashFawryExportZip(
                  dateFrom: from,
                  dateTo: to,
                ),
                successLabel: context.t('payL.cashFawryDownloaded'),
              ),
              icon: const Icon(Icons.account_balance_wallet_outlined, size: 16),
              label: Text(context.t('payL.cashFawryCycle')),
            ),
            OutlinedButton.icon(
              onPressed: () => _downloadPeriodFile(
                call: () => api.payrollPeriodSummaryExportXlsx(
                  dateFrom: from,
                  dateTo: to,
                ),
                successLabel: context.t('payL.summaryDownloaded'),
              ),
              icon: const Icon(Icons.summarize_outlined, size: 16),
              label: Text(context.t('payL.payrollSummary')),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _downloadPeriodFile({
    required Future<Map<String, dynamic>> Function() call,
    required String successLabel,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final data = await call();
      final base64 = (data['base64'] ?? data['file'])?.toString() ?? '';
      final filename = data['filename']?.toString() ?? 'download.bin';
      final mime = data['mimeType']?.toString();
      if (base64.isEmpty) throw Exception(context.t('payL.emptyFile'));
      downloadBase64File(
        base64,
        filename,
        mime ?? 'application/octet-stream',
      );
      if (!mounted) return;
      final count = data['fileCount'];
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            count is num
                ? context.t('payL.filesCount', {'label': successLabel, 'count': count})
                : successLabel,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _openPeriodReportDialog({
    required _PeriodReportKind kind,
    required String dateFrom,
    required String dateTo,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => _PeriodPayrollReportDialog(
        kind: kind,
        dateFrom: dateFrom,
        dateTo: dateTo,
      ),
    );
  }

  double _round2(double n) => (n * 100).round() / 100;

  Widget _payrollTile(Map<String, dynamic> p) {
    final fromImport =
        p['calculationSource']?.toString() == 'punch_report_import';
    final branch = p['branchName']?.toString().trim() ?? '';
    final name = p['name']?.toString() ?? '';
    final empCount = p['employeeCount'] ?? 0;
    final cash = _num(p['cashTotal']);
    final fawryApproved = _num(p['fawryTotal']);
    final fawryComm = p['fawryCommission'] != null
        ? _num(p['fawryCommission'])
        : _round2(fawryApproved * 0.0015);
    final fawryGrand = p['fawryGrandTotal'] != null
        ? _num(p['fawryGrandTotal'])
        : _round2(fawryApproved + fawryComm);
    final grandTotal = p['grandTotal'] != null
        ? _num(p['grandTotal'])
        : _round2(_num(p['totalNet']) + fawryComm);
    return ListTile(
      title: Text(
        branch.isNotEmpty ? branch : (name.isNotEmpty ? name : context.t('pay.sheetTitle')),
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t('payL.sheetSummary', {
              'count': empCount,
              'grand': formatMoney(grandTotal, fallback: ''),
              'net': formatMoney(p['totalNet'], fallback: ''),
              'cashFawry': cash > 0 || fawryGrand > 0
                  ? context.t('payL.cashFawrySuffix', {
                      'cash': formatMoney(cash, fallback: '0'),
                      'fawry': formatMoney(fawryGrand, fallback: '0'),
                    })
                  : '',
            }),
            style: const TextStyle(fontSize: 12.5),
          ),
          if (fromImport)
            Padding(
              padding: EdgeInsets.only(top: 4),
              child: Chip(
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                avatar: Icon(Icons.fingerprint, size: 14),
                label: Text(context.t('payL.fromPunchReport'), style: TextStyle(fontSize: 11)),
              ),
            ),
        ],
      ),
      trailing: StatusTag(
        label: _stateAr(p['state']?.toString() ?? ''),
        type: _tag(p['state']?.toString() ?? ''),
      ),
      onTap: () => context.go('${AppRoutes.hrPayroll}/${p['id']}'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groupedByPeriod();
    return AppPageScaffold(
      scrollable: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: context.t('payroll.listTitle'),
            subtitle: context.t('payroll.listSubtitle'),
            icon: Icons.payments_outlined,
            actions: [
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
              FilledButton.icon(
                onPressed: _create,
                style: headerActionStyle,
                icon: const Icon(Icons.add, size: 18),
                label: Text(context.t('payroll.newSheet')),
              ),
            ],
          ),
          HrLocalDataBanner(
            title: context.t('payroll.localBanner'),
            hint: context.t('payroll.localHint'),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const _PayrollListSkeleton()
                : _items.isEmpty
                    ? HrEmptyListCard(
                        message: context.t('payroll.emptyList'),
                        actionLabel: context.t('payroll.newSheet'),
                        onAction: _create,
                      )
                    : ListView.separated(
                        itemCount: groups.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final entry = groups[i];
                          final key = entry.key;
                          final parts = key.split('|');
                          final from = parts.isNotEmpty ? parts.first : '';
                          final to = parts.length > 1 ? parts[1] : from;
                          final payrolls = entry.value;
                          final branchCount = payrolls.length;
                          var cash = 0.0;
                          var fawryApproved = 0.0;
                          var fawryCommission = 0.0;
                          var fawryGrand = 0.0;
                          var grandTotalSum = 0.0;
                          var employees = 0;
                          for (final p in payrolls) {
                            cash += _num(p['cashTotal']);
                            final approved = _num(p['fawryTotal']);
                            final comm = p['fawryCommission'] != null
                                ? _num(p['fawryCommission'])
                                : _round2(approved * 0.0015);
                            final grand = p['fawryGrandTotal'] != null
                                ? _num(p['fawryGrandTotal'])
                                : _round2(approved + comm);
                            final sheetGrand = p['grandTotal'] != null
                                ? _num(p['grandTotal'])
                                : _round2(_num(p['totalNet']) + comm);
                            fawryApproved += approved;
                            fawryCommission += comm;
                            fawryGrand += grand;
                            grandTotalSum += sheetGrand;
                            final n = p['employeeCount'];
                            employees += n is num
                                ? n.toInt()
                                : int.tryParse(n?.toString() ?? '') ?? 0;
                          }
                          cash = _round2(cash);
                          fawryApproved = _round2(fawryApproved);
                          fawryCommission = _round2(fawryCommission);
                          fawryGrand = _round2(fawryGrand);
                          grandTotalSum = _round2(grandTotalSum);
                          final expanded = _expandedPeriods.contains(key);
                          return SellixCard(
                            padding: EdgeInsets.zero,
                            child: ExpansionTile(
                              key: PageStorageKey('payroll-period-$key'),
                              initiallyExpanded: expanded,
                              maintainState: true,
                              onExpansionChanged: (open) {
                                setState(() {
                                  if (open) {
                                    _expandedPeriods.add(key);
                                  } else {
                                    _expandedPeriods.remove(key);
                                  }
                                });
                              },
                              title: _periodHeader(
                                from: from,
                                to: to,
                                branchCount: branchCount,
                                cash: cash,
                                fawryApproved: fawryApproved,
                                fawryCommission: fawryCommission,
                                fawryGrand: fawryGrand,
                                grandTotalSum: grandTotalSum,
                                employees: employees,
                              ),
                              children: [
                                const Divider(height: 1),
                                for (var j = 0; j < payrolls.length; j++) ...[
                                  _payrollTile(payrolls[j]),
                                  if (j < payrolls.length - 1)
                                    const Divider(height: 1),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _PayrollCreateDialog extends StatefulWidget {
  const _PayrollCreateDialog({
    required this.initialDateFrom,
    required this.initialDateTo,
  });

  final String initialDateFrom;
  final String initialDateTo;

  @override
  State<_PayrollCreateDialog> createState() => _PayrollCreateDialogState();
}

class _PayrollCreateDialogState extends State<_PayrollCreateDialog> {
  final _nameCtrl = TextEditingController();
  late final TextEditingController _fromCtrl;
  late final TextEditingController _toCtrl;
  List<Map<String, dynamic>> _grids = [];
  List<Map<String, dynamic>> _devices = [];
  String? _shiftGridId;
  String? _deviceId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fromCtrl = TextEditingController(text: widget.initialDateFrom);
    _toCtrl = TextEditingController(text: widget.initialDateTo);
    _loadOptions();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _fromCtrl.dispose();
    _toCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    try {
      final grids = await api.shiftGridList(limit: 100);
      final devices = await api.devicesList();
      if (mounted) setState(() { _grids = grids; _devices = devices; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate(TextEditingController ctrl) async {
    final initial = DateTime.tryParse(ctrl.text.trim()) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      ctrl.text = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    }
  }

  void _onGridChanged(String? gridId) {
    setState(() {
      _shiftGridId = gridId;
      if (gridId == null || gridId.isEmpty) return;
      final grid = _grids.firstWhere((g) => g['id']?.toString() == gridId, orElse: () => {});
      if (grid.isEmpty) return;
      final from = grid['dateFrom']?.toString();
      final to = grid['dateTo']?.toString();
      if (from != null && from.isNotEmpty) _fromCtrl.text = from;
      if (to != null && to.isNotEmpty) _toCtrl.text = to;
      final dev = grid['deviceId']?.toString();
      if (dev != null && dev.isNotEmpty && dev != 'false') _deviceId = dev;
    });
  }

  void _submit() {
    final from = _fromCtrl.text.trim();
    final to = _toCtrl.text.trim();
    if (from.isEmpty || to.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.t('payL.pickPeriod'))));
      return;
    }
    Navigator.pop(context, {
      'name': _nameCtrl.text.trim(),
      'dateFrom': from,
      'dateTo': to,
      if (_shiftGridId != null && _shiftGridId!.isNotEmpty) 'shiftGridId': _shiftGridId,
      if (_deviceId != null && _deviceId!.isNotEmpty) 'deviceId': _deviceId,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.t('payL.newSheet')),
      content: SizedBox(
        width: 420,
        child: _loading
            ? const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()))
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _nameCtrl,
                      decoration: InputDecoration(
                        labelText: context.t('payL.sheetName'),
                        hintText: context.t('payL.sheetNameHint'),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _fromCtrl,
                            readOnly: true,
                            decoration: InputDecoration(
                              labelText: context.t('emp.dateFrom'),
                              border: const OutlineInputBorder(),
                              isDense: true,
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.calendar_today, size: 18),
                                onPressed: () => _pickDate(_fromCtrl),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _toCtrl,
                            readOnly: true,
                            decoration: InputDecoration(
                              labelText: context.t('emp.dateTo'),
                              border: const OutlineInputBorder(),
                              isDense: true,
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.calendar_today, size: 18),
                                onPressed: () => _pickDate(_toCtrl),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      value: _shiftGridId,
                      decoration: InputDecoration(
                        labelText: context.t('payL.gridOptional'),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        DropdownMenuItem<String?>(value: null, child: Text(context.t('payL.generalSheet'))),
                        for (final g in _grids)
                          DropdownMenuItem<String?>(
                            value: g['id']?.toString(),
                            child: Text(
                              '${g['name'] ?? g['id']} (${g['dateFrom']} → ${g['dateTo']})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: _onGridChanged,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      value: _deviceId,
                      decoration: InputDecoration(
                        labelText: context.t('payL.deviceOptional'),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        DropdownMenuItem<String?>(value: null, child: Text(context.t('payL.unspecified'))),
                        for (final d in _devices)
                          DropdownMenuItem<String?>(
                            value: d['id']?.toString(),
                            child: Text(d['name']?.toString() ?? d['id']?.toString() ?? ''),
                          ),
                      ],
                      onChanged: (v) => setState(() => _deviceId = v),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.t('payL.gridAutofillHint'),
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(context.t('common.cancel'))),
        FilledButton(onPressed: _loading ? null : _submit, child: Text(context.t('common.create'))),
      ],
    );
  }
}

enum _PeriodReportKind { zeroBasic, duplicates, negativeNet }

class _PeriodPayrollReportDialog extends StatefulWidget {
  const _PeriodPayrollReportDialog({
    required this.kind,
    required this.dateFrom,
    required this.dateTo,
  });

  final _PeriodReportKind kind;
  final String dateFrom;
  final String dateTo;

  @override
  State<_PeriodPayrollReportDialog> createState() =>
      _PeriodPayrollReportDialogState();
}

class _PeriodPayrollReportDialogState extends State<_PeriodPayrollReportDialog> {
  bool _loading = true;
  bool _exporting = false;
  String? _error;
  List<Map<String, dynamic>> _items = [];

  String get _title => switch (widget.kind) {
        _PeriodReportKind.zeroBasic => context.t('payL.zeroBasicEmployees'),
        _PeriodReportKind.negativeNet => context.t('payL.negativeNetEmployees'),
        _PeriodReportKind.duplicates => context.t('payL.dupInCycleGrids'),
      };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = switch (widget.kind) {
        _PeriodReportKind.zeroBasic => await api.payrollPeriodZeroBasicList(
            dateFrom: widget.dateFrom,
            dateTo: widget.dateTo,
          ),
        _PeriodReportKind.negativeNet => await api.payrollPeriodNegativeNetList(
            dateFrom: widget.dateFrom,
            dateTo: widget.dateTo,
          ),
        _PeriodReportKind.duplicates => await api.payrollPeriodDuplicatesList(
            dateFrom: widget.dateFrom,
            dateTo: widget.dateTo,
          ),
      };
      final raw = (data['items'] as List?) ?? [];
      if (!mounted) return;
      setState(() {
        _items = raw
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
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

  Future<void> _export() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final r = switch (widget.kind) {
        _PeriodReportKind.zeroBasic => await api.payrollPeriodZeroBasicExportXlsx(
            dateFrom: widget.dateFrom,
            dateTo: widget.dateTo,
          ),
        _PeriodReportKind.negativeNet =>
          await api.payrollPeriodNegativeNetExportXlsx(
            dateFrom: widget.dateFrom,
            dateTo: widget.dateTo,
          ),
        _PeriodReportKind.duplicates =>
          await api.payrollPeriodDuplicatesExportXlsx(
            dateFrom: widget.dateFrom,
            dateTo: widget.dateTo,
          ),
      };
      final filename = r['filename']?.toString() ??
          switch (widget.kind) {
            _PeriodReportKind.zeroBasic => 'zero_basic.xlsx',
            _PeriodReportKind.negativeNet => 'negative_net.xlsx',
            _PeriodReportKind.duplicates => 'period_duplicates.xlsx',
          };
      final base64 = r['base64']?.toString() ?? r['file']?.toString() ?? '';
      final mime = r['mimeType']?.toString() ??
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      if (base64.isEmpty) throw Exception(context.t('pay.emptyFromServer'));
      downloadBase64File(base64, filename, mime);
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(context.t('emp.downloaded', {'file': filename}))));
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Map<String, List<Map<String, dynamic>>> _grouped() {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final row in _items) {
      final branch = row['branchName']?.toString().trim().isNotEmpty == true
          ? row['branchName'].toString()
          : context.t('payL.noBranch');
      (map[branch] ??= []).add(row);
    }
    final keys = map.keys.toList()..sort((a, b) => a.compareTo(b));
    return {for (final k in keys) k: map[k]!};
  }

  @override
  Widget build(BuildContext context) {
    final groups = _grouped();
    final width = MediaQuery.sizeOf(context).width;
    return AlertDialog(
      title: Text('$_title (${_items.length})'),
      content: SizedBox(
        width: width > 900 ? 820 : width * 0.92,
        height: 480,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.danger)))
                : _items.isEmpty
                    ? Center(child: Text(context.t('payL.noResultsInCycle')))
                    : ListView(
                        children: [
                          Text(
                            context.t('payL.cycle', {'from': widget.dateFrom, 'to': widget.dateTo}),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          for (final entry in groups.entries) ...[
                            Padding(
                              padding: const EdgeInsets.only(top: 10, bottom: 4),
                              child: Text(
                                '${entry.key} (${entry.value.length})',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            for (final row in entry.value)
                              ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  '${row['employeeCode'] ?? ''} — ${row['employeeName'] ?? ''}',
                                  style: const TextStyle(fontSize: 13),
                                ),
                                subtitle: Text(
                                  switch (widget.kind) {
                                    _PeriodReportKind.zeroBasic =>
                                      context.t('payL.zeroBasicLine', {
                                        'sheet': row['payrollName'] ?? '',
                                        'basic': row['profileBasicSalary'] ?? 0,
                                        'net': formatMoney(row['netSalary'], fallback: '0'),
                                      }),
                                    _PeriodReportKind.negativeNet =>
                                      context.t('payL.negativeNetLine', {
                                        'sheet': row['payrollName'] ?? '',
                                        'earnings': formatMoney(row['totalEarnings'], fallback: '0'),
                                        'deductions': formatMoney(row['totalDeductions'], fallback: '0'),
                                        'net': formatMoney(row['signedNet'], fallback: '0'),
                                      }),
                                    _PeriodReportKind.duplicates =>
                                      context.t('payL.duplicateLine', {
                                        'sheet': row['payrollName'] ?? '',
                                        'count': row['occurrenceCount'] ?? '',
                                        'branches': (row['otherBranches']?.toString().isNotEmpty ?? false)
                                            ? context.t('payL.otherBranches', {'branches': row['otherBranches']})
                                            : '',
                                      }),
                                  },
                                  style: const TextStyle(fontSize: 11.5),
                                ),
                              ),
                          ],
                        ],
                      ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.t('common.close')),
        ),
        FilledButton.icon(
          onPressed: _loading || _exporting || _items.isEmpty ? null : _export,
          icon: _exporting
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download, size: 18),
          label: Text(context.t('payL.downloadExcel')),
        ),
      ],
    );
  }
}

class _PayrollListSkeleton extends StatelessWidget {
  const _PayrollListSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: 3,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) => const _PayrollGroupSkeleton(),
    );
  }
}

class _PayrollGroupSkeleton extends StatelessWidget {
  const _PayrollGroupSkeleton();

  @override
  Widget build(BuildContext context) {
    return SellixCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonBox(height: 18, width: 220),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(
              5,
              (_) => const SkeletonBox(
                height: 24,
                width: 88,
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 14),
          ...List.generate(4, (_) => const _PayrollRowSkeleton()),
        ],
      ),
    );
  }
}

class _PayrollRowSkeleton extends StatelessWidget {
  const _PayrollRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(height: 15, width: 140),
                SizedBox(height: 8),
                SkeletonBox(height: 12, width: 200),
              ],
            ),
          ),
          SizedBox(width: 12),
          SkeletonBox(
            height: 28,
            width: 72,
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
        ],
      ),
    );
  }
}

