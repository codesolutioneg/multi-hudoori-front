import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/injection.dart';
import '../../core/storage/shift_grid_import_storage.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme_v2.dart';
import '../../core/utils/api_error_message.dart';
import '../../core/utils/file_download.dart';
import '../../core/utils/file_pick.dart';
import '../../core/widgets/employee_search_field.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/sellix_card.dart';
import '../../core/widgets/skeleton_box.dart';
import '../../data/api/biotime_api_client.dart';
import '../../l10n/l10n_extension.dart';
import '../auth/auth_cubit.dart';
import 'shift_grid_cell_style.dart';
import 'shift_grid_helpers.dart';
import 'shift_grid_import_untracked_panel.dart';
import 'shift_grid_manual_ot_panel.dart';
import 'shift_grid_setup_panel.dart';

class ShiftGridDetailPage extends StatefulWidget {
  const ShiftGridDetailPage({super.key, required this.gridId});
  final String gridId;

  @override
  State<ShiftGridDetailPage> createState() => _ShiftGridDetailPageState();
}

class _ShiftGridDetailPageState extends State<ShiftGridDetailPage> {
  static const _employeePageSize = 25;

  Map<String, dynamic> _grid = {};
  Map<String, dynamic> _data = {};
  List<Map<String, dynamic>> _shifts = [];
  List<Map<String, dynamic>> _dates = [];
  List<MapEntry<String, List<Map<String, dynamic>>>> _jobGroups = [];
  /// Section rows by job title (default) or by department (operation/kitchen).
  String _grouping = 'job';
  /// HR sends the weekly sheet per department, so this defaults on.
  bool _sheetPerDepartment = true;
  List<_FlatGridRow> _flatRows = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMoreEmployees = false;
  int _employeeOffset = 0;
  String? _bulkValue;
  String? _bulkDateFrom;
  String? _bulkDateTo;
  String _syncState = 'idle';
  int _syncProgress = 0;
  String _syncMessage = '';
  int _syncSynced = 0;
  int _syncTotal = 0;
  int _syncErrors = 0;
  bool _actionBusy = false;
  Timer? _syncTimer;
  final ScrollController _scrollCtrl = ScrollController();
  final HorizontalScrollLinker _horizontalScrollLinker =
      HorizontalScrollLinker();
  late final ScrollController _headerHorizontalScroll = _horizontalScrollLinker
      .attach();
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  List<ShiftGridUntrackedUser> _untrackedImportUsers = [];
  String _lastImportMessage = '';
  bool _untrackedBannerVisible = false;
  /// Last successful punch-report Excel import for this grid (Make Payroll step).
  String? _punchReportImportId;
  /// `grid` | `manualOt`
  String _detailTab = 'grid';

