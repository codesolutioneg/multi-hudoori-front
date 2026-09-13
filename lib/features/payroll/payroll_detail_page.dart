import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/injection.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_theme_v2.dart';
import '../../core/utils/file_download.dart';
import '../../core/utils/file_pick.dart';
import '../../core/utils/money_format.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/sellix_card.dart';
import '../advances/widgets/advance_create_dialogs.dart';
import '../advances/widgets/long_advance_flow_dialog.dart';
import 'payroll_line_edit_dialog.dart';
import '../../l10n/l10n_extension.dart';

class PayrollDetailPage extends StatefulWidget {
  const PayrollDetailPage({super.key, required this.payrollId});
  final String payrollId;

  @override
  State<PayrollDetailPage> createState() => _PayrollDetailPageState();
}

class _PayrollDetailPageState extends State<PayrollDetailPage> {
  static const _linePageSize = 40;

  Map<String, dynamic> _payroll = {};
  List<Map<String, dynamic>> _lines = [];
  bool _loading = true;
  bool _loadingMoreLines = false;
  bool _hasMoreLines = false;
  int _lineOffset = 0;
  int _lineTotal = 0;
  String? _pendingAction;
  final ScrollController _scrollCtrl = ScrollController();
  final _searchCtrl = TextEditingController();
  Timer? _searchDebounce;
  String _lineSearch = '';
  /// Same-cycle payrolls (dateFrom/dateTo), list order.
  List<Map<String, dynamic>> _cyclePayrolls = [];
  int _cycleIndex = -1;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _searchCtrl.addListener(_onSearchChanged);
    _load(reset: true);
  }

  @override
  void didUpdateWidget(covariant PayrollDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.payrollId != widget.payrollId) {
      _lineSearch = '';
      _searchCtrl.clear();
      _cyclePayrolls = [];
      _cycleIndex = -1;
      _load(reset: true);
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      final next = _searchCtrl.text.trim();
      if (next == _lineSearch) return;
      _lineSearch = next;
      _load(reset: true);
    });
  }

  void _onScroll() {
    if (!_hasMoreLines || _loadingMoreLines || _loading) return;
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 240) {
      _loadMoreLines();
    }
  }

  Future<void> _load({bool reset = true}) async {
    if (reset) setState(() => _loading = true);
    try {
      final p = await api.payrollGet(
        widget.payrollId,
        lineLimit: _linePageSize,
        lineOffset: 0,
        lineSearch: _lineSearch.isEmpty ? null : _lineSearch,
      );
      if (!mounted) return;
      final pag = p['_linePagination'] as Map?;
      final lines = p['lines'];
      setState(() {
        _payroll = p;
        _lines = lines is List
            ? lines.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
            : [];
        _lineOffset = _lines.length;
        _lineTotal = (pag?['total'] as num?)?.toInt() ?? (p['employeeCount'] as num?)?.toInt() ?? _lines.length;
        _hasMoreLines = pag?['hasMore'] == true;
        _loading = false;
      });
      unawaited(_loadCycleSiblings());
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _loadCycleSiblings() async {
    final from = _payroll['dateFrom']?.toString();
    final to = _payroll['dateTo']?.toString();
    if (from == null || from.isEmpty || to == null || to.isEmpty) return;
    try {
      final all = await api.payrollList(limit: 200);
      if (!mounted) return;
      final siblings = all
          .where(
            (p) =>
                p['dateFrom']?.toString() == from &&
                p['dateTo']?.toString() == to,
          )
          .toList();
      // Same order as the period group on the list page (API list order).
      final idx = siblings.indexWhere(
        (p) => p['id']?.toString() == widget.payrollId,
      );
      setState(() {
        _cyclePayrolls = siblings;
        _cycleIndex = idx;
      });
    } catch (_) {
      // Non-blocking — detail page still works without sibling nav.
    }
  }

  String _cycleLabel(Map<String, dynamic> p) {
    final branch = p['branchName']?.toString().trim() ?? '';
    final name = p['name']?.toString().trim() ?? '';
    if (branch.isNotEmpty) return branch;
    if (name.isNotEmpty) return name;
    return p['id']?.toString() ?? '';
  }

  void _goCycleSibling(int delta) {
    if (_cycleIndex < 0 || _cyclePayrolls.isEmpty) return;
    final next = _cycleIndex + delta;
    if (next < 0 || next >= _cyclePayrolls.length) return;
    final id = _cyclePayrolls[next]['id']?.toString();
    if (id == null || id.isEmpty || id == widget.payrollId) return;
    context.go('${AppRoutes.hrPayroll}/$id');
  }

  Future<void> _loadMoreLines() async {
    if (!_hasMoreLines || _loadingMoreLines) return;
    setState(() => _loadingMoreLines = true);
    try {
      final p = await api.payrollGet(
        widget.payrollId,
        lineLimit: _linePageSize,
        lineOffset: _lineOffset,
        lineSearch: _lineSearch.isEmpty ? null : _lineSearch,
      );
      if (!mounted) return;
      final pag = p['_linePagination'] as Map?;
      final more = p['lines'];
      setState(() {
        if (more is List) {
          _lines.addAll(more.whereType<Map>().map((e) => Map<String, dynamic>.from(e)));
        }
        _lineOffset = _lines.length;
        _hasMoreLines = pag?['hasMore'] == true;
        _loadingMoreLines = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loadingMoreLines = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  bool get _actionBusy => _pendingAction != null;

  bool _loadingAction(String actionId) => _pendingAction == actionId;

  VoidCallback? _go(bool ok, VoidCallback fn) => (!_actionBusy && ok) ? fn : null;

  Future<void> _run(String actionId, Future<dynamic> Function() fn, String success) async {
    if (_actionBusy) return;
    setState(() => _pendingAction = actionId);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await fn();
      await _load(reset: false);
      if (mounted) messenger.showSnackBar(SnackBar(content: Text(success)));
    } catch (e) {
      if (mounted) messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _pendingAction = null);
    }
  }

  Future<void> _calculate() async {
    if (_actionBusy) return;
    setState(() => _pendingAction = 'calculate');
    final messenger = ScaffoldMessenger.of(context);
    try {
      final data = await api.payrollCalculate(widget.payrollId);
      await _load(reset: false);
      if (!mounted) return;
      final mode = data['calculateMode']?.toString();
      final msg = data['message']?.toString();
      messenger.showSnackBar(SnackBar(
        content: Text(
          (msg != null && msg.isNotEmpty)
              ? msg
              : (mode == 'excel_link_only'
                  ? context.t('pay.linkedOnly')
                  : context.t('pay.calculated')),
        ),
      ));
      final over = ((data['overDeducted'] as List?) ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final count = (data['overDeductedCount'] as num?)?.toInt() ?? over.length;
      if (count > 0) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => _PayrollOverDeductedDialog(items: over),
        );
      }
    } catch (e) {
      if (mounted) messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _pendingAction = null);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchOverDeductedLines() async {
    final snap = await api.payrollGet(
      widget.payrollId,
      includeLines: false,
      lineLimit: 0,
    );
    return ((snap['overDeducted'] as List?) ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<bool> _promptBeforeConfirm({required String title}) async {
    final over = await _fetchOverDeductedLines();
    if (!mounted) return false;
    if (over.isNotEmpty) {
      return await showDialog<bool>(
            context: context,
            builder: (ctx) => _PayrollOverDeductedDialog(
              items: over,
              confirmMode: true,
              title: title,
            ),
          ) ??
          false;
    }
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(title),
            content: Text(context.t('pay.noNegativeContinue')),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.t('common.cancel'))),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(context.t('pay.continue'))),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _confirmPayroll() async {
    if (_actionBusy) return;
    final ok = await _promptBeforeConfirm(title: context.t('pay.confirmSheet'));
    if (!ok) return;
    await _run('confirm', () => api.payrollConfirm(widget.payrollId), context.t('pay.confirmed'));
  }

  String _fmtJournalAmount(dynamic v) => _fmtMoney((v as num?)?.toDouble() ?? 0);

  Future<void> _sendPayrollToOdoo() async {
    if (_actionBusy) return;
    if (_payroll['odooSent'] == true || _payroll['odooPayrollJournalId'] != null) {
      final name = _payroll['odooMoveName']?.toString() ?? '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(name.isEmpty ? context.t('pay.alreadySent') : context.t('pay.alreadySentName', {'name': name}))),
      );
      return;
    }
    setState(() => _pendingAction = 'odoo_preview');
    Map<String, dynamic> preview;
    try {
      preview = await api.payrollOdooJournalPreview(widget.payrollId);
    } catch (e) {
      if (!mounted) return;
      setState(() => _pendingAction = null);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      return;
    }
    if (!mounted) return;
    setState(() => _pendingAction = null);
    final amounts = Map<String, dynamic>.from(preview['amounts'] as Map? ?? {});
    final cashFawry = Map<String, dynamic>.from(preview['cashFawry'] as Map? ?? {});
    final emails = ((preview['notificationEmails'] as List?) ?? [])
        .map((e) => e.toString())
        .where((e) => e.trim().isNotEmpty)
        .toList();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t('pay.sendJournal')),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _payroll['odooMoveId'] != null
                    ? context.t('pay.journalExists')
                    : context.t('pay.journalNew'),
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.35),
              ),
              const SizedBox(height: 12),
              Text(context.t('pay.jSalaryDebit', {'amount': _fmtJournalAmount(amounts['totalEarnings'])})),
              Text(context.t('pay.jCompanyIns', {'amount': _fmtJournalAmount(amounts['companySocial'])})),
              Text(context.t('pay.jPenalties', {'amount': _fmtJournalAmount(amounts['penalties'])})),
              Text(context.t('pay.jLongAdv', {'amount': _fmtJournalAmount(amounts['longTermAdvance'])})),
              Text(context.t('pay.jShortAdv', {'amount': _fmtJournalAmount(amounts['salaryAdvance'])})),
              Text(context.t('pay.jPayable', {'amount': _fmtJournalAmount(amounts['netSalary'])})),
              const SizedBox(height: 8),
              Text(
                context.t('pay.jBalance', {'debit': _fmtJournalAmount(amounts['totalDebit']), 'credit': _fmtJournalAmount(amounts['totalCredit'])}),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 10),
              Text(context.t('pay.jCashTotal', {'amount': _fmtJournalAmount(cashFawry['cashTotal'])})),
              Text(context.t('pay.jFawryTotal', {'amount': _fmtJournalAmount(cashFawry['fawryGrandTotal'])})),
              Text(context.t('pay.jFawryComm', {'amount': _fmtJournalAmount(cashFawry['fawryCommission'])})),
              const SizedBox(height: 10),
              Text(
                emails.isEmpty
                    ? context.t('pay.noBranchEmails')
                    : context.t('pay.willEmail', {'count': emails.length}),
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.35),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.t('common.cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(context.t('pay.send'))),
        ],
      ),
    );
    if (ok != true) return;
    await _run(
      'send_odoo',
      () => api.payrollSendToOdoo(widget.payrollId),
      context.t('pay.journalCreated'),
    );
  }

  Future<void> _downloadExport(
    String actionId,
    Future<Map<String, dynamic>> Function() fetch,
    String fallbackName,
  ) async {
    if (_actionBusy) return;
    setState(() => _pendingAction = actionId);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final r = await fetch();
      final filename = r['filename']?.toString() ?? fallbackName;
      final base64 = r['base64']?.toString() ?? r['file']?.toString() ?? '';
      final mime = r['mimeType']?.toString() ?? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      if (base64.isEmpty) throw Exception(context.t('pay.emptyFromServer'));
      downloadBase64File(base64, filename, mime);
      if (mounted) messenger.showSnackBar(SnackBar(content: Text(context.t('emp.downloaded', {'file': filename}))));
    } catch (e) {
      if (mounted) messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _pendingAction = null);
    }
  }

  Future<void> _exportFawry() =>
      _downloadExport('export_fawry', () => api.payrollExportFawry(widget.payrollId), 'fawry.xlsx');

  Future<void> _exportPayroll() =>
      _downloadExport('export_xlsx', () => api.payrollExportXlsx(widget.payrollId), 'payroll.xlsx');

  Future<void> _exportPayslips() => _downloadExport(
        'export_payslips',
        () => api.payrollExportPayslipsXlsx(widget.payrollId),
        'payslips.xlsx',
      );

  Future<void> _exportCashFawry() => _downloadExport(
        'export_cash_fawry',
        () => api.payrollExportCashFawry(widget.payrollId),
        'cash_fawry.xlsx',
      );

  Future<void> _exportPunchImportReference() => _downloadExport(
        'export_punch_ref',
        () => api.payrollExportPunchImportReference(widget.payrollId),
        'punch_report_reference.xlsx',
      );

  Future<void> _reimportPunchReport() async {
    if (_actionBusy) return;
    final base64 = await pickExcelBase64();
    if (base64 == null || base64.isEmpty) return;
    await _run(
      'reimport_punch',
      () => api.payrollReimportPunchReport(widget.payrollId, base64),
      context.t('pay.updatedFromReport'),
    );
  }

  Future<void> _addLongAdvance() async {
    if (_actionBusy || !mounted) return;
    final dateTo = _payroll['dateTo']?.toString();
    final ok = await showLongAdvanceCreateDialog(
      context,
      initialDeductionStart: dateTo,
      payrollId: widget.payrollId,
      linkPayrollAfterSave: true,
      onSaved: () async {
        await _load(reset: false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('pay.advanceCreated'))),
        );
      },
    );
    if (!mounted || ok != true) return;
    await _load(reset: false);
  }

  bool get _fromPunchImport => _payroll['calculationSource']?.toString() == 'punch_report_import';

  bool get _excelSourceLocked => _payroll['excelSourceLocked'] == true;

  String get _calculateTooltip {
    if (_excelSourceLocked) {
      return context.t('pay.linkOnlyHint');
    }
    return _fromPunchImport
        ? context.t('pay.recalcFromReport')
        : context.t('pay.calcFromPunches');
  }

  bool get _hasPunchImportFile {
    if (!_fromPunchImport) return false;
    final src = _payroll['punchImportSource'];
    if (src is! Map) return false;
    return src['hasSourceFile'] == true;
  }

  Future<void> _importPayroll() async {
    if (_actionBusy) return;
    final base64 = await pickExcelBase64();
    if (base64 == null || base64.isEmpty) return;
    await _run('import_xlsx', () => api.payrollImportXlsx(widget.payrollId, base64), context.t('pay.excelImported'));
  }

  Future<void> _resetEditComparison() async {
    await _run('reset_edit_cmp', () => api.payrollResetEditComparison(widget.payrollId), context.t('pay.comparisonReset'));
  }

  Future<void> _showSingleEmployeeDialog() async {
    final searchCtrl = TextEditingController();
    List<Map<String, dynamic>> results = [];
    bool searching = false;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          Future<void> search() async {
            setDlg(() => searching = true);
            try {
              final page = await api.employeesList(search: searchCtrl.text.trim(), limit: 30);
              setDlg(() { results = page.items; searching = false; });
            } catch (e) {
              setDlg(() => searching = false);
              if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(e.toString())));
            }
          }
          return AlertDialog(
            title: Text(context.t('pay.addEmployee')),
            content: SizedBox(
              width: 420,
              height: 360,
              child: Column(
                children: [
                  TextField(
                    controller: searchCtrl,
                    decoration: InputDecoration(
                      hintText: context.t('pay.searchNameCode'),
                      suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: search),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => search(),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: searching
                        ? const Center(child: CircularProgressIndicator())
                        : ListView.builder(
                            itemCount: results.length,
                            itemBuilder: (_, i) {
                              final e = results[i];
                              return ListTile(
                                title: Text('${e['code']} — ${e['name']}'),
                                onTap: () async {
                                  Navigator.pop(ctx);
                                  await _run(
                                    'add_employee',
                                    () => api.payrollCalculateSingleEmployee(
                                      payrollId: widget.payrollId,
                                      employeeId: e['id'],
                                    ),
                                    context.t('pay.employeeAdded'),
                                  );
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.t('common.cancel')))],
          );
        },
      ),
    );
    searchCtrl.dispose();
  }

  Future<void> _showLocationTransferDialog() async {
    final targetCtrl = TextEditingController(text: _payroll['branchName']?.toString() ?? '');
    List<Map<String, dynamic>> items = [];
    bool loading = false;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          Future<void> load() async {
            final t = targetCtrl.text.trim();
            if (t.isEmpty) return;
            setDlg(() => loading = true);
            try {
              final list = await api.payrollLocationTransferList(
                payrollId: widget.payrollId,
                targetLocation: t,
              );
              setDlg(() { items = list; loading = false; });
            } catch (e) {
              setDlg(() => loading = false);
              if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(e.toString())));
            }
          }
          return AlertDialog(
            title: Text(context.t('pay.moveLocation')),
            content: SizedBox(
              width: 480,
              height: 400,
              child: Column(
                children: [
                  TextField(
                    controller: targetCtrl,
                    decoration: InputDecoration(
                      labelText: context.t('pay.targetLocation'),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonalIcon(
                    onPressed: loading ? null : load,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: Text(context.t('pay.loadList')),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: loading
                        ? const Center(child: CircularProgressIndicator())
                        : _LocationTransferList(
                            items: items,
                            onApply: (selected) async {
                              Navigator.pop(ctx);
                              await _run(
                                'location_transfer',
                                () => api.payrollLocationTransferApply(
                                  payrollId: widget.payrollId,
                                  targetLocation: targetCtrl.text.trim(),
                                  lineIds: selected,
                                ),
                                context.t('pay.locationMoved'),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.t('common.close')))],
          );
        },
      ),
    );
    targetCtrl.dispose();
  }

  Future<void> _showDuplicatesDialog() async {
    if (_actionBusy) return;
    setState(() => _pendingAction = 'check_dup');
    try {
      final items = await api.payrollDuplicatesList(widget.payrollId);
      if (!mounted) return;
      setState(() => _pendingAction = null);
      await showDialog<void>(
        context: context,
        builder: (ctx) => _PayrollDuplicatesDialog(
          items: items,
          currentPayrollId: widget.payrollId,
          onExport: () => _downloadExport(
            'export_dup_xlsx',
            () => api.payrollDuplicatesExportXlsx(widget.payrollId),
            'payroll_duplicates.xlsx',
          ),
          onDelete: (lineId) async {
            await api.payrollDuplicateMoveLine(lineId: lineId, action: 'delete');
            await _load(reset: false);
          },
          onMove: (lineId, targetPayrollId) async {
            await api.payrollDuplicateMoveLine(
              lineId: lineId,
              targetPayrollId: targetPayrollId,
              action: 'move',
            );
            await _load(reset: false);
          },
          loadPayrollTargets: () async {
            final all = await api.payrollList();
            final from = _payroll['dateFrom']?.toString();
            final to = _payroll['dateTo']?.toString();
            return all.where((p) {
              if (p['id'] == widget.payrollId) return false;
              if (p['state'] == 'confirmed') return false;
              if (from != null && p['dateFrom']?.toString() != from) return false;
              if (to != null && p['dateTo']?.toString() != to) return false;
              return true;
            }).toList();
          },
        ),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted && _pendingAction == 'check_dup') setState(() => _pendingAction = null);
    }
  }

  Widget _punchImportSourceBanner() {
    if (!_fromPunchImport) return const SizedBox.shrink();
    final src = _payroll['punchImportSource'];
    final filename = src is Map ? src['sourceFilename']?.toString() ?? '' : '';
    final empCount = src is Map ? src['employeeCount'] : null;
    final hasFile = _hasPunchImportFile;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.fingerprint, color: AppColors.primary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t('pay.fromUploadedReport'),
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (filename.isNotEmpty) context.t('pay.fileLine', {'file': filename}),
                    if (empCount != null) context.t('pay.empInReport', {'count': empCount}),
                    if (hasFile)
                      context.t('pay.reportHint')
                    else
                      context.t('pay.noSavedFile'),
                  ].join(' • '),
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _editComparisonBanner() {
    if (_payroll['showEditComparison'] != true) return const SizedBox.shrink();
    final before = (_payroll['comparisonTotalNetBefore'] as num?)?.toDouble() ?? 0;
    final after = (_payroll['comparisonTotalNetAfter'] as num?)?.toDouble() ?? 0;
    final delta = after - before;
    final msg = _payroll['editImportMessage']?.toString() ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.compare_arrows, color: AppColors.warning, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.t('pay.comparisonAfter'), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                if (msg.isNotEmpty) Text(msg, style: const TextStyle(fontSize: 12)),
                Text(
                  context.t('pay.netBeforeAfter', {'before': _fmtMoney(before), 'after': _fmtMoney(after), 'delta': '${delta >= 0 ? '+' : ''}${_fmtMoney(delta)}'}),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          TextButton(onPressed: _actionBusy ? null : _resetEditComparison, child: Text(context.t('pay.hide'))),
        ],
      ),
    );
  }

  Widget _linkStatsRow() {
    if ((_payroll['state']?.toString() ?? '') == 'draft') return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _statChip(context.t('pay.deductionsShort'), _payroll['deductionCount'], _payroll['deductionTotalAmount']),
          _statChip(context.t('pay.shortAdv'), _payroll['shortAdvanceCount'], _payroll['shortAdvanceTotalAmount']),
          _statChip(context.t('pay.longAdv'), _payroll['longAdvanceCount'], _payroll['longAdvanceTotalAmount']),
        ],
      ),
    );
  }

  Widget _odooSentBanner() {
    final journalListed =
        _payroll['odooSent'] == true || _payroll['odooPayrollJournalId'] != null;
    final moveOnly = !journalListed && _payroll['odooMoveId'] != null;
    if (!journalListed && !moveOnly) return const SizedBox.shrink();
    final name = _payroll['odooMoveName']?.toString().trim() ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(
            journalListed ? Icons.check_circle_outline : Icons.info_outline,
            color: AppColors.primary,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  journalListed ? context.t('pay.sentToOdoo') : context.t('pay.journalNotListed'),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                Text(
                  journalListed
                      ? (name.isEmpty ? context.t('pay.draftJournal') : context.t('pay.journalName', {'name': name}))
                      : context.t('pay.pressSendHint'),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(String label, dynamic count, dynamic amount) {
    return Chip(
      avatar: const Icon(Icons.insights, size: 16),
      label: Text('$label: ${count ?? 0} • ${_fmtMoney(amount)}'),
    );
  }

  String _stateAr(String s) {
    switch (s) {
      case 'draft': return context.t('pay.draft');
      case 'calculated': return context.t('pay.computed');
      case 'confirmed': return context.t('pay.confirmedState');
      default: return s;
    }
  }

  Future<void> _runPayrollAction(String action) async {
    switch (action) {
      case 'sync_emp':
        await _run('sync_emp', () => api.payrollSyncEmployeeInfo(widget.payrollId), context.t('pay.employeesUpdated'));
      case 'recalc_basic':
        await _run('recalc_basic', () => api.payrollRecalculateBasicSalary(widget.payrollId), context.t('pay.basicRecalculated'));
      case 'recalc_adv':
        await _run('recalc_adv', () => api.payrollRecalculateAdvances(widget.payrollId), context.t('pay.advancesReset'));
      case 'link_long':
        await _run('link_long', () => api.payrollLinkLongAdvances(widget.payrollId), context.t('pay.advancesLinked'));
      case 'fix_penalty':
        await _run('fix_penalty', () => api.payrollFixPenaltyValues(widget.payrollId), context.t('pay.penaltyFixed'));
      case 'check_dup':
        await _showDuplicatesDialog();
      case 'link_ded_conf':
        await _run('link_ded_conf', () => api.payrollLinkDeductionsConfirmed(widget.payrollId), context.t('pay.deductionsLinked'));
    }
  }

  String _fmtMoney(dynamic v) => formatMoney(v);

  String _fmtQty(dynamic v) {
    final n = v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;
    if (n == n.roundToDouble()) return '${n.round()}';
    return n.toStringAsFixed(2);
  }

  double _lineNum(Map<String, dynamic> line, String key) {
    final v = line[key];
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }

  double _sumLines(String key) => _lines.fold(0.0, (s, l) => s + _lineNum(l, key));

  Set<String> get _duplicateEmployeeIds {
    final counts = <String, int>{};
    for (final line in _lines) {
      final id = line['employeeId']?.toString() ?? '';
      if (id.isNotEmpty) counts[id] = (counts[id] ?? 0) + 1;
    }
    return counts.entries.where((e) => e.value > 1).map((e) => e.key).toSet();
  }

  String _lineText(Map<String, dynamic> line, String key) {
    final v = line[key]?.toString().trim() ?? '';
    return v.isEmpty ? '—' : v;
  }

  Widget _scopeBanner() {
    final isBranch = _payroll['isBranchScoped'] == true;
    final branch = _payroll['branchName']?.toString().trim() ?? '';
    final grid = _payroll['shiftGridTitle']?.toString().trim() ?? '';
    final scope = _payroll['payrollScope']?.toString().trim() ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isBranch ? AppColors.primarySoft : AppColors.muted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isBranch ? AppColors.primary.withValues(alpha: 0.35) : AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(isBranch ? Icons.apartment_rounded : Icons.public_rounded, color: AppColors.primary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isBranch ? context.t('pay.branchSheet') : context.t('pay.generalSheet'),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 4),
                if (scope.isNotEmpty)
                  Text(scope, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                if (isBranch && branch.isNotEmpty)
                  Text(context.t('pay.branchLine', {'branch': branch}), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                if (isBranch && grid.isNotEmpty && grid != branch)
                  Text(context.t('pay.gridLine', {'grid': grid}), style: const TextStyle(fontSize: 12)),
                if (isBranch)
                  Text(
                    context.t('pay.gridOnlyHint'),
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn({
    required String tooltip,
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    bool filled = false,
    bool tonal = false,
    bool loading = false,
  }) {
    final btnIcon = loading
        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
        : Icon(icon, size: 18);
    final child = filled
        ? FilledButton.icon(onPressed: onPressed, icon: btnIcon, label: Text(label))
        : tonal
            ? FilledButton.tonalIcon(onPressed: onPressed, icon: btnIcon, label: Text(label))
            : OutlinedButton.icon(onPressed: onPressed, icon: btnIcon, label: Text(label));
    return _tipButton(message: tooltip, child: child);
  }

  Widget _actionSection(String title, List<Widget> children) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppThemeV2.caption.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: children),
        ],
      ),
    );
  }

  Widget _payrollActionsBar(String state, bool canEdit) {
    final go = _go;
    final isDraft = state == 'draft';
    final isCalc = state == 'calculated';
    final isConfirmed = state == 'confirmed';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _actionSection(context.t('pay.step1'), [
          _actionBtn(
            tooltip: _calculateTooltip,
            onPressed: go(canEdit && (isDraft || isCalc), _calculate),
            icon: Icons.calculate,
            label: context.t('pay.calculate'),
            filled: true,
            loading: _loadingAction('calculate'),
          ),
          _actionBtn(
            tooltip: context.t('pay.linkPendingHint'),
            onPressed: go(isCalc, () => _run('link_ded', () => api.payrollLinkDeductions(widget.payrollId), context.t('pay.deductionsLinked2'))),
            icon: Icons.link,
            label: context.t('pay.linkDeductions'),
          ),
          _actionBtn(
            tooltip: context.t('pay.confirmHint'),
            onPressed: go(isCalc, _confirmPayroll),
            icon: Icons.check,
            label: context.t('common.confirm'),
            tonal: true,
          ),
          _actionBtn(
            tooltip: _payroll['odooSent'] == true
                ? context.t('pay.sentLabel', {'name': _payroll['odooMoveName'] ?? ''})
                : _payroll['odooMoveId'] != null
                    ? context.t('pay.linkExistingHint')
                    : context.t('pay.createDraftHint'),
            onPressed: go(
              (isCalc || isConfirmed) && _payroll['odooSent'] != true,
              _sendPayrollToOdoo,
            ),
            icon: Icons.cloud_upload_outlined,
            label: _payroll['odooSent'] == true
                ? context.t('pay.sentToOdoo2')
                : _payroll['odooMoveId'] != null
                    ? context.t('pay.showInEntries')
                    : context.t('pay.sendToOdoo'),
            filled: true,
            loading: _loadingAction('odoo_preview') || _loadingAction('send_odoo'),
          ),
        ]),
        _actionSection(context.t('pay.step2'), [
          if (_fromPunchImport)
            _actionBtn(
              tooltip: _hasPunchImportFile
                  ? context.t('pay.downloadRefHint')
                  : context.t('pay.noSavedFileShort'),
              onPressed: go(_hasPunchImportFile, _exportPunchImportReference),
              icon: Icons.fingerprint,
              label: context.t('pay.punchReport'),
              loading: _loadingAction('export_punch_ref'),
            ),
          if (_fromPunchImport)
            _actionBtn(
              tooltip:
                  context.t('pay.reimportHint'),
              onPressed: go(canEdit && (isDraft || isCalc), _reimportPunchReport),
              icon: Icons.upload_file,
              label: context.t('pay.reimportReport'),
              loading: _loadingAction('reimport_punch'),
            ),
          _actionBtn(
            tooltip: context.t('pay.exportFullHint'),
            onPressed: go(!isDraft, _exportPayroll),
            icon: Icons.download,
            label: context.t('pay.exportExcel'),
            loading: _loadingAction('export_xlsx'),
          ),
          _actionBtn(
            tooltip: context.t('pay.payslipsHint'),
            onPressed: go(!isDraft, _exportPayslips),
            icon: Icons.receipt_long_outlined,
            label: context.t('pay.exportPayslips'),
            loading: _loadingAction('export_payslips'),
          ),
          _actionBtn(
            tooltip: context.t('pay.importHint'),
            onPressed: go(isCalc, _importPayroll),
            icon: Icons.upload_file,
            label: context.t('pay.importExcel'),
          ),
        ]),
        _actionSection(context.t('pay.step3'), [
          _actionBtn(
            tooltip: context.t('pay.fawryFileHint'),
            onPressed: go(!isDraft, _exportFawry),
            icon: Icons.account_balance_wallet_outlined,
            label: 'Fawry',
          ),
          _actionBtn(
            tooltip: context.t('pay.cashFileHint'),
            onPressed: go(!isDraft, _exportCashFawry),
            icon: Icons.payments_outlined,
            label: context.t('pay.cash'),
          ),
        ]),
        _actionSection(context.t('pay.step4'), [
          _actionBtn(
            tooltip: context.t('pay.refreshEmpHint'),
            onPressed: go(isCalc, () => _runPayrollAction('sync_emp')),
            icon: Icons.sync,
            label: context.t('pay.refreshEmp'),
          ),
          _actionBtn(
            tooltip: context.t('pay.resetBasicHint'),
            onPressed: go(isCalc, () => _runPayrollAction('recalc_basic')),
            icon: Icons.payments,
            label: context.t('pay.resetBasic'),
          ),
          _actionBtn(
            tooltip: context.t('pay.resetAdvHint'),
            onPressed: go(isCalc, () => _runPayrollAction('recalc_adv')),
            icon: Icons.refresh,
            label: context.t('pay.resetAdv'),
          ),
          _actionBtn(
            tooltip: context.t('pay.longAdvHint'),
            onPressed: go(isCalc, () => _runPayrollAction('link_long')),
            icon: Icons.account_balance,
            label: context.t('pay.longAdv'),
          ),
          _actionBtn(
            tooltip: context.t('pay.addLongAdvHint'),
            onPressed: go(isCalc, _addLongAdvance),
            icon: Icons.add_card_outlined,
            label: context.t('pay.addLongAdv'),
          ),
          _actionBtn(
            tooltip: context.t('pay.longAdvFlowHint'),
            onPressed: go(true, () => showLongAdvanceFlowDialog(context)),
            icon: Icons.route_outlined,
            label: context.t('pay.longAdvFlow'),
          ),
          _actionBtn(
            tooltip: context.t('pay.fixPenaltyHint'),
            onPressed: go(isCalc, () => _runPayrollAction('fix_penalty')),
            icon: Icons.build,
            label: context.t('pay.fixPenalty'),
          ),
          _actionBtn(
            tooltip: context.t('pay.dupCheckHint'),
            onPressed: go(!isDraft, () => _runPayrollAction('check_dup')),
            icon: Icons.content_copy,
            label: context.t('pay.dupCheck'),
          ),
        ]),
        _actionSection(context.t('pay.step5'), [
          _actionBtn(
            tooltip: context.t('pay.addOneHint'),
            onPressed: go(canEdit && !isConfirmed, _showSingleEmployeeDialog),
            icon: Icons.person_add,
            label: context.t('pay.addOne'),
          ),
          _actionBtn(
            tooltip: context.t('pay.moveLocHint'),
            onPressed: go(isCalc, _showLocationTransferDialog),
            icon: Icons.swap_horiz,
            label: context.t('pay.moveLocation'),
          ),
          _actionBtn(
            tooltip: context.t('pay.pdfHint'),
            onPressed: go(!isDraft, () => _downloadExport(
              'export_pdf',
              () => api.payrollPayslipPdfAll(widget.payrollId),
              'payslips.pdf',
            )),
            icon: Icons.picture_as_pdf,
            label: context.t('pay.pdfPayslips'),
          ),
          _actionBtn(
            tooltip: context.t('pay.backToDraftHint'),
            onPressed: go(isCalc, () => _run('back_draft', () => api.payrollBackToDraft(widget.payrollId), context.t('pay.backToDraft'))),
            icon: Icons.undo,
            label: context.t('pay.draft'),
          ),
          _actionBtn(
            tooltip: context.t('pay.linkConfirmedHint'),
            onPressed: go(isConfirmed, () => _runPayrollAction('link_ded_conf')),
            icon: Icons.link_off,
            label: context.t('pay.linkConfirmed'),
          ),
        ]),
      ],
    );
  }

  Widget _tipButton({required String message, required Widget child}) {
    return Tooltip(message: message, waitDuration: const Duration(milliseconds: 400), child: child);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final state = _payroll['state']?.toString() ?? '';
    final canEdit = state != 'confirmed';

    return SingleChildScrollView(
      controller: _scrollCtrl,
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: _payroll['name']?.toString() ?? context.t('pay.sheetTitle'),
            subtitle: [
              '${_payroll['dateFrom']} → ${_payroll['dateTo']}',
              if (_payroll['payablePeriodDays'] != null)
                context.t('pay.actualDays', {'days': _fmtQty(_payroll['payablePeriodDays'])}),
              _payroll['payrollScope']?.toString() ?? '',
              context.t('pay.employeeCount', {'count': _payroll['employeeCount'] ?? _lineTotal}),
              if (_lineSearch.isNotEmpty) context.t('pay.searchResults', {'count': _lineTotal}),
              if (_lines.isNotEmpty && _lines.length < _lineTotal) context.t('pay.showingOf', {'shown': _lines.length, 'total': _lineTotal}),
              _stateAr(state),
              if (_cycleIndex >= 0 && _cyclePayrolls.length > 1)
                context.t('pay.sheetOf', {'index': _cycleIndex + 1, 'total': _cyclePayrolls.length}),
            ].where((s) => s.isNotEmpty).join('  •  '),
            actions: [
              if (_cyclePayrolls.length > 1) ...[
                Tooltip(
                  message: _cycleIndex > 0
                      ? context.t('pay.prevSheet', {'label': _cycleLabel(_cyclePayrolls[_cycleIndex - 1])})
                      : context.t('pay.noPrevSheet'),
                  child: TextButton.icon(
                    onPressed: _cycleIndex > 0 ? () => _goCycleSibling(-1) : null,
                    icon: const Icon(Icons.navigate_next, size: 18),
                    label: Text(context.t('pay.prev')),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '${_cycleIndex + 1}/${_cyclePayrolls.length}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Tooltip(
                  message: _cycleIndex >= 0 &&
                          _cycleIndex < _cyclePayrolls.length - 1
                      ? context.t('pay.nextSheet', {'label': _cycleLabel(_cyclePayrolls[_cycleIndex + 1])})
                      : context.t('pay.noNextSheet'),
                  child: TextButton.icon(
                    onPressed: _cycleIndex >= 0 &&
                            _cycleIndex < _cyclePayrolls.length - 1
                        ? () => _goCycleSibling(1)
                        : null,
                    icon: const Icon(Icons.navigate_before, size: 18),
                    label: Text(context.t('pay.next')),
                  ),
                ),
              ],
              IconButton(onPressed: () => _load(reset: true), icon: const Icon(Icons.refresh)),
            ],
            onBack: () => context.go(AppRoutes.hrPayroll),
          ),
          const SizedBox(height: 8),
          _scopeBanner(),
          _punchImportSourceBanner(),
          _editComparisonBanner(),
          _odooSentBanner(),
          const SizedBox(height: 12),
          _payrollActionsBar(state, canEdit),
          _linkStatsRow(),
          const SizedBox(height: 16),
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: context.t('pay.searchFull'),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _lineSearch.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchCtrl.clear();
                        if (_lineSearch.isNotEmpty) {
                          _lineSearch = '';
                          _load(reset: true);
                        }
                      },
                    )
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _totalCard(context.t('pay.totalEarnings'), _payroll['totalEarnings']),
              const SizedBox(width: 8),
              _totalCard(context.t('pay.totalDeductions'), _payroll['totalDeductions']),
              const SizedBox(width: 8),
              _totalCard(context.t('pay.netSalaries'), _payroll['totalNet']),
              const SizedBox(width: 8),
              _totalCard(
                context.t('pay.grandTotal'),
                _payroll['grandTotal'] ?? _payroll['totalNet'],
                highlight: true,
              ),
            ],
          ),
          const SizedBox(height: 16),
          SellixCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                if (_lineSearch.isNotEmpty && _lines.isEmpty && !_loading)
                  Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(context.t('pay.noSearchMatch'), style: TextStyle(color: AppColors.textSecondary)),
                  ),
                if (_lines.isNotEmpty || _loading)
                  SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: [
                      DataColumn(label: Text(context.t('common.code'))),
                      DataColumn(label: Text(context.t('payCol.employee'))),
                      DataColumn(label: Text(context.t('payCol.department'))),
                      DataColumn(label: Text(context.t('payCol.job'))),
                      DataColumn(label: Text(context.t('payCol.branch'))),
                      DataColumn(label: Text(context.t('payCol.basic'))),
                      DataColumn(label: Text(context.t('payCol.actualDays'))),
                      DataColumn(label: Text(context.t('payCol.overtime'))),
                      DataColumn(label: Text(context.t('payCol.daysPay'))),
                      DataColumn(label: Text(context.t('payCol.overtimeAmount'))),
                      DataColumn(label: Text(context.t('payCol.lateDeduction'))),
                      DataColumn(label: Text(context.t('payCol.earlyLeave'))),
                      DataColumn(label: Text(context.t('payCol.punchDeduction'))),
                      DataColumn(label: Text(context.t('payCol.absenceDeduction'))),
                      DataColumn(label: Text(context.t('payCol.sickDeduction'))),
                      DataColumn(label: Text(context.t('payCol.leaveDeduction'))),
                      DataColumn(label: Text(context.t('payCol.insurance'))),
                      DataColumn(label: Text(context.t('payCol.cheques'))),
                      DataColumn(label: Text(context.t('payCol.manual'))),
                      DataColumn(label: Text(context.t('payCol.penalty'))),
                      DataColumn(label: Text(context.t('payCol.lateLeave'))),
                      DataColumn(label: Text(context.t('payCol.attendanceDeduction'))),
                      DataColumn(label: Text(context.t('payCol.hoursDiff'))),
                      DataColumn(label: Text(context.t('payCol.advances'))),
                      DataColumn(label: Text(context.t('payCol.earnings'))),
                      DataColumn(label: Text(context.t('payCol.deductions'))),
                      DataColumn(label: Text(context.t('payCol.net'))),
                      if (_payroll['showEditComparison'] == true) DataColumn(label: Text(context.t('payCol.netDelta'))),
                    ],
                    rows: [
                      if (_lines.isNotEmpty)
                        DataRow(
                          color: WidgetStateProperty.all(AppColors.muted.withValues(alpha: 0.5)),
                          cells: [
                            DataCell(Text(context.t('payCol.total'), style: TextStyle(fontWeight: FontWeight.w800))),
                            const DataCell(Text('')),
                            const DataCell(Text('')),
                            const DataCell(Text('')),
                            const DataCell(Text('')),
                            DataCell(Text(_fmtMoney(_sumLines('basicSalary')), style: const TextStyle(fontWeight: FontWeight.w700))),
                            DataCell(Text(_fmtQty(_sumLines('actualWorkingDays')), style: const TextStyle(fontWeight: FontWeight.w700))),
                            DataCell(Text(_fmtQty(_sumLines('overtimeHours')), style: const TextStyle(fontWeight: FontWeight.w700))),
                            DataCell(Text(_fmtMoney(_sumLines('workDaysSalary')), style: const TextStyle(fontWeight: FontWeight.w700))),
                            DataCell(Text(_fmtMoney(_sumLines('overtimeAmount')), style: const TextStyle(fontWeight: FontWeight.w700))),
                            DataCell(Text(_fmtMoney(_sumLines('lateDeduction')), style: const TextStyle(fontWeight: FontWeight.w700))),
                            DataCell(Text(_fmtMoney(_sumLines('earlyDeduction')), style: const TextStyle(fontWeight: FontWeight.w700))),
                            DataCell(Text(_fmtMoney(_lines.fold(0.0, (s, l) => s + _lineNum(l, 'punchDeductionCheckin') + _lineNum(l, 'punchDeductionCheckout'))), style: const TextStyle(fontWeight: FontWeight.w700))),
                            DataCell(Text(_fmtMoney(_sumLines('absentDeduction')), style: const TextStyle(fontWeight: FontWeight.w700))),
                            DataCell(Text(_fmtMoney(_sumLines('sickDeduction')), style: const TextStyle(fontWeight: FontWeight.w700))),
                            DataCell(Text(_fmtMoney(_sumLines('leaveAbsenceDeductionValue')), style: const TextStyle(fontWeight: FontWeight.w700))),
                            DataCell(Text(_fmtMoney(_sumLines('socialInsurance')), style: const TextStyle(fontWeight: FontWeight.w700))),
                            DataCell(Text(_fmtMoney(_sumLines('deductionChecks')), style: const TextStyle(fontWeight: FontWeight.w700))),
                            DataCell(Text(_fmtMoney(_sumLines('manualDebit')), style: const TextStyle(fontWeight: FontWeight.w700))),
                            DataCell(Text(_fmtMoney(_sumLines('penaltyDeductionValue')), style: const TextStyle(fontWeight: FontWeight.w700))),
                            DataCell(Text(_fmtMoney(_sumLines('lateCheckoutDeduction')), style: const TextStyle(fontWeight: FontWeight.w700))),
                            DataCell(Text(_fmtMoney(_sumLines('attendanceDeduction')), style: const TextStyle(fontWeight: FontWeight.w700))),
                            DataCell(Text(_fmtQty(_sumLines('hoursDifference')), style: const TextStyle(fontWeight: FontWeight.w700))),
                            DataCell(Text(_fmtMoney(_lines.fold(0.0, (s, l) => s + _lineNum(l, 'advanceShortTotal') + _lineNum(l, 'advanceLongTotal'))), style: const TextStyle(fontWeight: FontWeight.w700))),
                            DataCell(Text(_fmtMoney(_sumLines('totalEarnings')), style: const TextStyle(fontWeight: FontWeight.w700))),
                            DataCell(Text(_fmtMoney(_sumLines('totalDeductions')), style: const TextStyle(fontWeight: FontWeight.w700))),
                            DataCell(Text(_fmtMoney(_sumLines('netSalary')), style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary))),
                            if (_payroll['showEditComparison'] == true)
                              DataCell(Text(_fmtMoney(_sumLines('editNetDelta')), style: const TextStyle(fontWeight: FontWeight.w700))),
                          ],
                        ),
                      for (final line in _lines)
                        DataRow(
                          color: WidgetStateProperty.resolveWith((states) {
                            final empId = line['employeeId']?.toString() ?? '';
                            if (empId.isNotEmpty && _duplicateEmployeeIds.contains(empId)) {
                              return AppColors.warning.withValues(alpha: 0.14);
                            }
                            return null;
                          }),
                          cells: [
                          DataCell(Text(line['employeeCode']?.toString() ?? '')),
                          DataCell(Text(line['employeeName']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w500))),
                          DataCell(Text(_lineText(line, 'departmentName'), style: const TextStyle(fontSize: 12))),
                          DataCell(Text(_lineText(line, 'positionName'), style: const TextStyle(fontSize: 12))),
                          DataCell(Text(_lineText(line, 'employeeLocation'), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
                          DataCell(Text(_fmtMoney(line['basicSalary']))),
                          DataCell(Text(_fmtQty(line['actualWorkingDays']))),
                          DataCell(Text(_fmtQty(line['overtimeHours']))),
                          DataCell(Text(_fmtMoney(line['workDaysSalary']))),
                          DataCell(Text(_fmtMoney(line['overtimeAmount']))),
                          DataCell(Text(_fmtMoney(line['lateDeduction']))),
                          DataCell(Text(_fmtMoney(line['earlyDeduction']))),
                          DataCell(Text(_fmtMoney((line['punchDeductionCheckin'] as num? ?? 0) + (line['punchDeductionCheckout'] as num? ?? 0)))),
                          DataCell(Text(_fmtMoney(line['absentDeduction']))),
                          DataCell(Text(_fmtMoney(line['sickDeduction']))),
                          DataCell(Text(_fmtMoney(line['leaveAbsenceDeductionValue']))),
                          DataCell(Text(_fmtMoney(line['socialInsurance']))),
                          DataCell(Text(_fmtMoney(line['deductionChecks']))),
                          DataCell(Text(_fmtMoney(line['manualDebit']))),
                          DataCell(Text(_fmtMoney(line['penaltyDeductionValue']))),
                          DataCell(Text(_fmtMoney(line['lateCheckoutDeduction']))),
                          DataCell(Text(_fmtMoney(line['attendanceDeduction']))),
                          DataCell(Text(_fmtQty(line['hoursDifference']))),
                          DataCell(Text(_fmtMoney((line['advanceShortTotal'] as num? ?? 0) + (line['advanceLongTotal'] as num? ?? 0)))),
                          DataCell(Text(_fmtMoney(line['totalEarnings']))),
                          DataCell(Text(_fmtMoney(line['totalDeductions']))),
                          DataCell(Text(_fmtMoney(line['netSalary']), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary))),
                          if (_payroll['showEditComparison'] == true)
                            DataCell(Text(_fmtMoney(line['editNetDelta']))),
                          ],
                          onSelectChanged: canEdit ? (_) => _editLine(line) : null,
                        ),
                    ],
                  ),
                ),
                if (_loadingMoreLines)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalCard(String title, dynamic value, {bool highlight = false}) {
    return Expanded(
      child: Card(
        color: highlight ? AppColors.primaryLight : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              Text(formatMoney(value), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: highlight ? AppColors.primary : null)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editLine(Map<String, dynamic> line) async {
    if (_actionBusy) return;
    final messenger = ScaffoldMessenger.of(context);
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => PayrollLineEditDialog(
        line: line,
        onFixBasicSalary: () async {
          try {
            await api.payrollLineFixBasicSalary(line['id']);
            return true;
          } catch (e) {
            messenger.showSnackBar(SnackBar(content: Text(e.toString())));
            return false;
          }
        },
      ),
    );
    if (!mounted || payload == null) return;
    if (payload['__fixBasic'] == true) {
      await _load(reset: false);
      return;
    }
    try {
      await api.payrollLineUpdate(line['id'], payload);
      await _load(reset: false);
      if (mounted) messenger.showSnackBar(SnackBar(content: Text(context.t('pay.rowSaved'))));
    } catch (e) {
      if (mounted) messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
}

class _PayrollDuplicatesDialog extends StatefulWidget {
  const _PayrollDuplicatesDialog({
    required this.items,
    required this.currentPayrollId,
    required this.onDelete,
    required this.onMove,
    required this.loadPayrollTargets,
    required this.onExport,
  });

  final List<Map<String, dynamic>> items;
  final String currentPayrollId;
  final Future<void> Function(String lineId) onDelete;
  final Future<void> Function(String lineId, String targetPayrollId) onMove;
  final Future<List<Map<String, dynamic>>> Function() loadPayrollTargets;
  final Future<void> Function() onExport;

  @override
  State<_PayrollDuplicatesDialog> createState() => _PayrollDuplicatesDialogState();
}

class _PayrollDuplicatesDialogState extends State<_PayrollDuplicatesDialog> {
  List<Map<String, dynamic>> _targets = [];
  bool _loadingTargets = true;

  @override
  void initState() {
    super.initState();
    _loadTargets();
  }

  Future<void> _loadTargets() async {
    try {
      final t = await widget.loadPayrollTargets();
      if (mounted) setState(() { _targets = t; _loadingTargets = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingTargets = false);
    }
  }

  String _typeLabel(String? t) {
    switch (t) {
      case 'in_payroll':
        return context.t('pay.dupInSheet');
      case 'other_payroll_same_period':
        return context.t('pay.dupOtherSheet');
      default:
        return t ?? '';
    }
  }

  Future<void> _pickMoveTarget(String lineId) async {
    if (_targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('pay.noTargetSheet'))),
      );
      return;
    }
    final target = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(context.t('pay.moveToSheet')),
        children: [
          for (final p in _targets)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, p['id']?.toString()),
              child: Text('${p['name']} (${p['state']})'),
            ),
        ],
      ),
    );
    if (target == null || target.isEmpty) return;
    await widget.onMove(lineId, target);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.t('pay.dupCheck')),
      content: SizedBox(
        width: 560,
        height: 400,
        child: widget.items.isEmpty
            ? Center(child: Text(context.t('pay.noDuplicates')))
            : ListView.separated(
                itemCount: widget.items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final row = widget.items[i];
                  final lineId = row['lineId']?.toString() ?? '';
                  final canDelete = row['duplicateType'] == 'in_payroll';
                  final canMove = row['duplicateType'] == 'in_payroll' && !_loadingTargets;
                  return ListTile(
                    title: Text('${row['employeeCode']} — ${row['employeeName']}'),
                    subtitle: Text(
                      '${_typeLabel(row['duplicateType']?.toString())}\n${row['note'] ?? ''}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (canMove)
                          TextButton(
                            onPressed: lineId.isEmpty ? null : () => _pickMoveTarget(lineId),
                            child: Text(context.t('pay.move')),
                          ),
                        if (canDelete)
                          TextButton(
                            onPressed: lineId.isEmpty
                                ? null
                                : () async {
                                    await widget.onDelete(lineId);
                                    if (ctx.mounted) Navigator.pop(ctx);
                                  },
                            child: Text(context.t('common.delete')),
                          ),
                      ],
                    ),
                  );
                },
              ),
      ),
      actions: [
        if (widget.items.isNotEmpty)
          OutlinedButton.icon(
            onPressed: () async {
              await widget.onExport();
            },
            icon: Icon(Icons.download, size: 18),
            label: Text(context.t('pay.exportExcel')),
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: Text(context.t('common.close'))),
      ],
    );
  }
}

