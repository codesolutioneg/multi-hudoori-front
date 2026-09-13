import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/injection.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme_v2.dart';
import '../../core/utils/entity_id.dart';
import '../../core/utils/file_download.dart';
import '../../core/utils/money_format.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/sellix_card.dart';
import '../../l10n/l10n_extension.dart';
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
  Future<void> _syncPunchesIfNeeded() async {
    if (_report != HrReport.punchSummary) return;
    final locationId = _locationId;
    if (locationId == null || locationId.isEmpty) return;
    final jobId = await api.reportPunchSyncStart(
      dateFrom: _iso(_dateFrom),
      dateTo: _iso(_dateTo),
      locationId: locationId,
    );
    if (jobId == null || !mounted) return;

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
      await api.reportPunchSyncWait(
        jobId,
        onProgress: (message, {int? progress}) {
          dialogState.value = dialogState.value.copyWith(
            message: message.isNotEmpty ? message : dialogState.value.message,
            progress: progress,
          );
        },
      );
    } finally {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      dialogState.dispose();
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
        _error = e.toString();
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
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
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: _loading || !_reportReady ? null : _run,
                      icon: const Icon(Icons.play_arrow),
                      label: Text(context.t('reports.run')),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: _exporting || !_reportReady ? null : _export,
                      icon: const Icon(Icons.download_outlined),
                      label: Text(context.t('reports.exportExcel')),
                    ),
                    const Spacer(),
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
          Expanded(child: _buildResults()),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppThemeV2.primary));
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