  bool get _isSetup => _grid['state']?.toString() == 'setup';
  bool get _locked => _grid['state'] == 'confirmed';
  bool get _isBusy => _syncState == 'syncing' || _actionBusy;
  bool get _canEditGrid {
    if (_isBusy) return false;
    return context.read<AuthCubit>().state.roles.isBranchStaff;
  }

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _searchCtrl.addListener(_onSearchChanged);
    _load(reset: true);
    _restoreUntrackedFromStorage();
  }

  Future<void> _restoreUntrackedFromStorage() async {
    final saved = await ShiftGridImportStorage.load(widget.gridId);
    if (!mounted || saved == null) return;
    setState(() {
      _untrackedImportUsers = saved.users;
      _lastImportMessage = saved.message;
      _untrackedBannerVisible = saved.users.isNotEmpty;
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _horizontalScrollLinker.dispose();
    _searchCtrl.dispose();
    _stopSyncPoll();
    super.dispose();
  }

  void _onScroll() {
    if (_searchQuery.trim().isNotEmpty ||
        !_hasMoreEmployees ||
        _loadingMore ||
        _loading)
      return;
    if (!_scrollCtrl.hasClients) return;
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 480) {
      _loadMoreEmployees();
    }
  }

  void _onSearchChanged() {
    final next = _searchCtrl.text;
    if (next == _searchQuery) return;
    setState(() => _searchQuery = next);
    if (next.trim().isNotEmpty && _hasMoreEmployees) {
      _loadAllEmployeesForSearch();
    }
  }

  Future<void> _loadAllEmployeesForSearch() async {
    while (_hasMoreEmployees && mounted && !_loadingMore) {
      await _loadMoreEmployees();
    }
  }

  /// Unique department names from employees currently on this grid.
  List<String> _departmentsOnGrid() {
    final ungrouped = tr('emp.noDepartment');
    final names = <String>{};
    for (final entry in _jobGroups) {
      for (final emp in entry.value) {
        final name = emp['department_name']?.toString().trim() ?? '';
        names.add(name.isEmpty ? ungrouped : name);
      }
    }
    final list = names.toList();
    list.sort((a, b) {
      if (a == ungrouped) return 1;
      if (b == ungrouped) return -1;
      return a.compareTo(b);
    });
    return list;
  }

  List<_FlatGridRow> _buildVisibleFlatRows() {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return _flatRows;

    final rows = <_FlatGridRow>[];
    var rowNum = 0;
    for (final entry in _jobGroups) {
      final matched = entry.value.where((emp) {
        final name = emp['name']?.toString().toLowerCase() ?? '';
        final code = emp['code']?.toString().toLowerCase() ?? '';
        return name.contains(q) || code.contains(q);
      }).toList();
      if (matched.isEmpty) continue;
      if (entry.key != 'بدون وظيفة') {
        rows.add(_FlatGridRow.header(entry.key));
      }
      for (final emp in matched) {
        rowNum++;
        rows.add(_FlatGridRow.employee(emp, rowNum));
      }
    }
    return rows;
  }

  Future<bool> _ensureEditable() async {
    if (!_locked) return true;
    try {
      final r = await api.shiftGridReopen(widget.gridId);
      if (r['grid'] is Map) _grid = Map<String, dynamic>.from(r['grid'] as Map);
      if (mounted) setState(() {});
      return true;
    } catch (e) {
      _snack(e.toString());
      return false;
    }
  }

  void _rebuildFlatRows() {
    final rows = <_FlatGridRow>[];
    var rowNum = 0;
    for (final entry in _jobGroups) {
      if (entry.key != 'بدون وظيفة') {
        rows.add(_FlatGridRow.header(entry.key));
      }
      for (final emp in entry.value) {
        rowNum++;
        rows.add(_FlatGridRow.employee(emp, rowNum));
      }
    }
    _flatRows = rows;
  }

  Future<void> _load({bool reset = true}) async {
    if (reset) setState(() => _loading = true);
    try {
      final result = await api.shiftGridGet(
        widget.gridId,
        employeeLimit: _employeePageSize,
        employeeOffset: reset ? 0 : _employeeOffset,
        grouping: _grouping,
      );
      if (!mounted) return;
      final data = Map<String, dynamic>.from(result['data'] as Map? ?? {});
      setState(() {
        _grid = Map<String, dynamic>.from(result['grid'] as Map? ?? {});
        _data = data;
        _dates = parseDates(data['dates']);
        _shifts = parseShifts(data['shifts']);
        if (reset) {
          _jobGroups = parseJobGroups(data['job_groups']);
          _employeeOffset = 0;
        } else {
          mergeJobGroups(_jobGroups, data['job_groups']);
        }
        final pag = data['pagination'] as Map?;
        _hasMoreEmployees = pag?['hasMore'] == true;
        _employeeOffset =
            ((pag?['offset'] as num?)?.toInt() ?? 0) +
            ((pag?['count'] as num?)?.toInt() ?? 0);
        _rebuildFlatRows();
        _syncState = _grid['syncState']?.toString() ?? 'idle';
        _syncProgress = (_grid['syncProgress'] as num?)?.toInt() ?? 0;
        _syncMessage = _grid['syncMessage']?.toString() ?? '';
        _syncSynced = (_grid['syncSyncedCount'] as num?)?.toInt() ?? 0;
        _syncTotal = (_grid['syncTotalCount'] as num?)?.toInt() ?? 0;
        _syncErrors = (_grid['syncErrorsCount'] as num?)?.toInt() ?? 0;
        if (reset) {
          final from = _grid['dateFrom']?.toString();
          final to = _grid['dateTo']?.toString();
          _bulkDateFrom = from;
          _bulkDateTo = to;
        }
        _loading = false;
      });
      if (_syncState == 'syncing') _startSyncPoll();
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _snack(e.toString());
      }
    }
  }

  Future<void> _loadMoreEmployees() async {
    if (!_hasMoreEmployees || _loadingMore || _loading) return;
    setState(() => _loadingMore = true);
    try {
      final result = await api.shiftGridGet(
        widget.gridId,
        employeeLimit: _employeePageSize,
        employeeOffset: _employeeOffset,
        grouping: _grouping,
      );
      if (!mounted) return;
      final data = Map<String, dynamic>.from(result['data'] as Map? ?? {});
      setState(() {
        mergeJobGroups(_jobGroups, data['job_groups']);
        final pag = data['pagination'] as Map?;
        _hasMoreEmployees = pag?['hasMore'] == true;
        _employeeOffset =
            ((pag?['offset'] as num?)?.toInt() ?? 0) +
            ((pag?['count'] as num?)?.toInt() ?? 0);
        _rebuildFlatRows();
        _loadingMore = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loadingMore = false);
        _snack(e.toString());
      }
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<T?> _withBlockingLoader<T>(
    String message,
    Future<T> Function() action,
  ) async {
    if (!mounted) return null;
    setState(() => _actionBusy = true);
    final navigator = Navigator.of(context, rootNavigator: true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(height: 20),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
    try {
      return await action();
    } finally {
      if (mounted) {
        setState(() => _actionBusy = false);
        if (navigator.canPop()) navigator.pop();
      }
    }
  }

  Future<void> _exportExcel() async {
    // Load the full roster so department names cover every employee on the grid.
    await _loadAllEmployeesForSearch();
    if (!mounted) return;
    final departments = _departmentsOnGrid();
    final range = await _pickExcelDateRange(
      title: context.t('grid.exportRange'),
      confirmLabel: context.t('common.export'),
      confirmIcon: Icons.download,
      availableGroups: departments,
      groupsLabel: context.t('grid.departments'),
    );
    if (range == null) return;
    try {
      final selectedDepts = range.groupKeys ?? departments;
      final r = await api.shiftGridExportXlsx(
        widget.gridId,
        dateFrom: range.from,
        dateTo: range.to,
        grouping: _grouping,
        sheetPerGroup: _grouping == 'department' && _sheetPerDepartment,
        // Always send selected names so the API filename gets …_Operation_Kitchen.
        departmentNames: selectedDepts.isEmpty ? null : selectedDepts,
      );
      final base64 = r['base64']?.toString() ?? r['file']?.toString() ?? '';
      final gridName = (_grid['name']?.toString() ?? 'shift_grid')
          .trim()
          .replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_')
          .replaceAll(RegExp(r'\s+'), '_')
          .replaceAll(RegExp(r'_+'), '_')
          .replaceAll(RegExp(r'^_|_$'), '');
      final deptSuffix = selectedDepts
          .map(
            (d) => d
                .trim()
                .replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_')
                .replaceAll(RegExp(r'\s+'), '_')
                .replaceAll(RegExp(r'_+'), '_')
                .replaceAll(RegExp(r'^_|_$'), ''),
          )
          .where((d) => d.isNotEmpty)
          .join('_');
      final baseFallback =
          '${gridName.isEmpty ? 'shift_grid' : gridName}_${range.from}_${range.to}';
      final fallbackName = deptSuffix.isEmpty
          ? '$baseFallback.xlsx'
          : '${baseFallback}_$deptSuffix.xlsx';
      final apiName = r['filename']?.toString() ?? '';
      final filename = apiName.contains('shift_grid_') && apiName.contains(widget.gridId)
          ? fallbackName
          : (apiName.isNotEmpty ? apiName : fallbackName);
      if (base64.isEmpty) throw Exception(context.t('common.emptyFile'));
      downloadBase64File(
        base64,
        filename,
        r['mimeType']?.toString() ??
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      _snack(context.t('common.downloaded', {'file': filename}));
    } catch (e) {
      _snack(e.toString());
    }
  }

  /// One Excel file per department on this grid (ZIP), no department picker.
  Future<void> _exportAllDepartmentsSeparated() async {
    if (_isBusy || _dates.isEmpty) return;
    try {
      await _withBlockingLoader(
        context.t('grid.exportDepartmentsBulkBusy'),
        () async {
          final r = await api.shiftGridExportXlsxByDepartmentBulk(
            gridIds: [widget.gridId],
          );
          final base64 = r['base64']?.toString() ?? r['file']?.toString() ?? '';
          final filename =
              r['filename']?.toString() ?? 'shift_grid_by_department.zip';
          if (base64.isEmpty) throw Exception(context.t('common.emptyFile'));
          downloadBase64File(
            base64,
            filename,
            r['mimeType']?.toString() ?? 'application/zip',
          );
          final files = (r['fileCount'] as num?)?.toInt() ?? 0;
          if (mounted) {
            _snack(
              context
                  .t('grid.exportDepartmentsSeparatedDone')
                  .replaceAll('{files}', '$files'),
            );
          }
          return filename;
        },
      );
    } catch (e) {
      _snack(e.toString());
    }
  }

  Future<void> _importExcel() async {
    if (_locked) {
      _snack(context.t('grid.openForEditBeforeImport'));
      return;
    }
    final range = await _pickExcelDateRange(
      title: context.t('grid.importRange'),
      confirmLabel: context.t('grid.pickFile'),
      confirmIcon: Icons.upload_file,
      subtitle:
          context.t('grid.importRangeHint'),
    );
    if (range == null) return;
    try {
      final base64 = await pickExcelBase64();
      if (base64 == null || base64.isEmpty) return;
      var result = await _withBlockingLoader<Map<String, dynamic>>(
        context.t('grid.importingExcel'),
        () => api.shiftGridImportXlsx(
          widget.gridId,
          base64,
          dateFrom: range.from,
          dateTo: range.to,
        ),
      );
      if (!mounted || result == null) return;

      var untracked = ((result['untrackedUsers'] as List?) ?? [])
          .whereType<Map>()
          .map(
            (e) =>
                ShiftGridUntrackedUser.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList();

      // Offer to create + apply unknown codes (user can accept/reject per row).
      if (untracked.isNotEmpty) {
        final accepted = await showShiftGridOnboardUntrackedDialog(
          context,
          users: untracked,
        );
        if (!mounted) return;
        if (accepted != null && accepted.isNotEmpty) {
          result = await _withBlockingLoader<Map<String, dynamic>>(
            context.t('grid.creatingAccepted'),
            () => api.shiftGridImportXlsx(
              widget.gridId,
              base64,
              dateFrom: range.from,
              dateTo: range.to,
              createEmployeeCodes: accepted,
            ),
          );
          if (!mounted || result == null) return;
          untracked = ((result['untrackedUsers'] as List?) ?? [])
              .whereType<Map>()
              .map(
                (e) => ShiftGridUntrackedUser.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .toList();
        }
      }

      final importMessage = result['message']?.toString() ?? context.t('common.imported');
      setState(() {
        _untrackedImportUsers = untracked;
        _lastImportMessage = importMessage;
        _untrackedBannerVisible = untracked.isNotEmpty;
      });
      await ShiftGridImportStorage.save(
        widget.gridId,
        untracked,
        importMessage,
      );
      await _load(reset: true);
      if (!mounted) return;
      final errors = ((result['errors'] as List?) ?? [])
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList();
      final created =
          (result['createdEmployees'] as num?)?.toInt() ??
          ((result['createdCodes'] as List?)?.length ?? 0);
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(context.t('grid.importResult')),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(importMessage, style: const TextStyle(height: 1.45)),
                  if (created > 0) ...[
                    const SizedBox(height: 10),
                    Text(
                      context.t('grid.onboardCreatedNote', {'n': created}),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                  if (errors.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      context.t('grid.warnings'),
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    for (final err in errors.take(20))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '• $err',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.danger,
                            height: 1.35,
                          ),
                        ),
                      ),
                    if (errors.length > 20)
                      Text(
                        context.t('grid.moreWarnings', {'count': errors.length - 20}),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                  if (untracked.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      context.t('grid.untrackedNote', {'count': untracked.length}),
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
          ),
          actions: [
            if (untracked.isNotEmpty)
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  showShiftGridUntrackedUsersPanel(
                    context,
                    users: untracked,
                    importMessage: importMessage,
                  );
                },
                child: Text(context.t('grid.showUntracked')),
              ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.t('common.close')),
            ),
          ],
        ),
      );
      // Banner stays visible when there are untracked users; details via dialog.
    } catch (e) {
      if (!mounted) return;
      final apiErr = e is BioTimeApiException ? e : null;
      final msg = friendlyApiError(context, e);
      final isMismatch = apiErr?.code == 'GRID_MISMATCH' ||
          msg.contains('وليس للجدول') ||
          msg.contains('_meta') ||
          msg.contains('معرّف الجدول');
      if (isMismatch) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(context.t('grid.importRejected')),
            content: Text(msg),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(context.t('common.close')),
              ),
            ],
          ),
        );
      } else {
        _snack(msg);
      }
    }
  }
  /// When [availableGroups] is set (export), the user can also pick which
  /// sections to include; [groupKeys] in the result is null when omitted.
  Future<({String from, String to, List<String>? groupKeys})?>
      _pickExcelDateRange({
    required String title,
    required String confirmLabel,
    required IconData confirmIcon,
    String? subtitle,
    List<String>? availableGroups,
    String? groupsLabel,
  }) async {
    if (!mounted) return null;
    return showDialog<({String from, String to, List<String>? groupKeys})>(
      context: context,
      builder: (ctx) => _ShiftGridExcelRangeDialog(
        title: title,
        confirmLabel: confirmLabel,
        confirmIcon: confirmIcon,
        subtitle: subtitle,
        dateFrom: _grid['dateFrom']?.toString(),
        dateTo: _grid['dateTo']?.toString(),
        availableGroups: availableGroups,
        groupsLabel: groupsLabel,
      ),
    );
  }

  bool get _canExportPunchReport {
    final state = _grid['state']?.toString() ?? '';
    return _dates.isNotEmpty && (state == 'grid' || state == 'confirmed');
  }

  bool get _isMergedGrid {
    final ids = _grid['mergedFromGridIds'];
    if (ids is List && ids.isNotEmpty) return true;
    return _grid['isMergedGrid'] == true;
  }

  Widget _mergedGridPayrollBanner() {
    if (!_isMergedGrid) return const SizedBox.shrink();
    return SellixCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.merge_type, color: AppThemeV2.primary, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t('grid.mergedMonthly'),
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.t('grid.payrollSteps'),
                    style: AppThemeV2.caption,
                  ),
                  if ((_grid['mergedFromGridIds'] as List?)?.isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        context.t('grid.mergedFrom', {'count': (_grid['mergedFromGridIds'] as List).length}),
                        style: AppThemeV2.caption,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportPunchReportExcel() async {
    try {
      await _withBlockingLoader(
        context.t('grid.generatingPunchReport'),
        () async {
          final r = await api.shiftGridPunchReportExportXlsx(widget.gridId);
          final base64 = r['base64']?.toString() ?? r['file']?.toString() ?? '';
          final filename = r['filename']?.toString() ?? 'punch_report.xlsx';
          if (base64.isEmpty) throw Exception(context.t('common.emptyFile'));
          downloadBase64File(
            base64,
            filename,
            r['mimeType']?.toString() ??
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          );
          return filename;
        },
      );
      if (!mounted) return;
      _snack(context.t('grid.punchReportDownloaded'));
    } catch (e) {
      _snack(e.toString());
    }
  }

  Future<void> _importPunchReportExcel() async {
    try {
      final base64 = await pickExcelBase64();
      if (base64 == null || base64.isEmpty) return;
      final r = await _withBlockingLoader<Map<String, dynamic>>(
        context.t('grid.importingPunchReport'),
        () => api.shiftGridPunchReportImport(widget.gridId, base64),
      );
      if (!mounted || r == null) return;
      final importId = r['importId']?.toString();
      setState(() => _punchReportImportId = importId);
      final count = r['employeeCount'] ?? 0;
      final msg = r['message']?.toString() ?? context.t('grid.importedCount', {'count': count});
      _snack(msg);
    } catch (e) {
      _snack(e.toString());
    }
  }

  Future<void> _payrollFromPunchImport() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t('grid.payrollFromPunchImport')),
        content: Text(
          _punchReportImportId == null
              ? context.t('grid.useLastImport')
              : context.t('grid.buildFromImport'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.t('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.t('common.create')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final r = await _withBlockingLoader<Map<String, dynamic>>(
        context.t('grid.creatingPayroll'),
        () => api.shiftGridPayrollFromPunchImport(
          widget.gridId,
          importId: _punchReportImportId,
        ),
      );
      if (!mounted || r == null) return;
      final payroll = r['payroll'];
      final id = payroll is Map ? payroll['id'] : null;
      _snack(r['message']?.toString() ?? context.t('grid.payrollCreated'));
      if (id != null) context.go('${AppRoutes.hrPayroll}/$id');
    } catch (e) {
      _snack(e.toString());
    }
  }

  Future<void> _exportSelectedPunches() async {
    // Make sure every employee in the grid is available for selection.
    if (_hasMoreEmployees) {
      await _withBlockingLoader(context.t('grid.loadingEmployeeList'), () async {
        await _loadAllEmployeesForSearch();
        return null;
      });
    }
    if (!mounted) return;

    final employees = <Map<String, String>>[];
    for (final entry in _jobGroups) {
      for (final emp in entry.value) {
        final id = (emp['employee_id'] ?? emp['employeeId'] ?? '').toString();
        if (id.isEmpty) continue;
        employees.add({
          'id': id,
          'name': emp['name']?.toString() ?? '',
          'code': emp['code']?.toString() ?? '',
          'job': entry.key,
        });
      }
    }
    if (employees.isEmpty) {
      _snack(context.t('grid.noEmployeesInGrid'));
      return;
    }

    final result = await showDialog<_SelectedPunchesRequest>(
      context: context,
      builder: (ctx) => _SelectPunchesDialog(
        employees: employees,
        dateFrom: _grid['dateFrom']?.toString(),
        dateTo: _grid['dateTo']?.toString(),
      ),
    );
    if (result == null || result.employeeIds.isEmpty) return;

    try {
      await _withBlockingLoader(
        context.t('grid.generatingPunchesFor', {'count': result.employeeIds.length}),
        () async {
          final r = await api.employeesPunchesExportSelectedXlsx(
            widget.gridId,
            result.employeeIds,
            dateFrom: result.dateFrom,
            dateTo: result.dateTo,
          );
          final base64 = r['base64']?.toString() ?? r['file']?.toString() ?? '';
          final filename = r['filename']?.toString() ?? 'punches_selected.xlsx';
          if (base64.isEmpty) throw Exception(context.t('common.emptyFile'));
          downloadBase64File(
            base64,
            filename,
            r['mimeType']?.toString() ??
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          );
          return filename;
        },
      );
      if (!mounted) return;
      _snack(context.t('grid.selectedPunchesDownloaded'));
    } catch (e) {
      _snack(e.toString());
    }
  }

  void _startSyncPoll() {
    _stopSyncPoll();
    _syncTimer = Timer.periodic(const Duration(seconds: 2), (_) => _pollSync());
  }

  void _stopSyncPoll() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  Future<void> _pollSync() async {
    try {
      final s = await api.shiftGridSyncStatus(widget.gridId);
      if (!mounted) return;
      setState(() {
        _syncState = s['syncState']?.toString() ?? 'idle';
        _syncProgress = (s['syncProgress'] as num?)?.toInt() ?? 0;
        _syncMessage = s['syncMessage']?.toString() ?? '';
        _syncSynced = (s['syncSyncedCount'] as num?)?.toInt() ?? 0;
        _syncTotal = (s['syncTotalCount'] as num?)?.toInt() ?? 0;
        _syncErrors = (s['syncErrorsCount'] as num?)?.toInt() ?? 0;
      });
      if (_syncState != 'syncing') {
        _stopSyncPoll();
        if (_syncState == 'done') _snack(context.t('grid.syncedPunches', {'count': _syncSynced}));
        await _load(reset: true);
      }
    } catch (_) {}
  }

  Future<void> _syncStart() async {
    if (_isBusy) return;
    try {
      setState(() {
        _syncState = 'syncing';
        _syncProgress = 0;
        _syncSynced = 0;
        _syncTotal = 0;
        _syncMessage = context.t('grid.syncStarting');
        _syncErrors = 0;
      });
      await api.shiftGridSyncStart(widget.gridId);
      if (!mounted) return;
      _startSyncPoll();
      await _pollSync();
    } catch (e) {
      if (mounted) setState(() => _syncState = 'idle');
      _snack(e.toString());
    }
  }

  Future<void> _syncCancel() async {
    try {
      await api.shiftGridSyncCancel(widget.gridId);
      _stopSyncPoll();
      setState(() => _syncState = 'idle');
      _snack(context.t('grid.syncCancelled'));
    } catch (e) {
      _snack(e.toString());
    }
  }

  Future<void> _createPayroll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t('grid.createPayroll')),
        content: Text(
          context.t('grid.createPayrollConfirm', {
            'from': _grid['dateFrom'],
            'to': _grid['dateTo'],
          }),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.t('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.t('common.create')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final payroll = await api.payrollCreate(shiftGridId: widget.gridId);
      final id = payroll['id'];
      if (!mounted) return;
      _snack(context.t('grid.payrollCreated'));
      if (id != null) context.go('${AppRoutes.hrPayroll}/$id');
    } catch (e) {
      _snack(e.toString());
    }
  }

  Future<void> _action(
    Future<Map<String, dynamic>> Function() fn, {
    bool reload = true,
  }) async {
    try {
      final r = await fn();
      if (r['grid'] is Map) _grid = Map<String, dynamic>.from(r['grid'] as Map);
      if (reload)
        await _load(reset: true);
      else if (mounted)
        setState(() {});
    } catch (e) {
      _snack(friendlyApiError(context, e));
    }
  }

  Future<bool> _confirmDanger({
    required String title,
    required String body,
    required String confirmLabel,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body, style: const TextStyle(height: 1.45)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.t('common.cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _clearAssignments() async {
    if (_locked) {
      _snack(context.t('grid.openForEditFirst'));
      return;
    }
    final ok = await _confirmDanger(
      title: context.t('grid.clearAssignments'),
      body: context.t('grid.clearAssignmentsConfirm'),
      confirmLabel: context.t('grid.clearAssignments'),
    );
    if (!ok) return;
    await _action(() => api.shiftGridClearAssignments(widget.gridId));
  }

  Future<void> _wipeEmployees() async {
    if (_locked) {
      _snack(context.t('grid.openForEditFirst'));
      return;
    }
    final ok = await _confirmDanger(
      title: context.t('grid.wipeEmployees'),
      body: context.t('grid.wipeEmployeesConfirm'),
      confirmLabel: context.t('grid.wipeEmployees'),
    );
    if (!ok) return;
    await _action(() => api.shiftGridWipeEmployees(widget.gridId));
  }

  Future<void> _deleteGrid() async {
    final ok = await _confirmDanger(
      title: context.t('grid.deleteGrid'),
      body: context.t('grid.deleteGridConfirm'),
      confirmLabel: context.t('grid.deleteGrid'),
    );
    if (!ok) return;
    try {
      final r = await api.shiftGridDelete(widget.gridId);
      if (!mounted) return;
      _snack(r['message']?.toString() ?? context.t('grid.deleteGridDone'));
      context.go(AppRoutes.hrShiftGrid);
    } catch (e) {
      if (mounted) _snack(friendlyApiError(context, e));
    }
  }

  Future<void> _editCell(
    Map<String, dynamic> emp,
    String date,
    Map<String, dynamic>? existing,
  ) async {
    if (!_canEditGrid) return;
    final cellsRaw = emp['cells'];
    final cells = cellsRaw is Map
        ? Map<String, dynamic>.from(cellsRaw)
        : <String, dynamic>{};
    emp['cells'] = cells;

    final cell = existing ??
        <String, dynamic>{
          'employee_id': emp['employee_id'] ?? emp['employeeId'],
          'date': date,
        };
    // Keep a shared map instance so the API patch lands on the visible cell.
    if (!identical(cells[date], cell)) {
      cells[date] = cell;
    }

    final value = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CellEditorSheet(
        shifts: _shifts,
        current: ShiftGridCellStyle.cellSelectValue(cell),
      ),
    );
    if (value == null) return;
    if (!await _ensureEditable()) return;
    try {
      final lineId = cell['line_id'] ?? cell['lineId'] ?? cell['id'];
      final r = await api.shiftGridUpdateCell(
        gridId: widget.gridId,
        lineId: lineId,
        employeeId: cell['employee_id'] ??
            emp['employee_id'] ??
            emp['employeeId'],
        date: date,
        cellValue: value,
      );
      if (!mounted) return;
      setState(() {
        applyShiftGridCellUpdate(cell, r, shifts: _shifts);
        cells[date] = cell;
      });
    } catch (e) {
      _snack(e.toString());
    }
  }

  Future<void> _showPunches(Map<String, dynamic> cell) async {
    try {
      final r = await _withBlockingLoader(context.t('grid.loadingPunches'), () async {
        return api.shiftGridDayPunches(
          cell['line_id'] ?? cell['lineId'] ?? cell['id'],
        );
      });
      if (!mounted || r == null) return;
      await showDialog(
        context: context,
        builder: (_) => _PunchesDialog(result: r),
      );
    } catch (e) {
      _snack(e.toString());
    }
  }

  Future<void> _bulkRow(Object employeeId) async {
    if (_bulkValue == null || _bulkValue!.isEmpty) {
      _snack(context.t('grid.pickBulkValueFirst'));
      return;
    }
    if (_bulkDateFrom == null || _bulkDateTo == null) {
      _snack(context.t('grid.pickBulkRange'));
      return;
    }
    if (!await _ensureEditable()) return;
    await _action(
      () => api.shiftGridBulkRow(
        gridId: widget.gridId,
        employeeId: employeeId,
        cellValue: _bulkValue!,
        dateFrom: _bulkDateFrom,
        dateTo: _bulkDateTo,
      ),
    );
    _snack(context.t('grid.rowUpdated'));
  }

  Future<void> _bulkColumn(String date) async {
    if (_bulkValue == null || _bulkValue!.isEmpty) {
      _snack(context.t('grid.pickBulkValueFirst'));
      return;
    }
    if (!await _ensureEditable()) return;
    await _action(
      () => api.shiftGridBulkColumn(
        gridId: widget.gridId,
        date: date,
        cellValue: _bulkValue!,
      ),
    );
    _snack(context.t('grid.columnUpdated'));
  }

  Future<void> _removeEmployee(Object employeeId, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t('grid.removeFromGrid')),
        content: Text(
          context.t('grid.removeQuestion', {'name': name}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.t('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.t('common.delete')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!await _ensureEditable()) return;
    await _action(
      () => api.shiftGridRemoveEmployee(
        gridId: widget.gridId,
        employeeId: employeeId,
      ),
    );
    _snack(context.t('grid.employeeRemoved'));
  }

  Future<void> _transferEmployee(Object employeeId, String name) async {
    if (!await _ensureEditable()) return;

    final grids = await api.shiftGridList(limit: 100);
    final others = grids
        .where((g) => g['id']?.toString() != widget.gridId.toString())
        .where((g) => g['state']?.toString() != 'confirmed')
        .toList();
    if (!mounted) return;
    if (others.isEmpty) {
      _snack(context.t('grid.noOtherGrids'));
      return;
    }

    String? selectedId = others.first['id']?.toString();
    var saving = false;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
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
                context.t('grid.transferTitle'),
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: others.length,
                  itemBuilder: (_, i) {
                    final g = others[i];
                    final id = g['id']?.toString() ?? '';
                    final title = g['name']?.toString() ?? id;
                    final loc = g['locationName']?.toString() ?? '';
                    final range =
                        '${g['dateFrom'] ?? ''} → ${g['dateTo'] ?? ''}';
                    return RadioListTile<String>(
                      value: id,
                      groupValue: selectedId,
                      onChanged: saving
                          ? null
                          : (v) => setSheetState(() => selectedId = v),
                      title: Text(title),
                      subtitle: Text(
                        [loc, range].where((s) => s.isNotEmpty).join('  •  '),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: saving || selectedId == null
                    ? null
                    : () async {
                        setSheetState(() => saving = true);
                        try {
                          await api.shiftGridTransferEmployee(
                            gridId: widget.gridId,
                            targetGridId: selectedId!,
                            employeeId: employeeId,
                          );
                          if (ctx.mounted) Navigator.pop(ctx, true);
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text(e.toString())),
                            );
                            setSheetState(() => saving = false);
                          }
                        }
                      },
                icon: const Icon(Icons.send),
                label: Text(
                  saving ? context.t('grid.transferring') : context.t('grid.transferSend'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (ok == true && mounted) {
      _snack(context.t('grid.employeeTransferred'));
      await _load(reset: true);
    }
  }

  Future<void> _addEmployee() async {
    final locationId = _grid['locationId']?.toString();
    final selected = await showDialog<List<String>>(
      context: context,
      builder: (ctx) => _AddEmployeesDialog(
        gridId: widget.gridId.toString(),
        locationId: locationId,
      ),
    );
    if (selected == null || selected.isEmpty) return;
    if (!await _ensureEditable()) return;
    await _action(
      () => api.shiftGridAddEmployees(
        gridId: widget.gridId,
        employeeIds: selected,
      ),
    );
    _snack(context.t('grid.employeesAdded', {'count': selected.length}));
  }

  String _localizedStateLabel(BuildContext context, String state) =>
      switch (state) {
        'setup' => context.t('grid.state.setup'),
        'grid' => context.t('grid.state.grid'),
        'confirmed' => context.t('grid.state.confirmed'),
        _ => stateLabel(state),
      };

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: _ShiftGridLoadSkeleton(),
      );
    }

    final empCount = _grid['employeeCount'] ?? _data['employee_count'] ?? 0;
    final daysCount = _grid['daysCount'] ?? _data['days_count'] ?? 0;
    final isHr = context.watch<AuthCubit>().state.roles.isHrStaff;
    final locationLabel = _grid['locationName']?.toString().isNotEmpty == true
        ? context.t('grid.fingerprint', {'name': _grid['locationName']})
        : (_grid['deviceName']?.toString().isNotEmpty == true
              ? context.t('grid.fingerprint', {'name': _grid['deviceName']})
              : '');
    // Sticky: رقم + كود + اسم. Scrollable: وظيفة + أيام.
    final scrollWidth = _kColJob + _dates.length * _kColDate;
    final visibleRows = _buildVisibleFlatRows();
    final visibleEmpCount = visibleRows.where((r) => !r.isHeader).length;
    final searching = _searchQuery.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: CustomScrollView(
        controller: _scrollCtrl,
        slivers: [
          SliverToBoxAdapter(
            child: PageHeader(
              title: _grid['name']?.toString() ?? context.t('grid.detail'),
              icon: Icons.grid_view_rounded,
              subtitle: [
                if (locationLabel.isNotEmpty) locationLabel,
                context.t('grid.dateRange', {
                  'from': _grid['dateFrom'],
                  'to': _grid['dateTo'],
                }),
                if (empCount != 0 && daysCount != 0)
                  context.t('grid.empDaysCount', {
                    'emp': empCount,
                    'days': daysCount,
                  }),
                if (searching && visibleEmpCount > 0)
                  context.t('grid.searchResultsCount', {'n': visibleEmpCount}),
                if (!searching && _flatRows.isNotEmpty && empCount != 0)
                  context.t('grid.showingCount', {
                    'shown': _flatRows.where((r) => !r.isHeader).length,
                    'total': empCount,
                  }),
                _localizedStateLabel(context, _grid['state']?.toString() ?? ''),
              ].join('  •  '),
              actions: [
                if (!_isSetup)
                  PopupMenuButton<String>(
                    tooltip: context.t('grid.groupBy'),
                    icon: const Icon(Icons.account_tree_outlined),
                    initialValue: _grouping,
                    onSelected: (value) {
                      if (value == 'sheetPerDepartment') {
                        // Export-only: no reload, the grid on screen is unchanged.
                        setState(() => _sheetPerDepartment = !_sheetPerDepartment);
                        return;
                      }
                      if (value == _grouping) return;
                      setState(() => _grouping = value);
                      _load(reset: true);
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'job',
                        child: Text(context.t('grid.groupByJob')),
                      ),
                      PopupMenuItem(
                        value: 'department',
                        child: Text(context.t('grid.groupByDepartment')),
                      ),
                      if (_grouping == 'department') const PopupMenuDivider(),
                      if (_grouping == 'department')
                        CheckedPopupMenuItem(
                          value: 'sheetPerDepartment',
                          checked: _sheetPerDepartment,
                          child: Text(context.t('grid.sheetPerDepartment')),
                        ),
                    ],
                  ),
                IconButton(
                  onPressed: _isBusy ? null : () => _load(reset: true),
                  icon: const Icon(Icons.refresh),
                ),
              ],
              onBack: () => context.go(AppRoutes.hrShiftGrid),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          SliverToBoxAdapter(
            child: _StateBar(state: _grid['state']?.toString() ?? ''),
          ),
          if (_isMergedGrid && !_isSetup)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _mergedGridPayrollBanner(),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          if (_isSetup && _canEditGrid)
            SliverToBoxAdapter(
              child: ShiftGridSetupPanel(
                grid: _grid,
                onGenerated: () => _load(reset: true),
              ),
            )
          else if (!_isSetup) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                      value: 'grid',
                      label: Text(context.t('grid.manualOtGridTab')),
                      icon: const Icon(Icons.grid_on_outlined, size: 18),
                    ),
                    ButtonSegment(
                      value: 'manualOt',
                      label: Text(context.t('grid.manualOtTab')),
                      icon: const Icon(Icons.more_time, size: 18),
                    ),
                  ],
                  selected: {_detailTab},
                  onSelectionChanged: (s) async {
                    final next = s.first;
                    if (next == 'manualOt' && _hasMoreEmployees) {
                      await _withBlockingLoader(
                        context.t('grid.loadingEmployees'),
                        () async {
                          await _loadAllEmployeesForSearch();
                          return null;
                        },
                      );
                    }
                    if (!mounted) return;
                    setState(() => _detailTab = next);
                  },
                ),
              ),
            ),
            if (_detailTab == 'manualOt')
              SliverToBoxAdapter(
                child: SellixCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: ShiftGridManualOtPanel(
                      gridId: widget.gridId,
                      dateFrom: _grid['dateFrom']?.toString() ?? '',
                      dateTo: _grid['dateTo']?.toString() ?? '',
                      readOnly: !_canEditGrid,
                      employees: [
                        for (final entry in _jobGroups)
                          for (final emp in entry.value)
                            if ((emp['employee_id'] ?? emp['employeeId'] ?? '')
                                .toString()
                                .isNotEmpty)
                              {
                                'id': (emp['employee_id'] ?? emp['employeeId'])
                                    .toString(),
                                'name': emp['name']?.toString() ?? '',
                                'code': emp['code']?.toString() ?? '',
                                'job': entry.key,
                              },
                      ],
                    ),
                  ),
                ),
              )
            else ...[
            if (_canEditGrid)
              SliverToBoxAdapter(
                child: SellixCard(
                  child: _ActionBar(
                    disabled: _isBusy,
                    onSync: _syncStart,
                    onExport: _dates.isNotEmpty && !_isBusy
                        ? _exportExcel
                        : null,
                    onExportDepartmentsSeparated:
                        _dates.isNotEmpty && !_isBusy
                        ? _exportAllDepartmentsSeparated
                        : null,
                    onImport: _dates.isNotEmpty && !_isBusy && !_locked
                        ? _importExcel
                        : null,
                    onExportPunchReport: _canExportPunchReport && !_isBusy
                        ? _exportPunchReportExcel
                        : null,
                    onImportPunchReport: isHr && _canExportPunchReport && !_isBusy
                        ? _importPunchReportExcel
                        : null,
                    onPayrollFromPunchImport:
                        isHr && _canExportPunchReport && !_isBusy
                        ? _payrollFromPunchImport
                        : null,
                    onExportSelectedPunches: _canExportPunchReport && !_isBusy
                        ? _exportSelectedPunches
                        : null,
                    onBackToSetup: _locked || _isBusy
                        ? null
                        : () => _action(
                            () => api.shiftGridBackToSetup(widget.gridId),
                          ),
                    onResyncDates: _locked || _isBusy
                        ? null
                        : () => _action(
                            () => api.shiftGridResyncDates(widget.gridId),
                          ),
                    onConfirmAssignments: _locked || _isBusy
                        ? null
                        : () => _action(
                            () => api.shiftGridConfirm(widget.gridId),
                          ),
                    onClose: _locked || _isBusy
                        ? null
                        : () =>
                              _action(() => api.shiftGridClose(widget.gridId)),
                    onReopen: !_locked || _isBusy
                        ? null
                        : () =>
                              _action(() => api.shiftGridReopen(widget.gridId)),
                    onCreatePayroll: isHr && _dates.isNotEmpty && !_isBusy
                        ? _createPayroll
                        : null,
                    onShowUntracked: _untrackedImportUsers.isNotEmpty
                        ? () => showShiftGridUntrackedUsersPanel(
                            context,
                            users: _untrackedImportUsers,
                            importMessage: _lastImportMessage,
                          )
                        : null,
                    untrackedCount: _untrackedImportUsers.length,
                    onClearAssignments: !_locked && !_isBusy
                        ? _clearAssignments
                        : null,
                    onWipeEmployees: !_locked && !_isBusy
                        ? _wipeEmployees
                        : null,
                    onDeleteGrid: !_isBusy ? _deleteGrid : null,
                  ),
                ),
              ),
            if (_syncState == 'syncing') ...[
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              SliverToBoxAdapter(
                child: _SyncOverlay(
                  progress: _syncProgress,
                  message: _syncMessage,
                  synced: _syncSynced,
                  total: _syncTotal,
                  errors: _syncErrors,
                  onCancel: _syncCancel,
                ),
              ),
            ],
            if (_syncState == 'done' || _syncState == 'error') ...[
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              SliverToBoxAdapter(
                child: _SyncResultBanner(
                  state: _syncState,
                  message: _syncMessage,
                  synced: _syncSynced,
                  errors: _syncErrors,
                  onDismiss: () async {
                    await api.shiftGridSyncReset(widget.gridId);
                    setState(() => _syncState = 'idle');
                  },
                ),
              ),
            ],
            if (_untrackedImportUsers.isNotEmpty &&
                _untrackedBannerVisible) ...[
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              SliverToBoxAdapter(
                child: ShiftGridImportUntrackedBanner(
                  users: _untrackedImportUsers,
                  importMessage: _lastImportMessage,
                  onShowDetails: () => showShiftGridUntrackedUsersPanel(
                    context,
                    users: _untrackedImportUsers,
                    importMessage: _lastImportMessage,
                  ),
                  onDismiss: () =>
                      setState(() => _untrackedBannerVisible = false),
                ),
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            if (_dates.isEmpty)
              SliverToBoxAdapter(
                child: SellixCard(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(context.t('grid.noData')),
                  ),
                ),
              )
            else ...[
              SliverToBoxAdapter(
                child: _BulkBar(
                  shifts: _shifts,
                  locked: !_canEditGrid,
                  value: _bulkValue,
                  gridDateFrom: _grid['dateFrom']?.toString(),
                  gridDateTo: _grid['dateTo']?.toString(),
                  bulkDateFrom: _bulkDateFrom,
                  bulkDateTo: _bulkDateTo,
                  onChanged: _isBusy
                      ? null
                      : (v) => setState(() => _bulkValue = v),
                  onBulkDateFromChanged: _isBusy
                      ? null
                      : (v) => setState(() {
                          _bulkDateFrom = v;
                          if (_bulkDateTo != null &&
                              v != null &&
                              v.compareTo(_bulkDateTo!) > 0) {
                            _bulkDateTo = v;
                          }
                        }),
                  onBulkDateToChanged: _isBusy
                      ? null
                      : (v) => setState(() {
                          _bulkDateTo = v;
                          if (_bulkDateFrom != null &&
                              v != null &&
                              v.compareTo(_bulkDateFrom!) < 0) {
                            _bulkDateFrom = v;
                          }
                        }),
                  onAddEmployee: _canEditGrid ? _addEmployee : null,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              SliverToBoxAdapter(
                child: _GridSearchBar(controller: _searchCtrl),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              SliverToBoxAdapter(
                child: _GridHorizontalScrollBar(
                  linker: _horizontalScrollLinker,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              SliverPersistentHeader(
                pinned: true,
                delegate: _StickyGridHeaderDelegate(
                  scrollWidth: scrollWidth,
                  dates: _dates,
                  horizontalController: _headerHorizontalScroll,
                  onBulkColumn: _canEditGrid ? _bulkColumn : null,
                ),
              ),
              if (visibleRows.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(context.t('grid.noSearchResults')),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index >= visibleRows.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      }
                      final row = visibleRows[index];
                      if (row.isHeader) {
                        return Row(
                          children: [
                            Container(
                              width: _kStickyColsWidth,
                              color: const Color(0xFFF0C040),
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              alignment: Alignment.center,
                              child: Text(
                                row.jobTitle!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Expanded(
                              child: ClipRect(
                                child: SyncHorizontalScrollView(
                                  linker: _horizontalScrollLinker,
                                  width: scrollWidth,
                                  child: Container(
                                    color: const Color(0xFFF0C040),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 6,
                                    ),
                                    alignment: Alignment.center,
                                    child: const SizedBox.shrink(),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      }
                      return _GridEmployeeRow(
                        emp: row.employee!,
                        rowNum: row.rowNum,
                        dates: _dates,
                        scrollWidth: scrollWidth,
                        linker: _horizontalScrollLinker,
                        locked: !_canEditGrid,
                        onBulkRow: _bulkRow,
                        onRemove: _removeEmployee,
                        onTransfer: _transferEmployee,
                        onEditCell: _editCell,
                        onShowPunches: _showPunches,
                      );
                    },
                    childCount:
                        visibleRows.length +
                        (_loadingMore && !searching ? 1 : 0),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ],
            ],
          ],
        ],
      ),
    );
  }
}

const double _kColNum = 40;
const double _kColCode = 56;
const double _kColName = 280;
const double _kColJob = 90;
const double _kColDate = 70;
/// رقم + كود + اسم — ثابتة جنب الشاشة أثناء السكرول الأفقي.
const double _kStickyColsWidth = _kColNum + _kColCode + _kColName;

class _FlatGridRow {
  _FlatGridRow.header(this.jobTitle) : employee = null, rowNum = 0;
  _FlatGridRow.employee(this.employee, this.rowNum) : jobTitle = null;

  final String? jobTitle;
  final Map<String, dynamic>? employee;
  final int rowNum;
  bool get isHeader => jobTitle != null;
}

class _GridHeaderRow extends StatelessWidget {
  const _GridHeaderRow({required this.dates, this.onBulkColumn});

  final List<Map<String, dynamic>> dates;
  final void Function(String date)? onBulkColumn;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _hdr(context.t('grid.jobColumn'), width: _kColJob, light: true),
        for (final d in dates)
          _dateHdr(
            d,
            onBulk: onBulkColumn == null
                ? null
                : () => onBulkColumn!(d['date'].toString()),
          ),
      ],
    );
  }
}

class _GridEmployeeRow extends StatelessWidget {
  const _GridEmployeeRow({
    required this.emp,
    required this.rowNum,
    required this.dates,
    required this.scrollWidth,
    required this.linker,
    required this.locked,
    required this.onBulkRow,
    required this.onRemove,
    required this.onTransfer,
    required this.onEditCell,
    required this.onShowPunches,
  });

  final Map<String, dynamic> emp;
  final int rowNum;
  final List<Map<String, dynamic>> dates;
  final double scrollWidth;
  final HorizontalScrollLinker linker;
  final bool locked;
  final Future<void> Function(Object employeeId) onBulkRow;
  final Future<void> Function(Object employeeId, String name) onRemove;
  final Future<void> Function(Object employeeId, String name) onTransfer;
  final Future<void> Function(
    Map<String, dynamic> emp,
    String date,
    Map<String, dynamic>? cell,
  ) onEditCell;
  final Future<void> Function(Map<String, dynamic> cell) onShowPunches;

  bool get _canRemove {
    if (emp['can_remove'] == true) return true;
    final cells = emp['cells'];
    if (cells is! Map) return true;
    for (final raw in cells.values) {
      if (raw is! Map) continue;
      final cell = Map<String, dynamic>.from(raw);
      final shiftId = cell['shift_id'];
      if (shiftId != null && shiftId != false) return false;
      if (cell['is_off'] == true ||
          cell['is_sick'] == true ||
          cell['is_annual_leave'] == true ||
          cell['is_excluded'] == true ||
          cell['is_bus_delay'] == true ||
          cell['is_present'] == true ||
          cell['is_finished'] == true ||
          cell['is_resignation'] == true ||
          cell['is_work_absence'] == true ||
          cell['is_work_injury'] == true ||
          cell['is_marriage_leave'] == true) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final employeeId = emp['employee_id'] ?? emp['employeeId'] ?? '';
    final name = emp['name']?.toString() ?? '';
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: _kStickyColsWidth,
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 4,
                  offset: const Offset(-2, 0),
                ),
              ],
            ),
            child: Row(
              children: [
                SizedBox(
                  width: _kColNum,
                  child: Center(
                    child: Text(
                      '$rowNum',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ),
                SizedBox(
                  width: _kColCode,
                  child: Text(
                    emp['code']?.toString() ?? '',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                SizedBox(
                  width: _kColName,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          emp['name']?.toString() ?? '',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          softWrap: true,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!locked)
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
                          icon: const Icon(Icons.play_arrow, size: 16),
                          tooltip: context.t('grid.bulkRow'),
                          onPressed: () => onBulkRow(employeeId),
                        ),
                      if (!locked)
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
                          icon: Icon(
                            Icons.share_outlined,
                            size: 16,
                            color: Colors.blue.shade700,
                          ),
                          tooltip: context.t('grid.transferEmployee'),
                          onPressed: () => onTransfer(employeeId, name),
                        ),
                      if (!locked && _canRemove)
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
                          icon: const Icon(
                            Icons.person_remove_outlined,
                            size: 16,
                            color: Colors.red,
                          ),
                          tooltip: context.t('grid.removeFromGridNoShifts'),
                          onPressed: () => onRemove(employeeId, name),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ClipRect(
              child: SyncHorizontalScrollView(
                linker: linker,
                width: scrollWidth,
                child: Row(
                  children: [
                    SizedBox(
                      width: _kColJob,
                      child: Text(
                        emp['job_title']?.toString() ?? '',
                        style: const TextStyle(fontSize: 10),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    for (final d in dates)
                      _gridCellWidget(
                        emp,
                        d['date'].toString(),
                        d['is_friday'] == true,
                        locked,
                        onEditCell,
                        onShowPunches,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _gridCellWidget(
  Map<String, dynamic> emp,
  String date,
  bool isFriday,
  bool locked,
  Future<void> Function(
    Map<String, dynamic> emp,
    String date,
    Map<String, dynamic>? cell,
  ) onEditCell,
  Future<void> Function(Map<String, dynamic> cell) onShowPunches,
) {
  final cells = emp['cells'];
  final raw = cells is Map ? cells[date] : null;
  final cell = raw is Map<String, dynamic>
      ? raw
      : (raw is Map ? Map<String, dynamic>.from(raw) : null);
  final style = ShiftGridCellStyle.forCell(cell, isFriday: isFriday);
  final label = ShiftGridCellStyle.displayLabel(cell);

  return GestureDetector(
    onTap: locked ? null : () => onEditCell(emp, date, cell),
    onLongPress: locked || cell == null ? null : () => onShowPunches(cell),
    child: MouseRegion(
      cursor: locked ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: Container(
        width: 70,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: style.background,
          border: Border.all(
            color: AppColors.border.withValues(alpha: 0.4),
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: style.fontWeight,
            color: style.foreground,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ),
  );
}

Widget _hdr(String text, {double? width, bool light = false}) {
  return Container(
    width: width,
    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Colors.white,
        fontSize: light ? 11 : 13,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

Widget _dateHdr(Map<String, dynamic> d, {VoidCallback? onBulk}) {
  final isFriday = d['is_friday'] == true;
  return Container(
    width: 70,
    padding: const EdgeInsets.all(4),
    color: isFriday ? const Color(0xFF4A5568) : null,
    child: Column(
      children: [
        Text(
          d['day_name']?.toString() ?? '',
          style: TextStyle(
            fontSize: 9,
            color: isFriday ? const Color(0xFFFFD700) : Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          '${d['day_num']}-${d['month_name']}',
          style: TextStyle(
            fontSize: 10,
            color: isFriday ? const Color(0xFFFFD700) : Colors.white,
          ),
        ),
        if (onBulk != null)
          InkWell(
            onTap: onBulk,
            child: const Icon(
              Icons.arrow_drop_down,
              color: Colors.white70,
              size: 16,
            ),
          ),
      ],
    ),
  );
}

class _StateBar extends StatelessWidget {
  const _StateBar({required this.state});
  final String state;

  @override
  Widget build(BuildContext context) {
    final steps = ['setup', 'grid', 'confirmed'];
    final labels = [
      context.t('grid.state.setup'),
      context.t('grid.state.grid'),
      context.t('grid.state.confirmed'),
    ];
    final current = steps.indexOf(state).clamp(0, 2);

    return SellixCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Row(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            if (i > 0)
              Expanded(
                child: Container(
                  height: 2,
                  color: i <= current ? AppThemeV2.primary : AppThemeV2.border,
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: i == current ? AppThemeV2.primaryGradient : null,
                color: i == current ? null : AppThemeV2.surfaceElevated,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: i == current ? Colors.transparent : AppThemeV2.border,
                ),
              ),
              child: Text(
                labels[i],
                style: AppThemeV2.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: i == current ? Colors.white : AppThemeV2.textSecondary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.disabled,
    required this.onSync,
    this.onBackToSetup,
    this.onResyncDates,
    this.onConfirmAssignments,
    this.onClose,
    this.onReopen,
    this.onCreatePayroll,
    this.onExport,
    this.onExportDepartmentsSeparated,
    this.onImport,
    this.onExportPunchReport,
    this.onImportPunchReport,
    this.onPayrollFromPunchImport,
    this.onExportSelectedPunches,
    this.onShowUntracked,
    this.onClearAssignments,
    this.onWipeEmployees,
    this.onDeleteGrid,
    this.untrackedCount = 0,
  });

  final bool disabled;
  final VoidCallback? onSync;
  final VoidCallback? onBackToSetup;
  final VoidCallback? onResyncDates;
  final VoidCallback? onConfirmAssignments;
  final VoidCallback? onClose;
  final VoidCallback? onReopen;
  final VoidCallback? onCreatePayroll;
  final VoidCallback? onExport;
  final VoidCallback? onExportDepartmentsSeparated;
  final VoidCallback? onImport;
  final VoidCallback? onExportPunchReport;
  final VoidCallback? onImportPunchReport;
  final VoidCallback? onPayrollFromPunchImport;
  final VoidCallback? onExportSelectedPunches;
  final VoidCallback? onShowUntracked;
  final VoidCallback? onClearAssignments;
  final VoidCallback? onWipeEmployees;
  final VoidCallback? onDeleteGrid;
  final int untrackedCount;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (onBackToSetup != null)
          OutlinedButton.icon(
            onPressed: disabled ? null : onBackToSetup,
            icon: const Icon(Icons.settings_backup_restore, size: 18),
            label: Text(context.t('grid.backToSetup')),
          ),
        if (onResyncDates != null)
          OutlinedButton.icon(
            onPressed: disabled ? null : onResyncDates,
            icon: const Icon(Icons.date_range_outlined, size: 18),
            label: Text(context.t('grid.adjustDays')),
          ),
        if (onConfirmAssignments != null)
          FilledButton.tonalIcon(
            onPressed: disabled ? null : onConfirmAssignments,
            icon: const Icon(Icons.assignment_turned_in_outlined, size: 18),
            label: Text(context.t('grid.confirmAssignments')),
          ),
        if (onClose != null)
          OutlinedButton.icon(
            onPressed: disabled ? null : onClose,
            icon: const Icon(Icons.lock_outline, size: 18),
            label: Text(context.t('grid.closeGrid')),
          ),
        if (onReopen != null)
          OutlinedButton.icon(
            onPressed: disabled ? null : onReopen,
            icon: const Icon(Icons.lock_open_outlined, size: 18),
            label: Text(context.t('grid.reopenGrid')),
          ),
        FilledButton.icon(
          onPressed: disabled ? null : onSync,
          icon: const Icon(Icons.sync, size: 18),
          label: Text(context.t('grid.syncPunches')),
        ),
        if (onExportPunchReport != null)
          FilledButton.icon(
            onPressed: disabled ? null : onExportPunchReport,
            icon: const Icon(Icons.description_outlined, size: 18),
            label: Text(context.t('grid.punchReportExcel')),
          ),
        if (onImportPunchReport != null)
          OutlinedButton.icon(
            onPressed: disabled ? null : onImportPunchReport,
            icon: const Icon(Icons.upload_file_outlined, size: 18),
            label: Text(context.t('grid.importPunchReport')),
          ),
        if (onPayrollFromPunchImport != null)
          FilledButton.tonalIcon(
            onPressed: disabled ? null : onPayrollFromPunchImport,
            icon: const Icon(Icons.calculate_outlined, size: 18),
            label: Text(context.t('grid.payrollFromPunchImport')),
          ),
        if (onExportSelectedPunches != null)
          OutlinedButton.icon(
            onPressed: disabled ? null : onExportSelectedPunches,
            icon: const Icon(Icons.fact_check_outlined, size: 18),
            label: Text(context.t('grid.selectedPunchesExcel')),
          ),
        if (onExport != null)
          OutlinedButton.icon(
            onPressed: disabled ? null : onExport,
            icon: const Icon(Icons.download, size: 18),
            label: Text(context.t('grid.exportExcel')),
          ),
        if (onExportDepartmentsSeparated != null)
          OutlinedButton.icon(
            onPressed: disabled ? null : onExportDepartmentsSeparated,
            icon: const Icon(Icons.folder_zip_outlined, size: 18),
            label: Text(context.t('grid.exportDepartmentsSeparated')),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppThemeV2.primary,
              side: const BorderSide(color: AppThemeV2.primary),
            ),
          ),
        if (onImport != null)
          OutlinedButton.icon(
            onPressed: disabled ? null : onImport,
            icon: const Icon(Icons.upload_file, size: 18),
            label: Text(context.t('grid.importExcel')),
          ),
        if (onShowUntracked != null)
          OutlinedButton.icon(
            onPressed: disabled ? null : onShowUntracked,
            icon: const Icon(Icons.person_off_outlined, size: 18),
            label: Text(
              context.t('grid.untrackedUsersReopen', {'n': untrackedCount}),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFE65100),
              side: const BorderSide(color: Color(0xFFE65100)),
            ),
          ),
        if (onCreatePayroll != null)
          FilledButton.tonalIcon(
            onPressed: disabled ? null : onCreatePayroll,
            icon: const Icon(Icons.payments_outlined, size: 18),
            label: Text(context.t('grid.payrollSheet')),
          ),
        if (onClearAssignments != null)
          OutlinedButton.icon(
            onPressed: disabled ? null : onClearAssignments,
            icon: const Icon(Icons.layers_clear_outlined, size: 18),
            label: Text(context.t('grid.clearAssignments')),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFE65100),
              side: const BorderSide(color: Color(0xFFE65100)),
            ),
          ),
        if (onWipeEmployees != null)
          OutlinedButton.icon(
            onPressed: disabled ? null : onWipeEmployees,
            icon: const Icon(Icons.group_off_outlined, size: 18),
            label: Text(context.t('grid.wipeEmployees')),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.danger),
            ),
          ),
        if (onDeleteGrid != null)
          FilledButton.tonalIcon(
            onPressed: disabled ? null : onDeleteGrid,
            icon: const Icon(Icons.delete_forever_outlined, size: 18),
            label: Text(context.t('grid.deleteGrid')),
            style: FilledButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: AppColors.danger,
            ),
          ),
      ],
    );
  }
}

class _GridHorizontalScrollBar extends StatefulWidget {
  const _GridHorizontalScrollBar({required this.linker});

  final HorizontalScrollLinker linker;

  @override
  State<_GridHorizontalScrollBar> createState() => _GridHorizontalScrollBarState();
}

class _GridHorizontalScrollBarState extends State<_GridHorizontalScrollBar> {
  static const _step = 280.0;
  double _value = 0;
  double _max = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncFromLinker());
  }

  void _syncFromLinker() {
    if (!mounted) return;
    setState(() {
      _max = widget.linker.maxExtent;
      _value = widget.linker.offset.clamp(0.0, _max > 0 ? _max : 0.0);
    });
  }

  void _nudge(double delta) {
    widget.linker.scrollBy(delta);
    _syncFromLinker();
  }

  void _seek(double value) {
    widget.linker.jumpTo(value);
    _syncFromLinker();
  }

  @override
  Widget build(BuildContext context) {
    // Re-read extents when the grid remounts / dates change.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final max = widget.linker.maxExtent;
      final value = widget.linker.offset.clamp(0.0, max > 0 ? max : 0.0);
      if (!mounted) return;
      if ((max - _max).abs() > 0.5 || (value - _value).abs() > 0.5) {
        setState(() {
          _max = max;
          _value = value;
        });
      }
    });

    if (_max <= 0) {
      return const SizedBox.shrink();
    }

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            IconButton(
              tooltip: context.t('grid.scrollRight'),
              onPressed: () => _nudge(-_step),
              icon: const Icon(Icons.chevron_right),
              visualDensity: VisualDensity.compact,
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                ),
                child: Slider(
                  value: _value.clamp(0.0, _max),
                  max: _max,
                  onChanged: _seek,
                ),
              ),
            ),
            IconButton(
              tooltip: context.t('grid.scrollLeft'),
              onPressed: () => _nudge(_step),
              icon: const Icon(Icons.chevron_left),
              visualDensity: VisualDensity.compact,
            ),
            Text(
              context.t('grid.scrollHorizontally'),
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridSearchBar extends StatelessWidget {
  const _GridSearchBar({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppThemeV2.surfaceElevated,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppThemeV2.border.withValues(alpha: 0.9)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            return TextField(
              controller: controller,
              style: AppThemeV2.body.copyWith(fontSize: 14),
              decoration: InputDecoration(
                hintText: context.t('grid.searchHint'),
                hintStyle: AppThemeV2.caption.copyWith(
                  color: AppThemeV2.textMuted,
                ),
                filled: true,
                fillColor: AppThemeV2.surfaceElevated,
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 22,
                  color: AppThemeV2.primary,
                ),
                suffixIcon: value.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          controller.clear();
                          FocusScope.of(context).unfocus();
                        },
                      ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 14,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StickyGridHeaderDelegate extends SliverPersistentHeaderDelegate {
  _StickyGridHeaderDelegate({
    required this.scrollWidth,
    required this.dates,
    required this.horizontalController,
    this.onBulkColumn,
  });

  final double scrollWidth;
  final List<Map<String, dynamic>> dates;
  final ScrollController horizontalController;
  final void Function(String date)? onBulkColumn;

  @override
  double get minExtent => 52;

  @override
  double get maxExtent => 52;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      elevation: overlapsContent ? 2 : 0,
      color: Theme.of(context).cardColor,
      child: Row(
        children: [
          Container(
            width: _kStickyColsWidth,
            height: maxExtent,
            decoration: BoxDecoration(
              gradient: AppThemeV2.primaryGradient,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 4,
                  offset: const Offset(-2, 0),
                ),
              ],
            ),
            child: Row(
              children: [
                _hdr(context.t('grid.numberColumn'), width: _kColNum, light: true),
                _hdr(context.t('common.code'), width: _kColCode, light: true),
                _hdr(context.t('common.name'), width: _kColName, light: true),
              ],
            ),
          ),
          Expanded(
            child: ClipRect(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                controller: horizontalController,
                child: Container(
                  width: scrollWidth,
                  height: maxExtent,
                  decoration: const BoxDecoration(
                    gradient: AppThemeV2.primaryGradient,
                  ),
                  child: _GridHeaderRow(
                    dates: dates,
                    onBulkColumn: onBulkColumn,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _StickyGridHeaderDelegate oldDelegate) {
    return oldDelegate.scrollWidth != scrollWidth ||
        oldDelegate.dates != dates ||
        oldDelegate.horizontalController != horizontalController ||
        oldDelegate.onBulkColumn != onBulkColumn;
  }
}

class _BulkBar extends StatelessWidget {
  const _BulkBar({
    required this.shifts,
    required this.locked,
    required this.value,
    this.gridDateFrom,
    this.gridDateTo,
    this.bulkDateFrom,
    this.bulkDateTo,
    required this.onChanged,
    this.onBulkDateFromChanged,
    this.onBulkDateToChanged,
    this.onAddEmployee,
  });

  final List<Map<String, dynamic>> shifts;
  final bool locked;
  final String? value;
  final String? gridDateFrom;
  final String? gridDateTo;
  final String? bulkDateFrom;
  final String? bulkDateTo;
  final ValueChanged<String?>? onChanged;
  final ValueChanged<String?>? onBulkDateFromChanged;
  final ValueChanged<String?>? onBulkDateToChanged;
  final VoidCallback? onAddEmployee;

  DateTime? _parseDate(String? s) {
    if (s == null || s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  Future<void> _pickDate(
    BuildContext context, {
    required String? current,
    required ValueChanged<String?>? onChanged,
    DateTime? min,
    DateTime? max,
  }) async {
    if (onChanged == null) return;
    final initial = _parseDate(current) ?? min ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: min ?? DateTime(2000),
      lastDate: max ?? DateTime(2100),
    );
    if (picked != null) {
      final iso =
          '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      onChanged(iso);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gridMin = _parseDate(gridDateFrom);
    final gridMax = _parseDate(gridDateTo);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (onAddEmployee != null)
                  OutlinedButton.icon(
                    onPressed: onAddEmployee,
                    icon: const Icon(Icons.person_add, size: 18),
                    label: Text(context.t('grid.addEmployees')),
                  ),
              ],
            ),
            if (!locked) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    context.t('grid.bulkAssign'),
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: value,
                      onChanged: locked ? null : onChanged,
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                      ),
                      hint: Text(
                        context.t('grid.pickValue'),
                        overflow: TextOverflow.ellipsis,
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'off',
                          child: Text(
                            context.t('shiftGrid.cell.off'),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'present',
                          child: Text(context.t('shiftGrid.cell.present'), overflow: TextOverflow.ellipsis),
                        ),
                        DropdownMenuItem(
                          value: 'sick',
                          child: Text(
                            context.t('shiftGrid.cell.sick'),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'annual',
                          child: Text(
                            context.t('shiftGrid.cell.annual'),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'excluded',
                          child: Text(
                            context.t('shiftGrid.cell.excluded'),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'bus_delay',
                          child: Text(
                            context.t('shiftGrid.cell.busDelay'),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'finished',
                          child: Text(
                            context.t('shiftGrid.cell.finished'),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'resignation',
                          child: Text(
                            context.t('shiftGrid.cell.resignation'),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'work_absence',
                          child: Text(
                            context.t('shiftGrid.cell.absence'),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'work_injury',
                          child: Text(
                            context.t('shiftGrid.cell.injury'),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'marriage',
                          child: Text(
                            context.t('shiftGrid.cell.marriage'),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        for (final s in shifts)
                          DropdownMenuItem(
                            value: s['id'].toString(),
                            child: Text(
                              '${s['code']} - ${s['name']}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        for (final s in shifts)
                          DropdownMenuItem(
                            value: 'bus_${s['id']}',
                            child: Text(
                              '${s['code']} 🚌',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (gridMin != null && gridMax != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      context.t('grid.periodLabel'),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onBulkDateFromChanged == null
                            ? null
                            : () => _pickDate(
                                context,
                                current: bulkDateFrom,
                                onChanged: onBulkDateFromChanged,
                                min: gridMin,
                                max: _parseDate(bulkDateTo) ?? gridMax,
                              ),
                        child: Text(
                          bulkDateFrom ?? context.t('common.from'),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        '—',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onBulkDateToChanged == null
                            ? null
                            : () => _pickDate(
                                context,
                                current: bulkDateTo,
                                onChanged: onBulkDateToChanged,
                                min: _parseDate(bulkDateFrom) ?? gridMin,
                                max: gridMax,
                              ),
                        child: Text(
                          bulkDateTo ?? context.t('common.to'),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 4),
              Text(
                context.t('grid.bulkHint'),
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SyncOverlay extends StatelessWidget {
  const _SyncOverlay({
    required this.progress,
    required this.message,
    required this.synced,
    required this.total,
    required this.errors,
    required this.onCancel,
  });

  final int progress;
  final String message;
  final int synced;
  final int total;
  final int errors;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1A237E),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  context.t('grid.syncingPunches'),
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress / 100,
                minHeight: 20,
                color: const Color(0xFF42A5F5),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              total > 0 ? context.t('grid.syncProgress', {'synced': synced, 'total': total, 'percent': progress}) : '$progress%',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            if (errors > 0)
              Text(
                context.t('grid.errorsCount', {'count': errors}),
                style: const TextStyle(color: Color(0xFFEF9A9A)),
              ),
            if (message.isNotEmpty)
              Text(
                message,
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onCancel,
                style: TextButton.styleFrom(foregroundColor: Colors.white70),
                child: Text(context.t('grid.cancelSync')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SyncResultBanner extends StatelessWidget {
  const _SyncResultBanner({
    required this.state,
    required this.message,
    required this.synced,
    required this.errors,
    required this.onDismiss,
  });

  final String state;
  final String message;
  final int synced;
  final int errors;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final ok = state == 'done';
    return Card(
      color: ok ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
      child: ListTile(
        leading: Icon(
          ok ? Icons.check_circle : Icons.error,
          color: ok ? AppColors.success : AppColors.danger,
        ),
        title: Text(
          message.isNotEmpty ? message : (ok ? context.t('grid.syncDone') : context.t('grid.syncFailed')),
        ),
        subtitle: Text(context.t('grid.syncSummary', {'synced': synced, 'errors': errors > 0 ? ' • ' + context.t('grid.errorsCount', {'count': errors}) : ''})),
        trailing: TextButton(onPressed: onDismiss, child: Text(context.t('common.close'))),
      ),
    );
  }
}

class _CellEditorSheet extends StatelessWidget {
  const _CellEditorSheet({required this.shifts, required this.current});
  final List<Map<String, dynamic>> shifts;
  final String current;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      builder: (_, scroll) => Material(
        child: ListView(
          controller: scroll,
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              context.t('grid.editCell'),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (current.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.clear, color: Colors.redAccent),
                title: Text(
                  context.t('grid.clearAssignment'),
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(context.t('grid.clearCellHint')),
                onTap: () => Navigator.pop(context, ''),
              ),
            if (current.isNotEmpty) const Divider(),
            for (final opt in [
              ('off', context.t('shiftGrid.cell.off')),
              ('present', context.t('shiftGrid.cell.present')),
              ('sick', context.t('shiftGrid.cell.sick')),
              ('annual', context.t('shiftGrid.cell.annual')),
              ('excluded', context.t('shiftGrid.cell.excluded')),
              ('bus_delay', context.t('shiftGrid.cell.busDelay')),
              ('finished', context.t('shiftGrid.cell.finished')),
              ('resignation', context.t('shiftGrid.cell.resignation')),
              ('work_absence', context.t('shiftGrid.cell.absence')),
              ('work_injury', context.t('shiftGrid.cell.injury')),
              ('marriage', context.t('shiftGrid.cell.marriage')),
            ])
              ListTile(
                title: Text(opt.$2),
                selected: current == opt.$1,
                onTap: () => Navigator.pop(context, opt.$1),
              ),
            for (final s in shifts)
              ListTile(
                title: Text('${s['code']} - ${s['name']}'),
                selected: current == s['id'].toString(),
                onTap: () => Navigator.pop(context, s['id'].toString()),
              ),
            for (final s in shifts)
              ListTile(
                title: Text('${s['code']} 🚌'),
                selected: current == 'bus_${s['id']}',
                onTap: () => Navigator.pop(context, 'bus_${s['id']}'),
              ),
          ],
        ),
      ),
    );
  }
}

class _AddEmployeesDialog extends StatefulWidget {
  const _AddEmployeesDialog({required this.gridId, this.locationId});

  final String gridId;
  final String? locationId;

  @override
  State<_AddEmployeesDialog> createState() => _AddEmployeesDialogState();
}

class _AddEmployeesDialogState extends State<_AddEmployeesDialog> {
  final Set<String> _selected = {};
  List<Map<String, dynamic>> _candidates = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    try {
      final all = <Map<String, dynamic>>[];
      var offset = 0;
      const limit = 100;
      while (true) {
        final page = await api.employeesList(
          locationId: widget.locationId,
          excludeGridId: widget.gridId,
          limit: limit,
          offset: offset,
        );
        all.addAll(page.items);
        if (!page.hasMore) break;
        offset += limit;
      }
      if (!mounted) return;
      setState(() {
        _candidates = all;
        _loading = false;
      });
    } catch (e) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = e.toString();
        });
    }
  }

  void _onSearchSelected(String? id, String name) {
    if (id == null) return;
    setState(() {
      _selected.add(id);
      if (!_candidates.any((e) => e['id']?.toString() == id)) {
        _candidates = [
          ..._candidates,
          {'id': id, 'name': name},
        ];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.t('grid.addEmployees')),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.t('grid.onlyActiveAtLocation'),
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              EmployeeSearchField(
                locationId: widget.locationId,
                excludeGridId: widget.gridId,
                onSelected: _onSearchSelected,
              ),
              const SizedBox(height: 12),
              if (_loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_error != null)
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                )
              else if (_candidates.isEmpty)
                Text(context.t('grid.noEmployees'), style: TextStyle(fontSize: 12))
              else ...[
                ..._candidates.map((emp) {
                  final id = emp['id']?.toString() ?? '';
                  final name = emp['name']?.toString() ?? '';
                  final code =
                      emp['identificationId']?.toString() ??
                      emp['code']?.toString() ??
                      '';
                  final loc =
                      emp['locationName']?.toString() ??
                      emp['location']?.toString() ??
                      '';
                  final checked = _selected.contains(id);
                  return CheckboxListTile(
                    dense: true,
                    value: checked,
                    onChanged: id.isEmpty
                        ? null
                        : (v) => setState(() {
                            if (v == true) {
                              _selected.add(id);
                            } else {
                              _selected.remove(id);
                            }
                          }),
                    title: Text(name),
                    subtitle: Text(
                      [
                        if (code.isNotEmpty) code,
                        if (loc.isNotEmpty) loc,
                      ].join('  •  '),
                      style: const TextStyle(fontSize: 11),
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.t('common.cancel')),
        ),
        FilledButton(
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.pop(context, _selected.toList()),
          child: Text(context.t('grid.addCount', {'count': _selected.length})),
        ),
      ],
    );
  }
}

class _PunchesDialog extends StatelessWidget {
  const _PunchesDialog({required this.result});
  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    final items = (result['items'] as List?)?.whereType<Map>().toList() ?? [];
    return AlertDialog(
      title: Text(context.t('grid.punchesOf', {'name': result['employeeName'], 'date': result['date']})),
      content: SizedBox(
        width: 400,
        child: items.isEmpty
            ? Text(context.t('grid.noPunchesToday'))
            : ListView.builder(
                shrinkWrap: true,
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final p = items[i];
                  return ListTile(
                    dense: true,
                    title: Text(p['punchTime']?.toString() ?? ''),
                    subtitle: Text(
                      '${p['terminalAlias'] ?? ''}  state=${p['punchState'] ?? ''}',
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.t('common.close')),
        ),
      ],
    );
  }
}

class _ShiftGridLoadSkeleton extends StatelessWidget {
  const _ShiftGridLoadSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SkeletonBox(height: 28, width: 280),
        const SizedBox(height: 10),
        const SkeletonBox(height: 14, width: 420),
        const SizedBox(height: 16),
        const SkeletonBox(height: 40),
        const SizedBox(height: 12),
        const SkeletonBox(height: 44),
        const SizedBox(height: 12),
        Expanded(
          child: Card(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: 10,
              itemBuilder: (_, __) => const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SkeletonBox(height: 32, width: 120),
                    SizedBox(width: 8),
                    Expanded(child: SkeletonBox(height: 32)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SelectedPunchesRequest {
  _SelectedPunchesRequest(this.employeeIds, this.dateFrom, this.dateTo);
  final List<String> employeeIds;
  final String? dateFrom;
  final String? dateTo;
}

class _SelectPunchesDialog extends StatefulWidget {
  const _SelectPunchesDialog({
    required this.employees,
    this.dateFrom,
    this.dateTo,
  });

  final List<Map<String, String>> employees;
  final String? dateFrom;
  final String? dateTo;

  @override
  State<_SelectPunchesDialog> createState() => _SelectPunchesDialogState();
}

class _SelectPunchesDialogState extends State<_SelectPunchesDialog> {
  final Set<String> _selected = {};
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _fromCtrl = TextEditingController();
  final TextEditingController _toCtrl = TextEditingController();
  String _query = '';
  String? _error;
  late final DateTime _minDate;
  late final DateTime _maxDate;

  @override
  void initState() {
    super.initState();
    final gridFrom = _parse(_normDate(widget.dateFrom) ?? '') ?? DateTime.now();
    final gridTo = _parse(_normDate(widget.dateTo) ?? '') ?? DateTime.now();
    _minDate = gridFrom.isBefore(gridTo) ? gridFrom : gridTo;
    _maxDate = gridFrom.isBefore(gridTo) ? gridTo : gridFrom;
    _fromCtrl.text = _fmt(_minDate);
    _toCtrl.text = _fmt(_maxDate);
    _searchCtrl.addListener(
      () => setState(() => _query = _searchCtrl.text.trim().toLowerCase()),
    );
  }

  DateTime _clamp(DateTime d) {
    if (d.isBefore(_minDate)) return _minDate;
    if (d.isAfter(_maxDate)) return _maxDate;
    return d;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _fromCtrl.dispose();
    _toCtrl.dispose();
    super.dispose();
  }

  String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String? _normDate(String? s) {
    if (s == null) return null;
    final t = s.trim();
    if (t.length >= 10 && RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(t))
      return t.substring(0, 10);
    return null;
  }

  DateTime? _parse(String s) {
    final m = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(s.trim());
    if (m == null) return null;
    final dt = DateTime(
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
    );
    if (dt.month != int.parse(m.group(2)!) || dt.day != int.parse(m.group(3)!))
      return null;
    return dt;
  }

  List<Map<String, String>> get _filtered {
    if (_query.isEmpty) return widget.employees;
    return widget.employees.where((e) {
      final name = (e['name'] ?? '').toLowerCase();
      final code = (e['code'] ?? '').toLowerCase();
      return name.contains(_query) || code.contains(_query);
    }).toList();
  }

  Future<void> _pick(TextEditingController ctrl) async {
    final current = _clamp(_parse(ctrl.text) ?? _minDate);
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: _minDate,
      lastDate: _maxDate,
    );
    if (picked != null) {
      setState(() {
        ctrl.text = _fmt(picked);
        _error = null;
      });
    }
  }

  void _submit() {
    final from = _parse(_fromCtrl.text);
    final to = _parse(_toCtrl.text);
    if (from == null || to == null) {
      setState(() => _error = context.t('grid.badDateFormat'));
      return;
    }
    if (from.isAfter(to)) {
      setState(() => _error = context.t('grid.startBeforeEnd'));
      return;
    }
    if (from.isBefore(_minDate) || to.isAfter(_maxDate)) {
      setState(
        () => _error =
            context.t('grid.dateWithinRange', {'from': _fmt(_minDate), 'to': _fmt(_maxDate)}),
      );
      return;
    }
    if (_selected.isEmpty) {
      setState(() => _error = context.t('shiftGrid.pickEmployee'));
      return;
    }
    Navigator.pop(
      context,
      _SelectedPunchesRequest(_selected.toList(), _fmt(from), _fmt(to)),
    );
  }

  Widget _dateField(String label, TextEditingController ctrl) {
    return InkWell(
      onTap: () => _pick(ctrl),
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.event, size: 18),
          suffixIcon: const Icon(Icons.calendar_month, size: 18),
        ),
        child: Text(ctrl.text.isEmpty ? '—' : ctrl.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final allFilteredSelected =
        filtered.isNotEmpty &&
        filtered.every((e) => _selected.contains(e['id']));

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: EdgeInsets.zero,
      title: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: const BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.fact_check_outlined,
              color: Colors.white,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.t('grid.exportSelectedPunches'),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              context.t('grid.selectedCount', {'count': _selected.length}),
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: _dateField(context.t('grid.dateFrom'), _fromCtrl)),
                const SizedBox(width: 12),
                Expanded(child: _dateField(context.t('grid.dateTo'), _toCtrl)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              context.t('grid.availableRange', {'from': _fmt(_minDate), 'to': _fmt(_maxDate)}),
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: context.t('grid.searchNameOrCode'),
                isDense: true,
                prefixIcon: Icon(Icons.search, size: 18),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      if (allFilteredSelected) {
                        for (final e in filtered) {
                          _selected.remove(e['id']);
                        }
                      } else {
                        for (final e in filtered) {
                          _selected.add(e['id']!);
                        }
                      }
                      _error = null;
                    });
                  },
                  icon: Icon(
                    allFilteredSelected ? Icons.deselect : Icons.select_all,
                    size: 18,
                  ),
                  label: Text(
                    allFilteredSelected ? context.t('common.clearSelection') : context.t('common.selectAll'),
                  ),
                ),
                const Spacer(),
                Text(
                  context.t('shiftGrid.employeesCount', {'count': filtered.length}),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const Divider(height: 1),
            SizedBox(
              height: 320,
              child: filtered.isEmpty
                  ? Center(child: Text(context.t('common.noResults')))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final e = filtered[i];
                        final id = e['id']!;
                        final checked = _selected.contains(id);
                        return CheckboxListTile(
                          value: checked,
                          onChanged: (v) => setState(() {
                            if (v == true) {
                              _selected.add(id);
                            } else {
                              _selected.remove(id);
                            }
                            _error = null;
                          }),
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(
                            e['name'] ?? '',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            [
                              if ((e['code'] ?? '').isNotEmpty)
                                context.t('common.codeValue', {'code': e['code']}),
                              if ((e['job'] ?? '').isNotEmpty &&
                                  e['job'] != 'بدون وظيفة')
                                e['job']!,
                            ].join('  •  '),
                            style: const TextStyle(fontSize: 11),
                          ),
                        );
                      },
                    ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.danger, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.t('common.cancel')),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.download, size: 18),
          label: Text(context.t('common.export')),
        ),
      ],
    );
  }
}

class _ShiftGridExcelRangeDialog extends StatefulWidget {
  const _ShiftGridExcelRangeDialog({
    required this.title,
    required this.confirmLabel,
    required this.confirmIcon,
    this.subtitle,
    this.dateFrom,
    this.dateTo,
    this.availableGroups,
    this.groupsLabel,
  });

  final String title;
  final String confirmLabel;
  final IconData confirmIcon;
  final String? subtitle;
  final String? dateFrom;
  final String? dateTo;
  /// When non-null, show a multi-select of grid sections (jobs / departments).
  final List<String>? availableGroups;
  final String? groupsLabel;

  @override
  State<_ShiftGridExcelRangeDialog> createState() =>
      _ShiftGridExcelRangeDialogState();
}

class _ShiftGridExcelRangeDialogState extends State<_ShiftGridExcelRangeDialog> {
  final TextEditingController _fromCtrl = TextEditingController();
  final TextEditingController _toCtrl = TextEditingController();
  String? _error;
  late final DateTime _minDate;
  late final DateTime _maxDate;
  late final Set<String> _selectedGroups;

  bool get _hasGroups =>
      widget.availableGroups != null && widget.availableGroups!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    final gridFrom = _parse(_normDate(widget.dateFrom) ?? '') ?? DateTime.now();
    final gridTo = _parse(_normDate(widget.dateTo) ?? '') ?? DateTime.now();
    _minDate = gridFrom.isBefore(gridTo) ? gridFrom : gridTo;
    _maxDate = gridFrom.isBefore(gridTo) ? gridTo : gridFrom;
    _fromCtrl.text = _fmt(_minDate);
    _toCtrl.text = _fmt(_maxDate);
    _selectedGroups = {...?widget.availableGroups};
  }

  @override
  void dispose() {
    _fromCtrl.dispose();
    _toCtrl.dispose();
    super.dispose();
  }

  String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String? _normDate(String? s) {
    if (s == null) return null;
    final t = s.trim();
    if (t.length >= 10 && RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(t)) {
      return t.substring(0, 10);
    }
    return null;
  }

  DateTime? _parse(String s) {
    final m = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(s.trim());
    if (m == null) return null;
    final dt = DateTime(
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
    );
    if (dt.month != int.parse(m.group(2)!) ||
        dt.day != int.parse(m.group(3)!)) {
      return null;
    }
    return dt;
  }

  DateTime _clamp(DateTime d) {
    if (d.isBefore(_minDate)) return _minDate;
    if (d.isAfter(_maxDate)) return _maxDate;
    return d;
  }

  Future<void> _pick(TextEditingController ctrl) async {
    final current = _clamp(_parse(ctrl.text) ?? _minDate);
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: _minDate,
      lastDate: _maxDate,
    );
    if (picked != null) {
      setState(() {
        ctrl.text = _fmt(picked);
        _error = null;
      });
    }
  }

  void _submit() {
    final from = _parse(_fromCtrl.text);
    final to = _parse(_toCtrl.text);
    if (from == null || to == null) {
      setState(() => _error = context.t('grid.badDateFormat'));
      return;
    }
    if (from.isAfter(to)) {
      setState(() => _error = context.t('grid.startBeforeEnd'));
      return;
    }
    if (from.isBefore(_minDate) || to.isAfter(_maxDate)) {
      setState(
        () => _error =
            context.t('grid.dateWithinRange', {'from': _fmt(_minDate), 'to': _fmt(_maxDate)}),
      );
      return;
    }
    if (_hasGroups && _selectedGroups.isEmpty) {
      setState(() => _error = context.t('grid.pickDepartmentToExport'));
      return;
    }
    Navigator.pop(context, (
      from: _fmt(from),
      to: _fmt(to),
      // Always return selected departments so the Excel filename can suffix them
      // (e.g. …_Operation or …_Kitchen_Operation).
      groupKeys: _hasGroups ? _selectedGroups.toList() : null,
    ));
  }

  Widget _dateField(String label, TextEditingController ctrl) {
    return InkWell(
      onTap: () => _pick(ctrl),
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.event, size: 18),
          suffixIcon: const Icon(Icons.calendar_month, size: 18),
        ),
        child: Text(ctrl.text.isEmpty ? '—' : ctrl.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fromDt = _parse(_fromCtrl.text);
    final toDt = _parse(_toCtrl.text);
    final dayCount =
        fromDt != null && toDt != null ? toDt.difference(fromDt).inDays + 1 : null;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: EdgeInsets.zero,
      title: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: const BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Row(
          children: [
            const Icon(Icons.date_range, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.t('grid.gridPeriod', {'from': _fmt(_minDate), 'to': _fmt(_maxDate)}),
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (widget.subtitle != null) ...[
                const SizedBox(height: 8),
                Text(
                  widget.subtitle!,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _dateField(context.t('grid.dateFrom'), _fromCtrl)),
                  const SizedBox(width: 12),
                  Expanded(child: _dateField(context.t('grid.dateTo'), _toCtrl)),
                ],
              ),
              if (dayCount != null && dayCount > 0) ...[
                const SizedBox(height: 10),
                Text(
                  context.t('grid.selectedDays', {'count': dayCount}),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (_hasGroups) ...[
                const SizedBox(height: 16),
                Text(
                  widget.groupsLabel ?? context.t('grid.departments'),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.t('grid.departmentsHint'),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => setState(() {
                        _selectedGroups
                          ..clear()
                          ..addAll(widget.availableGroups!);
                        _error = null;
                      }),
                      child: Text(context.t('common.selectAll')),
                    ),
                    TextButton(
                      onPressed: () => setState(() {
                        _selectedGroups.clear();
                        _error = null;
                      }),
                      child: Text(context.t('common.clearAll')),
                    ),
                    const Spacer(),
                    Text(
                      '${_selectedGroups.length}/${widget.availableGroups!.length}',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: Material(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: widget.availableGroups!.length,
                      itemBuilder: (context, i) {
                        final key = widget.availableGroups![i];
                        final selected = _selectedGroups.contains(key);
                        return CheckboxListTile(
                          dense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 8),
                          value: selected,
                          title: Text(key, style: const TextStyle(fontSize: 13)),
                          controlAffinity: ListTileControlAffinity.leading,
                          onChanged: (v) {
                            setState(() {
                              if (v == true) {
                                _selectedGroups.add(key);
                              } else {
                                _selectedGroups.remove(key);
                              }
                              _error = null;
                            });
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.danger, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.t('common.cancel')),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: Icon(widget.confirmIcon, size: 18),
          label: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