class _PayrollOverDeductedDialog extends StatelessWidget {
  const _PayrollOverDeductedDialog({
    required this.items,
    this.confirmMode = false,
    this.title,
  });

  final List<Map<String, dynamic>> items;
  final bool confirmMode;
  final String? title;

  String _fmt(dynamic v) => formatMoney(v);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title ?? context.t('pay.negativeWarning', {'count': items.length})),
      content: SizedBox(
        width: 640,
        height: 360,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              confirmMode
                  ? context.t('pay.negativeBody')
                  : context.t('pay.negativeBodyAlt'),
              style: TextStyle(fontSize: 13),
            ),
            SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: DataTable(
                  columns: [
                    DataColumn(label: Text(context.t('common.code'))),
                    DataColumn(label: Text(context.t('common.name'))),
                    DataColumn(label: Text(context.t('payCol.earnings'))),
                    DataColumn(label: Text(context.t('payCol.deductions'))),
                    DataColumn(label: Text(context.t('payCol.increase'))),
                    DataColumn(label: Text(context.t('payCol.net'))),
                  ],
                  rows: [
                    for (final row in items)
                      DataRow(
                        cells: [
                          DataCell(Text(row['employeeCode']?.toString() ?? '')),
                          DataCell(Text(row['employeeName']?.toString() ?? '')),
                          DataCell(Text(_fmt(row['totalEarnings']))),
                          DataCell(Text(_fmt(row['totalDeductions']))),
                          DataCell(
                            Text(
                              _fmt(row['excess']),
                              style: const TextStyle(
                                color: AppColors.danger,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          DataCell(Text(_fmt(row['netSalary']))),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (confirmMode) ...[
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.t('common.cancel'))),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.t('pay.continueConfirm')),
          ),
        ] else
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.t('common.ok')),
          ),
      ],
    );
  }
}

