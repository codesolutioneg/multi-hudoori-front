import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/injection.dart';
import '../../core/layout/breakpoints.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme_v2.dart';
import '../../core/utils/api_error_message.dart';
import '../../core/utils/entity_id.dart';
import '../../core/utils/file_download.dart';
import '../../core/utils/money_format.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/sellix_card.dart';
import '../../l10n/l10n_extension.dart';
import '../../core/platform/mobile_platform.dart';
import '../mobile/hudoori_loader.dart';
import '../mobile/mobile_ui.dart';
import 'widgets/report_options_panel.dart';
import 'widgets/sync_progress_dialog.dart';

enum HrReport {
  noPunches,
  locationMismatch,
  punchSummary,
  fawry,
  insurance,
  documents,
  healthCertificates,
  employeeHirings,
  employeeExits,
  employeeEmails,
}

/// One page for the five compliance reports. They share a population filter and
/// an export button, and differ only in their options and columns, so keeping
/// them together avoids five near-identical screens.
class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  HrReport _report = HrReport.noPunches;

  // Shared population scope.
  String? _locationId;
  String? _departmentId;
  bool _requireNationalId = false;
  bool _includeArchived = false;

  // Report 1 + location mismatch.
  DateTime _dateFrom = DateTime.now().subtract(const Duration(days: 30));
  DateTime _dateTo = DateTime.now();
  bool _includeNeverScheduled = true;
  bool _includeUnmappedDevices = false;

  // Reports 2, 3, 4, 5.
  String _fawryFilter = 'all';
  String _insuranceKind = 'both';
  String _insuranceFilter = 'all';
  final Set<String> _requiredDocuments = {};
  String _documentsFilter = 'incomplete';
  bool _acceptCopies = true;
  String _healthMode = 'expired_or_expiring';
  final _warningDaysCtrl = TextEditingController(text: '15');

  List<Map<String, dynamic>> _locations = [];
  List<Map<String, dynamic>> _departments = [];
  List<Map<String, dynamic>> _documentTypes = [];

  List<Map<String, dynamic>> _rows = [];
  List<String> _columns = [];
  bool _loading = false;
  bool _exporting = false;
  bool _hasRun = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReferenceData();
  }

  @override
  void dispose() {
    _warningDaysCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadReferenceData() async {
    try {
      final results = await Future.wait([
        api.locationsList(),
        api.departmentsList(),
        api.reportDocumentTypes(),
      ]);
      if (!mounted) return;
      setState(() {
        _locations = (results[0] as List).cast<Map<String, dynamic>>();
        _departments = (results[1] as List).cast<Map<String, dynamic>>();
        _documentTypes =
            ((results[2] as Map)['types'] as List? ?? []).cast<Map<String, dynamic>>();
      });
    } catch (_) {
      // Reference lists only drive optional filters; the reports still run.
    }
  }

  String _reportTitle(HrReport report) {
    switch (report) {
      case HrReport.noPunches:
        return context.t('reports.noPunches');
      case HrReport.locationMismatch:
        return context.t('reports.locationMismatch');
      case HrReport.punchSummary:
        return context.t('reports.punchSummary');
      case HrReport.fawry:
        return context.t('reports.fawry');
      case HrReport.insurance:
        return context.t('reports.insurance');
      case HrReport.documents:
        return context.t('reports.documents');
      case HrReport.healthCertificates:
        return context.t('reports.healthCertificates');
      case HrReport.employeeHirings:
        return context.t('reports.employeeHirings');
      case HrReport.employeeExits:
        return context.t('reports.employeeExits');
      case HrReport.employeeEmails:
        return context.t('reports.employeeEmails');
    }
  }

  String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  int? get _warningDays {
    final parsed = int.tryParse(_warningDaysCtrl.text.trim());
    if (parsed == null || parsed < 0) return null;
    return parsed;
  }

  bool get _reportReady =>
      _report != HrReport.punchSummary || (_locationId?.isNotEmpty ?? false);

  Future<Map<String, dynamic>> _callReport({required bool export}) {
    switch (_report) {
      case HrReport.noPunches:
        return api.reportNoPunches(
          dateFrom: _iso(_dateFrom),
          dateTo: _iso(_dateTo),
          includeNeverScheduled: _includeNeverScheduled,
          locationId: _locationId,
          departmentId: _departmentId,
          requireNationalId: _requireNationalId,
          includeArchived: _includeArchived,
          export: export,
        );
      case HrReport.locationMismatch:
        // No national-ID gate on this report (the panel hides it), so don't
        // forward a stale _requireNationalId from another report or it would
        // silently drop employees with no national ID.
        return api.reportLocationMismatch(
          dateFrom: _iso(_dateFrom),
          dateTo: _iso(_dateTo),
          includeUnmappedDevices: _includeUnmappedDevices,
          locationId: _locationId,
          departmentId: _departmentId,
          includeArchived: _includeArchived,
          export: export,
        );
      case HrReport.punchSummary:
        // No national-ID gate on this report either (the panel hides it).
        return api.reportPunchSummary(
          dateFrom: _iso(_dateFrom),
          dateTo: _iso(_dateTo),
          locationId: _locationId,
          departmentId: _departmentId,
          includeArchived: _includeArchived,
          export: export,
        );
      case HrReport.fawry:
        return api.reportFawry(
          filter: _fawryFilter,
          locationId: _locationId,
          departmentId: _departmentId,
          requireNationalId: _requireNationalId,
          export: export,
        );
      case HrReport.insurance:
        return api.reportInsurance(
          kind: _insuranceKind,
          filter: _insuranceFilter,
          locationId: _locationId,
          departmentId: _departmentId,
          requireNationalId: _requireNationalId,
          export: export,
        );
      case HrReport.documents:
        return api.reportDocuments(
          requiredDocuments: _requiredDocuments.toList(),
          filter: _documentsFilter,
          acceptCopies: _acceptCopies,
          locationId: _locationId,
          departmentId: _departmentId,
          requireNationalId: _requireNationalId,
          export: export,
        );
      case HrReport.healthCertificates:
        return api.reportHealthCertificates(
          mode: _healthMode,
          warningDays: _warningDays,
          locationId: _locationId,
          departmentId: _departmentId,
          requireNationalId: _requireNationalId,
          export: export,
        );
      case HrReport.employeeHirings:
        return api.reportEmployeeMovements(
          mode: 'hirings',
          dateFrom: _iso(_dateFrom),
          dateTo: _iso(_dateTo),
          locationId: _locationId,
          departmentId: _departmentId,
          requireNationalId: _requireNationalId,
          export: export,
        );
      case HrReport.employeeExits:
        return api.reportEmployeeMovements(
          mode: 'exits',
          dateFrom: _iso(_dateFrom),
          dateTo: _iso(_dateTo),
          locationId: _locationId,
          departmentId: _departmentId,
          requireNationalId: _requireNationalId,
          export: export,
        );
      case HrReport.employeeEmails:
        return api.reportEmployeeEmails(
          locationId: _locationId,
          departmentId: _departmentId,
          requireNationalId: _requireNationalId,
          includeArchived: _includeArchived,
          export: export,
        );
    }
  }

  /// The insurance report returns two lists rather than one, so it is flattened
  /// with a kind column instead of getting its own results table.
  List<Map<String, dynamic>> _extractRows(Map<String, dynamic> data) {
    if (_report != HrReport.insurance) {
      return ((data['rows'] as List?) ?? []).cast<Map<String, dynamic>>();
    }
    final social = ((data['social'] as List?) ?? []).cast<Map<String, dynamic>>();
    final medical = ((data['medical'] as List?) ?? []).cast<Map<String, dynamic>>();
    return [
      for (final r in social) {...r, 'kind': context.t('reports.insuranceSocial')},
      for (final r in medical) {...r, 'kind': context.t('reports.insuranceMedical')},
    ];
  }

  List<String> _columnsFor(HrReport report) {
    switch (report) {
      case HrReport.noPunches:
        return ['code', 'name', 'locationName', 'departmentName', 'hiringDate', 'isBareCode'];
      case HrReport.locationMismatch:
        return [
          'code',
          'name',
          'employeeLocationName',
          'deviceName',
          'deviceLocationName',
          'punchCount',
          'statusLabel',
        ];
      case HrReport.punchSummary:
        // Every figure the workbook summary block prints, in the same order, so
        // HR can reconcile totalPenalties from what is on screen.
        return [
          'code',
          'name',
          'locationName',
          'workingDays',
          'earnedLeaveCapped',
          'actualWorkingDays',
          'singlePunch',
          'punchDeduction',
          'absentCount',
          'adminPenalty',
          'overtime',
          'lateDeduction',
          'earlyDeduction',
          'sickDayCount',
          'sickDeduction',
          'totalPenalties',
          'measured',
        ];
      case HrReport.fawry:
        return [
          'code',
          'name',
          'locationName',
          'hasFlag',
          'fawryNumber',
          'numberSourceLabel',
          'statusLabel',
        ];
      case HrReport.insurance:
        return ['code', 'name', 'kind', 'insured', 'companyName', 'insuredSalary'];
      case HrReport.documents:
        return ['code', 'name', 'locationName', 'complete', 'missingCount', 'missingLabels'];
      case HrReport.healthCertificates:
        return ['code', 'name', 'locationName', 'expiryDate', 'daysRemaining', 'statusLabel'];
      case HrReport.employeeHirings:
        return [
          'eventDate',
          'code',
          'name',
          'locationName',
          'departmentName',
          'hiringDate',
        ];
      case HrReport.employeeExits:
        return [
          'kindLabel',
          'eventDate',
          'code',
          'name',
          'locationName',
          'departmentName',
          'hiringDate',
          'archivedAt',
          'archiveReason',
          'departureDate',
        ];
      case HrReport.employeeEmails:
        return [
          'code',
          'name',
          'locationName',
          'departmentName',
          'workEmail',
          'workEmailPassword',
        ];
    }
  }

  /// The punch report reads stored punches, so the period is pulled from BioTime
  /// first when no recent sync covered it. The pull is a job with its own progress
  /// dialog: a month of punches takes minutes, longer than a request may last.
  /// If BioTime is unreachable, we skip sync and continue from local DB punches.
  Future<void> _syncPunchesIfNeeded() async {
    if (_report != HrReport.punchSummary) return;
    final locationId = _locationId;
    if (locationId == null || locationId.isEmpty) return;
    try {
      final start = await api.reportPunchSyncStart(
        dateFrom: _iso(_dateFrom),
        dateTo: _iso(_dateTo),
        locationId: locationId,
      );
      if (!mounted) return;
      if (start.usedLocal) {
        final msg = (start.message != null && start.message!.trim().isNotEmpty)
            ? start.message!
            : context.t('reports.punchSyncUsedLocal');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        return;
      }
      final jobId = start.jobId;
      if (jobId == null) return;

      final dialogState = ValueNotifier(
        SyncDialogState(
          title: context.t('reports.punchSyncTitle'),
          message: context.t('reports.punchSyncMessage'),
        ),
      );
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => SyncProgressDialog(stateListenable: dialogState),
      );
      try {
        final st = await api.reportPunchSyncWait(
          jobId,
          onProgress: (message, {int? progress}) {
            dialogState.value = dialogState.value.copyWith(
              message: message.isNotEmpty ? message : dialogState.value.message,
              progress: progress,
            );
          },
        );
        if (!mounted) return;
        final doneMsg = st['message']?.toString() ?? '';
        if (doneMsg.contains('المخزّنة') || doneMsg.toLowerCase().contains('biotime')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(doneMsg.isNotEmpty ? doneMsg : context.t('reports.punchSyncUsedLocal'))),
          );
        }
      } finally {
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
        dialogState.dispose();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${friendlyApiError(context, e)}\n${context.t('reports.punchSyncUsedLocal')}',
          ),
        ),
      );
    }
  }

  Future<void> _run() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _syncPunchesIfNeeded();
      final data = await _callReport(export: false);
      if (!mounted) return;
      setState(() {
        _rows = _extractRows(data);
        _columns = _columnsFor(_report);
        _loading = false;
        _hasRun = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _hasRun = true;
        _rows = [];
        _error = friendlyApiError(context, e);
      });
    }
  }

  Future<void> _export() async {
    if (_exporting) return;
    // Resolved before the await: reading it afterwards would touch a context
    // that may already be gone.
    final emptyFileMessage = context.t('reports.emptyFile');
    setState(() => _exporting = true);
    try {
      await _syncPunchesIfNeeded();
      final data = await _callReport(export: true);
      final base64 = data['file']?.toString() ?? data['base64']?.toString() ?? '';
      if (base64.isEmpty) throw Exception(emptyFileMessage);
      final filename = data['filename']?.toString() ?? 'report.xlsx';
      downloadBase64File(
        base64,
        filename,
        data['mimeType']?.toString() ??
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      if (!mounted) return;
      setState(() => _exporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('reports.downloaded', {'name': filename}))),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _exporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyApiError(context, e))),
      );
    }
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom ? _dateFrom : _dateTo;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2015),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isFrom) {
        _dateFrom = picked;
        if (_dateTo.isBefore(picked)) _dateTo = picked;
      } else {
        _dateTo = picked;
        if (_dateFrom.isAfter(picked)) _dateFrom = picked;
      }
    });
  }

  String _cellText(Map<String, dynamic> row, String column) {
    if (column == 'missingLabels') {
      final labels = row['missingLabels']?.toString().trim();
      if (labels != null && labels.isNotEmpty) return labels;
      final missing = (row['missing'] as List?) ?? [];
      if (missing.isEmpty) return '—';
      final byValue = {
        for (final t in _documentTypes)
          t['value']?.toString(): t['label']?.toString() ?? t['value']?.toString() ?? '',
      };
      return missing
          .map((m) => byValue[m.toString()] ?? m.toString())
          .where((s) => s.isNotEmpty)
          .join(tr('common.listSeparator'));
    }
    // The backend label is Arabic (it also goes into the Arabic Excel), so
    // localize this one from the enum instead of showing it in an English UI.
    if (column == 'numberSourceLabel') {
      final source = row['numberSource'];
      if (source is String && source.isNotEmpty) {
        final key = 'reports.fawrySource.$source';
        final label = context.t(key);
        if (label != key) return label;
      }
    }
    final value = row[column];
    if (value == null || value == '') return '—';
    if (value is bool) return value ? context.t('common.yes') : context.t('common.no');
    if (value is num && _moneyColumns.contains(column)) return formatMoney(value);
    return value.toString();
  }

  static const _moneyColumns = {
    'insuredSalary',
    'punchDeduction',
    'adminPenalty',
    'overtime',
    'lateDeduction',
    'earlyDeduction',
    'sickDeduction',
    'totalPenalties',
  };

  bool _isAlertRow(Map<String, dynamic> row) {
    switch (_report) {
      case HrReport.noPunches:
        return row['isBareCode'] == true;
      case HrReport.locationMismatch:
        return true;
      case HrReport.punchSummary:
        // Unmeasured means the zeros are "nothing to compare", not "clean".
        return (row['totalPenalties'] as num? ?? 0) > 0 || row['measured'] == false;
      case HrReport.fawry:
        return row['status'] == 'missing_number' || row['status'] == 'number_without_flag';
      case HrReport.insurance:
        return row['insured'] == false;
      case HrReport.documents:
        return row['complete'] == false;
      case HrReport.healthCertificates:
        return row['status'] == 'expired' || row['status'] == 'missing';
      case HrReport.employeeHirings:
        return false;
      case HrReport.employeeExits:
        return true;
      case HrReport.employeeEmails:
        return row['hasPassword'] == false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Phones scroll the whole page; wider screens keep the results area fixed.
    final mobile = isMobile(context);
    final content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: context.t('reports.title'),
            subtitle: context.t('reports.subtitle'),
            icon: Icons.assessment_outlined,
            onBack: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go(AppRoutes.dashboard);
              }
            },
          ),
          const SizedBox(height: 16),
          SellixCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isNativeMobile)
                  _mobileReportPicker(context)
                else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final report in HrReport.values)
                      ChoiceChip(
                        label: Text(_reportTitle(report)),
                        selected: _report == report,
                        onSelected: (_) => setState(() {
                          _report = report;
                          _rows = [];
                          _hasRun = false;
                          _error = null;
                        }),
                      ),
                  ],
                ),
                const Divider(height: 24),
                ReportOptionsPanel(
                  report: _report,
                  locations: _locations,
                  departments: _departments,
                  documentTypes: _documentTypes,
                  locationId: _locationId,
                  departmentId: _departmentId,
                  requireNationalId: _requireNationalId,
                  includeArchived: _includeArchived,
                  dateFrom: _dateFrom,
                  dateTo: _dateTo,
                  includeNeverScheduled: _includeNeverScheduled,
                  includeUnmappedDevices: _includeUnmappedDevices,
                  fawryFilter: _fawryFilter,
                  insuranceKind: _insuranceKind,
                  insuranceFilter: _insuranceFilter,
                  requiredDocuments: _requiredDocuments,
                  documentsFilter: _documentsFilter,
                  acceptCopies: _acceptCopies,
                  healthMode: _healthMode,
                  warningDaysController: _warningDaysCtrl,
                  onLocationChanged: (v) => setState(() => _locationId = v),
                  onDepartmentChanged: (v) => setState(() => _departmentId = v),
                  onRequireNationalIdChanged: (v) => setState(() => _requireNationalId = v),
                  onIncludeArchivedChanged: (v) => setState(() => _includeArchived = v),
                  onPickDate: (isFrom) => _pickDate(isFrom: isFrom),
                  onIncludeNeverScheduledChanged: (v) =>
                      setState(() => _includeNeverScheduled = v),
                  onIncludeUnmappedDevicesChanged: (v) =>
                      setState(() => _includeUnmappedDevices = v),
                  onFawryFilterChanged: (v) => setState(() => _fawryFilter = v),
                  onInsuranceKindChanged: (v) => setState(() => _insuranceKind = v),
                  onInsuranceFilterChanged: (v) => setState(() => _insuranceFilter = v),
                  onToggleDocument: (type, selected) => setState(() {
                    if (selected) {
                      _requiredDocuments.add(type);
                    } else {
                      _requiredDocuments.remove(type);
                    }
                  }),
                  onDocumentsFilterChanged: (v) => setState(() => _documentsFilter = v),
                  onAcceptCopiesChanged: (v) => setState(() => _acceptCopies = v),
                  onHealthModeChanged: (v) => setState(() => _healthMode = v),
                ),
                const SizedBox(height: 12),
                if (!_reportReady) ...[
                  Text(
                    context.t('reports.punchReportSelectLocation'),
                    style: AppThemeV2.caption.copyWith(color: AppColors.warning),
                  ),
                  const SizedBox(height: 8),
                ],
                if (isNativeMobile)
                  _mobileRunBar()
                else
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: _loading || !_reportReady ? null : _run,
                      icon: const Icon(Icons.play_arrow),
                      label: Text(context.t('reports.run')),
                    ),
                    OutlinedButton.icon(
                      onPressed: _exporting || !_reportReady ? null : _export,
                      icon: const Icon(Icons.download_outlined),
                      label: Text(context.t('reports.exportExcel')),
                    ),
                    if (_hasRun && _error == null)
                      Text(
                        context.t('reports.resultCount', {'count': '${_rows.length}'}),
                        style: AppThemeV2.caption,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (mobile)
            _buildResults(inline: true)
          else
            Expanded(child: _buildResults()),
        ],
      );
    if (mobile) {
      return SingleChildScrollView(
        padding: isNativeMobile
            ? const EdgeInsets.fromLTRB(16, 6, 16, 24)
            : const EdgeInsets.fromLTRB(12, 12, 12, 24),
        child: content,
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: content,
    );
  }

  Widget _mobileRunBar() {
    const excel = Color(0xFF16A34A);
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              flex: 3,
              child: FilledButton.icon(
                onPressed: _loading || !_reportReady ? null : _run,
                style: FilledButton.styleFrom(
                  backgroundColor: MobileUi.primary,
                  minimumSize: const Size.fromHeight(52),
                  shape: shape,
                  textStyle: MobileUi.text(14.5, weight: FontWeight.w800),
                ),
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                      )
                    : const Icon(Icons.play_arrow_rounded, size: 24),
                label: Text(context.t('reports.run')),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: FilledButton.tonalIcon(
                onPressed: _exporting || !_reportReady ? null : _export,
                style: FilledButton.styleFrom(
                  backgroundColor: excel.withValues(alpha: 0.12),
                  foregroundColor: excel,
                  minimumSize: const Size.fromHeight(52),
                  shape: shape,
                  textStyle: MobileUi.text(13.5, weight: FontWeight.w800),
                ),
                icon: _exporting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.2, color: excel),
                      )
                    : const Icon(Icons.table_view_rounded, size: 20),
                label: const Text('Excel'),
              ),
            ),
          ],
        ),
        if (_hasRun && _error == null) ...[
          const SizedBox(height: 10),
          Center(
            child: MobileChip(
              label: context.t('reports.resultCount', {'count': '${_rows.length}'}),
              icon: Icons.fact_check_outlined,
            ),
          ),
        ],
      ],
    );
  }

  void _selectReport(HrReport report) => setState(() {
        _report = report;
        _rows = [];
        _hasRun = false;
        _error = null;
      });

  Widget _mobileReportPicker(BuildContext context) {
    Future<void> open() async {
      final picked = await showModalBottomSheet<HrReport>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.75),
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.fromLTRB(12, 0, 12, 24 + MediaQuery.viewPaddingOf(ctx).bottom),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                child: Text(context.t('m.reportType'), style: MobileUi.sectionTitle),
              ),
              for (final report in HrReport.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Material(
                    color: report == _report ? MobileUi.primarySoft : const Color(0xFFF7F9FD),
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => Navigator.pop(ctx, report),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        child: Row(
                          children: [
                            Icon(
                              Icons.insert_chart_outlined_rounded,
                              size: 20,
                              color: report == _report ? MobileUi.primary : MobileUi.muted,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _reportTitle(report),
                                style: MobileUi.text(
                                  14,
                                  weight: report == _report ? FontWeight.w800 : FontWeight.w600,
                                  color: report == _report ? MobileUi.primaryDeep : MobileUi.ink,
                                ),
                              ),
                            ),
                            if (report == _report)
                              const Icon(Icons.check_circle_rounded, color: MobileUi.primary, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
      if (picked != null && picked != _report) _selectReport(picked);
    }

    return Material(
      color: MobileUi.primarySoft,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: open,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: MobileUi.primaryGradient,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.insert_chart_outlined_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.t('m.reportType'),
                      style: MobileUi.text(12, weight: FontWeight.w600, color: MobileUi.muted),
                    ),
                    Text(
                      _reportTitle(_report),
                      style: MobileUi.text(15, weight: FontWeight.w800, color: MobileUi.primaryDeep, height: 1.3),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.unfold_more_rounded, color: MobileUi.primary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mobileResults() {
    final title = _columns.isEmpty ? null : _columns.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final row in _rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  final id = EntityId.parse(row['employeeId']);
                  if (id != null) context.go(AppRoutes.hrEmployeeDetail(id));
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: MobileUi.card().copyWith(
                    border: _isAlertRow(row)
                        ? Border.all(color: MobileTone.danger.withValues(alpha: 0.35))
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (title != null)
                        Row(
                          children: [
                            MobileAvatar(name: _cellText(row, title), size: 38),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _cellText(row, title),
                                style: MobileUi.text(14.5, weight: FontWeight.w800),
                              ),
                            ),
                            if (_isAlertRow(row))
                              const Icon(Icons.error_outline_rounded, color: MobileTone.danger, size: 20),
                          ],
                        ),
                      const SizedBox(height: 8),
                      for (final column in _columns.skip(1))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text(
                                  context.t('reports.column.$column'),
                                  style: MobileUi.text(12, weight: FontWeight.w600, color: MobileUi.muted),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  _cellText(row, column),
                                  style: MobileUi.text(13, weight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildResults({bool inline = false}) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: HudooriLoader(),
        ),
      );
    }
    if (isNativeMobile) {
      if (_error != null) {
        return MobileEmptyState(icon: Icons.error_outline_rounded, message: _error!);
      }
      if (!_hasRun) {
        return MobileEmptyState(
          icon: Icons.insert_chart_outlined_rounded,
          message: context.t('reports.pressRun'),
        );
      }
      if (_rows.isEmpty) {
        return MobileEmptyState(
          icon: Icons.check_circle_outline_rounded,
          message: context.t('reports.empty'),
        );
      }
      return _mobileResults();
    }
    if (_error != null) {
      return SellixCard(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
          ],
        ),
      );
    }
    if (!_hasRun) {
      return SellixCard(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.assessment_outlined, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text(context.t('reports.pressRun')),
          ],
        ),
      );
    }
    if (_rows.isEmpty) {
      return SellixCard(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline, size: 48, color: AppColors.success),
            const SizedBox(height: 12),
            Text(context.t('reports.empty')),
          ],
        ),
      );
    }

    return SellixCard(
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        primary: inline ? false : null,
        physics: inline ? const NeverScrollableScrollPhysics() : null,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: [
              for (final column in _columns)
                DataColumn(label: Text(context.t('reports.column.$column'))),
            ],
            rows: [
              for (final row in _rows)
                DataRow(
                  color: _isAlertRow(row)
                      ? WidgetStatePropertyAll(AppColors.danger.withValues(alpha: 0.06))
                      : null,
                  cells: [
                    for (final column in _columns)
                      DataCell(
                        Text(_cellText(row, column)),
                        onTap: () {
                          final id = EntityId.parse(row['employeeId']);
                          if (id != null) context.go(AppRoutes.hrEmployeeDetail(id));
                        },
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