class _LocationTransferList extends StatefulWidget {
  const _LocationTransferList({required this.items, required this.onApply});

  final List<Map<String, dynamic>> items;
  final Future<void> Function(List<String> lineIds) onApply;

  @override
  State<_LocationTransferList> createState() => _LocationTransferListState();
}

class _LocationTransferListState extends State<_LocationTransferList> {
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    for (final item in widget.items) {
      if (item['needsTransfer'] == true && item['selected'] == true) {
        final id = item['lineId']?.toString();
        if (id != null && id.isNotEmpty) _selected.add(id);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return Center(child: Text(context.t('pay.loadAfterTarget')));
    }
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: widget.items.length,
            itemBuilder: (_, i) {
              final row = widget.items[i];
              final lineId = row['lineId']?.toString() ?? '';
              final needs = row['needsTransfer'] == true;
              return CheckboxListTile(
                value: _selected.contains(lineId),
                onChanged: needs && lineId.isNotEmpty
                    ? (v) => setState(() {
                        if (v == true) {
                          _selected.add(lineId);
                        } else {
                          _selected.remove(lineId);
                        }
                      })
                    : null,
                title: Text('${row['employeeCode']} — ${row['employeeName']}'),
                subtitle: Text(
                  '${row['currentLocation'] ?? '—'} → ${needs ? 'يحتاج نقل' : 'مطابق'}',
                  style: TextStyle(fontSize: 12, color: needs ? null : Colors.grey),
                ),
              );
            },
          ),
        ),
        FilledButton(
          onPressed: _selected.isEmpty ? null : () => widget.onApply(_selected.toList()),
          child: Text(context.t('pay.moveCount', {'count': _selected.length})),
        ),
      ],
    );
  }
}
