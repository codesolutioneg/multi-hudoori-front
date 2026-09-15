import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/injection.dart';
import '../../core/layout/app_page_scaffold.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme_v2.dart';
import '../../core/utils/file_download.dart';
import '../../core/utils/file_pick.dart';
import '../../core/utils/money_format.dart';
import '../../core/utils/payroll_month.dart';
import '../../core/widgets/employee_search_field.dart';
import '../../core/widgets/list_picker_field.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/sellix_card.dart';
import '../../core/widgets/status_tag.dart';
import '../../l10n/l10n_extension.dart';

String _money(dynamic value) => formatMoney(value, fallback: value?.toString() ?? '');

const _fawryCommissionRate = 0.0015;

double _roundMoney(double value) => (value * 100).roundToDouble() / 100;

({double approved, double commission, double total}) _fawryTotalsFromBatch(
  Map<String, dynamic>? batch,
) {
  final approved = (batch?['fawryApprovedAmount'] as num?)?.toDouble() ??
      (batch?['fawryAmount'] as num?)?.toDouble() ??
      0;
  final commission = (batch?['fawryCommissionAmount'] as num?)?.toDouble() ??
      _roundMoney(approved * _fawryCommissionRate);
  final total = (batch?['fawryAmount'] as num?)?.toDouble() ??
      _roundMoney(approved + commission);
  return (approved: approved, commission: commission, total: total);
}

String _fawryBreakdownLine(
  BuildContext context, {
  required double approved,
  required double commission,
  required double total,
}) =>
    '${context.t('fawryLine.noCommission', {'amount': _money(approved)})}'
    ' • ${context.t('fawryLine.commission', {'amount': _money(commission)})}'
    ' • ${context.t('fawryLine.total', {'amount': _money(total)})}';

String _cashPlusFawryApprovedLine(
  BuildContext context, {
  required double cash,
  required double fawryApproved,
}) =>
    context.t('fawryLine.cashPlus', {
      'amount': _money(_roundMoney(cash + fawryApproved)),
    });

String _primaryLocationFromBatch(Map<String, dynamic>? batch) {
  final primary =
      batch?['primaryLocationName']?.toString().trim() ??
      batch?['locationName']?.toString().trim() ??
      '';
  return primary;
}

String _tipReviewTitle(BuildContext context, Map<String, dynamic>? batch) {
  final primary = _primaryLocationFromBatch(batch);
  if (primary.isEmpty) return context.t('loanImp.reviewTitle');
  return context.t('loanImp.reviewTitleBranch', {'branch': primary});
}

String _sheetHeadlineFromBatch(
  Map<String, dynamic>? batch, {
  bool preferPrimaryLocation = false,
}) {
  final reference = batch?['reference']?.toString() ?? '';
  if (reference.isEmpty) return '';
  if (preferPrimaryLocation) {
    final primary =
        batch?['primaryLocationName']?.toString() ??
        batch?['locationName']?.toString() ??
        '';
    if (primary.trim().isNotEmpty) return '$reference — $primary';
  }
  final mixed = batch?['mixedLocations'] == true ||
      ((batch?['locationCount'] as num?)?.toInt() ?? 0) > 1;
  if (mixed) return '$reference — multiple';
  final lines = (batch?['lines'] as List? ?? []).whereType<Map>();
  final names = <String>{};
  for (final line in lines) {
    final name = line['locationName']?.toString().trim() ?? '';
    if (name.isNotEmpty) names.add(name);
  }
  if (names.length > 1) return '$reference — multiple';
  final loc = names.isEmpty
      ? (batch?['primaryLocationName']?.toString() ??
            batch?['locationName']?.toString() ??
            '')
      : names.first;
  if (loc.trim().isEmpty) return reference;
  return '$reference — $loc';
}

String _fmtDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _locationLabel(Map<String, dynamic> d) {
  final loc = d['locationName']?.toString().trim();
  if (loc != null && loc.isNotEmpty) return loc;
  return d['name']?.toString() ?? d['alias']?.toString() ?? '';
}

enum _ImportPhase { drafts, setup, review }

class AdvanceLoanImportPage extends StatefulWidget {
  const AdvanceLoanImportPage({
    super.key,
    this.initialImportId,
    this.kind = 'loan',
  });

  final String? initialImportId;
  final String kind;

  @override
  State<AdvanceLoanImportPage> createState() => _AdvanceLoanImportPageState();
}

class _AdvanceLoanImportPageState extends State<AdvanceLoanImportPage> {
  bool get _isTip => widget.kind == 'tip';
  Map<String, dynamic>? _batch;
  List<Map<String, dynamic>> _drafts = [];
  List<Map<String, dynamic>> _devices = [];
  List<Map<String, dynamic>> _locations = [];
  bool _loading = true;
  bool _busy = false;
  String? _deviceId;
  final Set<String> _tipLocationIds = {};
  final _dateCtrl = TextEditingController(text: _fmtDate(DateTime.now()));
  final _reasonCtrl = TextEditingController(text: tr('loanImp.eligibilityReason'));
  final _searchCtrl = TextEditingController();
  final _tipsFromCtrl = TextEditingController();
  final _tipsToCtrl = TextEditingController();
  String _statusFilter = '';
  String _approveFilter = '';
  String _jobFilter = '';
  int _sortColumnIndex = 0;
  bool _sortAscending = true;
  DateTime _tipsFrom = DateTime.now();
  DateTime _tipsTo = DateTime.now();

  _ImportPhase _phase = _ImportPhase.drafts;
  bool _odooIntegrationEnabled = false;

  @override
  void initState() {
    super.initState();
    if (widget.kind == 'tip') {
      _reasonCtrl.text = 'tips';
    }
    _init();
  }

  @override
  void dispose() {
    _dateCtrl.dispose();
    _reasonCtrl.dispose();
    _searchCtrl.dispose();
    _tipsFromCtrl.dispose();
    _tipsToCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    setState(() => _loading = true);
    try {
      final devices = await api.devicesList();
      final locations = _isTip ? await api.locationsList() : <Map<String, dynamic>>[];
      final drafts = await api.advanceLoanImportList(kind: widget.kind);
      final initialBatch = widget.initialImportId == null
          ? null
          : await api.advanceLoanImportGet(widget.initialImportId!);
      var odooEnabled = false;
      try {
        final odoo = await api.odooConfigGet();
        final cfg = (odoo['config'] as Map?)?.cast<String, dynamic>() ?? {};
        odooEnabled = cfg['integrationEnabled'] == true;
      } catch (_) {}
      var tipsFrom = DateTime.now();
      var tipsTo = DateTime.now();
      if (widget.kind == 'tip') {
        var startDay = 26;
        try {
          final config = await api.configGet();
          startDay =
              (config['payrollMonthStartDay'] as num?)?.toInt() ?? 26;
        } catch (_) {}
        final now = DateTime.now();
        final range = payrollMonthRange(now, startDay);
        final today = DateTime(now.year, now.month, now.day);
        var to = DateTime(
          range.dateTo.year,
          range.dateTo.month,
          range.dateTo.day,
        );
        if (to.isAfter(today)) to = today;
        tipsFrom = DateTime(
          range.dateFrom.year,
          range.dateFrom.month,
          range.dateFrom.day,
        );
        tipsTo = to;
      }
      if (mounted) {
        setState(() {
          _devices = devices;
          _locations = locations;
          _drafts = drafts;
          _batch = initialBatch;
          _odooIntegrationEnabled = odooEnabled;
          _tipsFrom = tipsFrom;
          _tipsTo = tipsTo;
          _tipsFromCtrl.text = formatIsoDate(tipsFrom);
          _tipsToCtrl.text = formatIsoDate(tipsTo);
          _loading = false;
          _phase = initialBatch == null
              ? _ImportPhase.drafts
              : _ImportPhase.review;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _snack(e.toString());
      }
    }
  }

  String? get _tipsFromIso => _isTip ? formatIsoDate(_tipsFrom) : null;
  String? get _tipsToIso => _isTip ? formatIsoDate(_tipsTo) : null;

  Future<void> _pickTipsBound({required bool from}) async {
    final current = from ? _tipsFrom : _tipsTo;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 366)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (from) {
        _tipsFrom = picked;
        if (_tipsTo.isBefore(_tipsFrom)) _tipsTo = _tipsFrom;
      } else {
        _tipsTo = picked;
        if (_tipsFrom.isAfter(_tipsTo)) _tipsFrom = _tipsTo;
      }
      _tipsFromCtrl.text = formatIsoDate(_tipsFrom);
      _tipsToCtrl.text = formatIsoDate(_tipsTo);
    });
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String? get _importId => _batch?['id']?.toString();

  List<Map<String, dynamic>> get _lines {
    final raw = _batch?['lines'];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  List<String> get _jobTitles {
    final titles = <String>{};
    for (final line in _lines) {
      final job = line['jobTitle']?.toString().trim() ?? '';
      if (job.isNotEmpty) titles.add(job);
    }
    final list = titles.toList()..sort();
    return list;
  }

  List<Map<String, dynamic>> get _filteredLines {
    final q = _searchCtrl.text.trim().toLowerCase();
    final filtered = _lines.where((line) {
      if (q.isNotEmpty) {
        final hay = [
          line['employeeCode'],
          line['employeeName'],
          line['jobTitle'],
          line['locationName'],
        ].map((v) => v?.toString().toLowerCase() ?? '').join(' ');
        if (!hay.contains(q)) return false;
      }
      if (_statusFilter.isNotEmpty &&
          (line['compareStatus']?.toString() ?? '') != _statusFilter) {
        return false;
      }
      if (_approveFilter == 'yes' && line['toApprove'] != true) return false;
      if (_approveFilter == 'no' && line['toApprove'] == true) return false;
      if (_jobFilter.isNotEmpty &&
          (line['jobTitle']?.toString().trim() ?? '') != _jobFilter) {
        return false;
      }
      return true;
    }).toList();
    filtered.sort((a, b) {
      int comparison;
      if (_sortColumnIndex == 2) {
        final aJob = a['jobTitle']?.toString().trim().toLowerCase() ?? '';
        final bJob = b['jobTitle']?.toString().trim().toLowerCase() ?? '';
        comparison = aJob.compareTo(bJob);
      } else {
        final aCode = a['employeeCode']?.toString().trim() ?? '';
        final bCode = b['employeeCode']?.toString().trim() ?? '';
        final aNumber = num.tryParse(aCode);
        final bNumber = num.tryParse(bCode);
        comparison = aNumber != null && bNumber != null
            ? aNumber.compareTo(bNumber)
            : aCode.toLowerCase().compareTo(bCode.toLowerCase());
      }
      return _sortAscending ? comparison : -comparison;
    });
    return filtered;
  }

  bool _showIneligibilityInfo(Map<String, dynamic> line) {
    final status = line['compareStatus']?.toString() ?? '';
    final reason = (line['ineligibilityReason']?.toString() ?? '').trim();
    return reason.isNotEmpty ||
        status == 'not_eligible' ||
        status == 'no_mapping' ||
        status == 'missing_in_eligibility';
  }

  String _ineligibilityReasonText(Map<String, dynamic> line) {
    final reason = (line['ineligibilityReason']?.toString() ?? '').trim();
    if (reason.isNotEmpty) return reason;
    switch (line['compareStatus']?.toString()) {
      case 'no_mapping':
        return context.t('loanImp.reasonNotMapped');
      case 'missing_in_eligibility':
        return context.t('loanImp.reasonNotInSheet');
      default:
        return context.t('loanImp.reasonNotEligible');
    }
  }

  bool get _locked => _batch?['state']?.toString() == 'locked';

  String get _backLabel => widget.initialImportId == null
      ? (_locked
            ? context.t(_isTip ? 'loanImp.backTip' : 'loanImp.backLoan')
            : context.t('loanImp.backDrafts'))
      : context.t(_isTip ? 'loanImp.backTip' : 'loanImp.backLoan');

  Future<void> _loadDrafts() async {
    final drafts = await api.advanceLoanImportList(kind: widget.kind);
    if (!mounted) return;
    setState(() => _drafts = drafts);
  }

  void _startNewImport() {
    setState(() {
      _batch = null;
      _deviceId = null;
      _tipLocationIds.clear();
      _dateCtrl.text = _fmtDate(DateTime.now());
      _reasonCtrl.text = _isTip ? 'Commission' : context.t('loanImp.eligibilityReason');
      _phase = _ImportPhase.setup;
    });
  }

  Future<void> _showDrafts() async {
    if (widget.initialImportId != null) {
      if (mounted) Navigator.of(context).maybePop();
      return;
    }
    if (_locked) {
      if (mounted) context.go(_isTip ? AppRoutes.hrTips : AppRoutes.hrAdvances);
      return;
    }
    setState(() => _busy = true);
    try {
      await _loadDrafts();
      if (!mounted) return;
      setState(() {
        _batch = null;
        _phase = _ImportPhase.drafts;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack(e.toString());
    }
  }

  Future<void> _openDraft(Map<String, dynamic> draft) async {
    setState(() => _busy = true);
    try {
      final batch = await api.advanceLoanImportGet(draft['id']);
      if (!mounted) return;
      setState(() {
        _batch = batch;
        _phase = _ImportPhase.review;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack(e.toString());
    }
  }

  Future<void> _deleteDraft(Map<String, dynamic> draft) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t('loanImp.deleteDraft')),
        content: Text(ctx.t('loanImp.deleteConfirm', {'name': draft['reference'] ?? ctx.t('loanImp.theDraft')})),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.t('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.t('loanImp.delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await api.advanceLoanImportDeleteDraft(draft['id']);
      await _loadDrafts();
      if (!mounted) return;
      setState(() => _busy = false);
      _snack(context.t('loanImp.draftDeleted'));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack(e.toString());
    }
  }

  String _tipLocationSummary() {
    if (_tipLocationIds.isEmpty) return context.t('loanImp.noBranchPicked');
    final names = <String>[];
    for (final loc in _locations) {
      final id = loc['id']?.toString() ?? '';
      if (_tipLocationIds.contains(id)) {
        names.add(loc['name']?.toString() ?? id);
      }
    }
    if (names.isEmpty) return context.t('loanImp.branchCount', {'count': _tipLocationIds.length});
    if (names.length <= 3) return names.join(tr('common.listSeparator'));
    return '${names.take(3).join(tr('common.listSeparator'))} +${names.length - 3}';
  }

  Future<void> _pickTipLocations() async {
    if (_locations.isEmpty) {
      _snack(context.t('loanImp.noLocations'));
      return;
    }
    final selected = await showDialog<Set<String>>(
      context: context,
      builder: (ctx) {
        final selectedIds = Set<String>.from(_tipLocationIds);
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final allIds = _locations
                .map((loc) => loc['id']?.toString() ?? '')
                .where((id) => id.isNotEmpty)
                .toList();
            return AlertDialog(
              title: Text(ctx.t('loanImp.pickBranches')),
              content: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      ctx.t('loanImp.pickBranchesHintTip'),
                      style: TextStyle(fontSize: 13, height: 1.35),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => setLocal(() {
                            selectedIds
                              ..clear()
                              ..addAll(allIds);
                          }),
                          child: Text(ctx.t('loanImp.selectAll')),
                        ),
                        TextButton(
                          onPressed: selectedIds.isEmpty
                              ? null
                              : () => setLocal(() => selectedIds.clear()),
                          child: Text(ctx.t('loanImp.clearSelection')),
                        ),
                        const Spacer(),
                        Text(
                          ctx.t('loanImp.selectedCount', {'count': selectedIds.length}),
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 320),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _locations.length,
                        itemBuilder: (_, i) {
                          final loc = _locations[i];
                          final id = loc['id']?.toString() ?? '';
                          if (id.isEmpty) return const SizedBox.shrink();
                          final name = loc['name']?.toString() ?? id;
                          return CheckboxListTile(
                            dense: true,
                            value: selectedIds.contains(id),
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(
                              name,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onChanged: (v) => setLocal(() {
                              if (v == true) {
                                selectedIds.add(id);
                              } else {
                                selectedIds.remove(id);
                              }
                            }),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(ctx.t('common.cancel')),
                ),
                FilledButton(
                  onPressed: selectedIds.isEmpty
                      ? null
                      : () => Navigator.pop(ctx, selectedIds),
                  child: Text(ctx.t('loanImp.apply')),
                ),
              ],
            );
          },
        );
      },
    );
    if (selected == null || !mounted) return;
    setState(() => _tipLocationIds
      ..clear()
      ..addAll(selected));
  }

  /// Tips: branches chosen once in setup (multi-select).
  List<String>? _resolveTipTemplateLocationIds() {
    if (_tipLocationIds.isEmpty) return null;
    return _tipLocationIds.toList();
  }

  Future<List<String>?> _pickLoanTemplateLocations() async {
    final locations = await api.locationsList();
    if (!mounted) return null;
    if (locations.isEmpty) {
      _snack(context.t('loanImp.noLocations'));
      return null;
    }
    return showDialog<List<String>>(
      context: context,
      builder: (ctx) {
        final selectedIds = <String>{};
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final allIds = locations
                .map((loc) => loc['id']?.toString() ?? '')
                .where((id) => id.isNotEmpty)
                .toList();
            return AlertDialog(
              title: Text(ctx.t('loanImp.pickBranches')),
              content: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      ctx.t('loanImp.pickBranchesHintLoan'),
                      style: TextStyle(fontSize: 13, height: 1.35),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () =>
                          Navigator.pop(ctx, <String>['_blank_multiple_']),
                      icon: const Icon(Icons.note_add_outlined),
                      label: Text(ctx.t('loanImp.blankTemplate')),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => setLocal(() {
                            selectedIds
                              ..clear()
                              ..addAll(allIds);
                          }),
                          child: Text(ctx.t('loanImp.selectAll')),
                        ),
                        TextButton(
                          onPressed: selectedIds.isEmpty
                              ? null
                              : () => setLocal(() => selectedIds.clear()),
                          child: Text(ctx.t('loanImp.clearSelection')),
                        ),
                        const Spacer(),
                        Text(
                          ctx.t('loanImp.selectedCount', {'count': selectedIds.length}),
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 320),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: locations.length,
                        itemBuilder: (_, i) {
                          final loc = locations[i];
                          final id = loc['id']?.toString() ?? '';
                          if (id.isEmpty) return const SizedBox.shrink();
                          final name = loc['name']?.toString() ?? id;
                          return CheckboxListTile(
                            dense: true,
                            value: selectedIds.contains(id),
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(
                              name,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onChanged: (v) => setLocal(() {
                              if (v == true) {
                                selectedIds.add(id);
                              } else {
                                selectedIds.remove(id);
                              }
                            }),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(ctx.t('common.cancel')),
                ),
                FilledButton(
                  onPressed: selectedIds.isEmpty
                      ? null
                      : () => Navigator.pop(ctx, selectedIds.toList()),
                  child: Text(ctx.t('loanImp.downloadTemplate')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _downloadLoanTemplate() async {
    try {
      List<String>? selected;
      if (_isTip) {
        if (_tipsFromIso == null || _tipsToIso == null) {
          _snack(context.t('loanImp.needPeriod'));
          return;
        }
        selected = _resolveTipTemplateLocationIds();
        if (selected == null || selected.isEmpty) {
          _snack(context.t('loanImp.needBranch'));
          return;
        }
      } else {
        selected = await _pickLoanTemplateLocations();
      }
      if (selected == null || selected.isEmpty) return;

      final blank = selected.length == 1 && selected.first == '_blank_multiple_';
      final r = await api.advancesExportImportTemplate(
        locationIds: blank ? null : selected,
        blank: blank,
        kind: widget.kind,
        dateFrom: _tipsFromIso,
        dateTo: _tipsToIso,
      );
      final base64 = r['base64']?.toString() ?? r['file']?.toString() ?? '';
      final filename =
          r['filename']?.toString() ?? 'advances_import_template.xlsx';
      if (base64.isEmpty) throw Exception(context.t('loanImp.emptyFile'));
      downloadBase64File(
        base64,
        filename,
        r['mimeType']?.toString() ??
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      final count = r['count'];
      final fileCount = r['fileCount'];
      final skipped = r['skipped'];
      final skipN = skipped is List ? skipped.length : 0;
      var msg = _isTip
          ? context.t('loanImp.tipTemplateDownloaded', {
              'count': count,
              'branches': fileCount is num && fileCount > 1
                  ? context.t('loanImp.branchesSuffix', {'count': fileCount})
                  : '',
            })
          : (count != null
                ? context.t('loanImp.loanTemplateDownloadedCount', {'count': count})
                : context.t('loanImp.loanTemplateDownloaded'));
      if (!_isTip && fileCount is num && fileCount > 1) {
        msg = context.t('loanImp.downloadedFiles', {'name': filename, 'count': fileCount});
        if (count != null) msg += context.t('loanImp.employeesSuffix', {'count': count});
        msg += ')';
      }
      if (skipN > 0) {
        final names = skipped
            .whereType<Map>()
            .map((s) => s['name']?.toString() ?? '')
            .where((n) => n.isNotEmpty)
            .take(3)
            .join(context.t('common.listSeparator'));
        msg += context.t('loanImp.skippedBranches', {'count': skipN});
        if (names.isNotEmpty) msg += ' ($names${skipN > 3 ? '…' : ''})';
      }
      _snack(msg);
    } catch (e) {
      _snack(e.toString());
    }
  }

  Future<void> _downloadFileFromResult(
    Map<String, dynamic> r, {
    String? okMsg,
  }) async {
    final base64 = r['base64']?.toString() ?? r['file']?.toString() ?? '';
    final filename = r['filename']?.toString() ?? 'file.xlsx';
    if (base64.isEmpty) throw Exception(context.t('loanImp.emptyFile'));
    downloadBase64File(
      base64,
      filename,
      r['mimeType']?.toString() ??
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
    _snack(okMsg ?? context.t('loanImp.downloaded', {'name': filename}));
  }

  Future<bool> _preview({
    required String loanBase64,
    String? eligibilityBase64,
  }) async {
    if (_importId == null) return false;
    setState(() => _busy = true);
    try {
      final batch = await api.advanceLoanImportPreview(
        importId: _importId!,
        loanFileBase64: loanBase64,
        eligibilityFileBase64: eligibilityBase64,
        dateFrom: _tipsFromIso,
        dateTo: _tipsToIso,
      );
      if (mounted) {
        setState(() {
          _batch = batch;
          _busy = false;
          _phase = _ImportPhase.review;
        });
        _snack(context.t('loanImp.previewed', {'count': _lines.length}));
        return true;
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _snack(e.toString());
      }
      return false;
    }
    return false;
  }

  Future<void> _pickLoanAndContinue() async {
    try {
      final loanFile = await pickExcelBase64();
      if (loanFile == null || loanFile.isEmpty) return;
      if (!mounted) return;

      final useEligibility = _isTip
          ? false
          : await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ctx.t('loanImp.eligibilityFileTitle')),
          content: Text(
            ctx.t('loanImp.eligibilityFileBody'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.t('loanImp.no')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.t('loanImp.yes')),
            ),
          ],
        ),
      );

      final batch = await api.advanceLoanImportCreate({
        if (_deviceId != null) 'deviceId': _deviceId,
        'date': _dateCtrl.text.trim(),
        'defaultReason': _reasonCtrl.text.trim(),
        'kind': widget.kind,
      });
      if (!mounted) return;
      setState(() => _batch = batch);

      // Create the draft only after a file is selected, then persist its rows.
      final previewed = await _preview(loanBase64: loanFile);
      if (!previewed) {
        final failedId = batch['id'];
        if (failedId != null) {
          try {
            await api.advanceLoanImportDeleteDraft(failedId);
          } catch (_) {}
        }
        return;
      }

      if (useEligibility == true && mounted && _importId != null) {
        try {
          setState(() => _busy = true);
          // Prefer export from preview lines (includes computed status).
          final generated = await api.advanceLoanImportExportEligibility(
            _importId!,
          );
          await _downloadFileFromResult(
            generated,
            okMsg:
                context.t('loanImp.eligSheetDownloadedState', {'count': generated['count'] ?? ''}),
          );
        } catch (e) {
          // Fallback: generate directly from loan file with live compute.
          final generated = await api.advanceLoanImportEligibilityFromLoan(
            loanFile,
          );
          await _downloadFileFromResult(
            generated,
            okMsg: context.t('loanImp.eligSheetDownloaded', {'count': generated['count'] ?? ''}),
          );
        } finally {
          if (mounted) setState(() => _busy = false);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      _snack(e.toString());
    }
  }

  Future<void> _exportEligibility() async {
    if (_importId == null) return;
    try {
      setState(() => _busy = true);
      final r = await api.advanceLoanImportExportEligibility(_importId!);
      await _downloadFileFromResult(r, okMsg: context.t('loanImp.eligSheetExported'));
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportAccountsSheet() async {
    if (_importId == null) return;
    try {
      setState(() => _busy = true);
      final r = await api.advanceLoanImportExportAccountsSheet(_importId!);
      final cash = r['cashAmount'] ?? 0;
      final fawry = r['fawryAmount'] ?? 0;
      await _downloadFileFromResult(
        r,
        okMsg: context.t('loanImp.loanSheetDownloaded', {'cash': cash, 'fawry': fawry}),
      );
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importEligibility() async {
    if (_importId == null) return;
    try {
      final eligibilityFile = await pickExcelBase64();
      if (eligibilityFile == null || eligibilityFile.isEmpty) return;
      setState(() => _busy = true);
      final batch = await api.advanceLoanImportApplyEligibility(
        importId: _importId!,
        eligibilityFileBase64: eligibilityFile,
      );
      if (!mounted) return;
      setState(() {
        _batch = batch;
        _busy = false;
      });
      _snack(context.t('loanImp.eligUpdated'));
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      _snack(e.toString());
    }
  }

  Future<void> _reimportLoanSheet() async {
    if (_importId == null || _locked) return;
    final loanFile = await pickExcelBase64();
    if (loanFile == null || loanFile.isEmpty || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t(_isTip ? 'loanImp.reuploadTip' : 'loanImp.reuploadLoan')),
        content: Text(
          ctx.t('loanImp.reuploadBody'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.t('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.t('loanImp.mergeFile')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final result = await api.advanceLoanImportMergeLoan(
        importId: _importId!,
        loanFileBase64: loanFile,
        dateFrom: _tipsFromIso,
        dateTo: _tipsToIso,
      );
      if (!mounted) return;
      final import = Map<String, dynamic>.from(
        result['import'] as Map? ?? result,
      );
      final merge = Map<String, dynamic>.from(result['merge'] as Map? ?? {});
      setState(() {
        _batch = import;
        _busy = false;
      });
      _snack(
        context.t('loanImp.merged', {
          'updated': merge['updated'] ?? 0,
          'added': merge['added'] ?? 0,
          'unchanged': merge['unchanged'] ?? 0,
        }),
      );
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      _snack(e.toString());
    }
  }

  Future<void> _addEmployeeManually() async {
    if (_importId == null || _locked) return;
    final values = await showDialog<({String employeeId, double amount})>(
      context: context,
      builder: (_) => _AddLoanEmployeeDialog(isTip: _isTip),
    );
    if (values == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await api.advanceLoanImportLineAddManual(
        importId: _importId!,
        employeeId: values.employeeId,
        requestedAmount: values.amount,
        dateFrom: _tipsFromIso,
        dateTo: _tipsToIso,
      );
      final batch = await api.advanceLoanImportGet(_importId!);
      if (!mounted) return;
      setState(() {
        _batch = batch;
        _busy = false;
      });
      _snack(context.t(_isTip ? 'loanImp.employeeAddedTip' : 'loanImp.employeeAddedLoan'));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack(e.toString());
    }
  }

  Future<bool> _updateLine(
    Map<String, dynamic> line, {
    double? approved,
    bool? toApprove,
  }) async {
    setState(() => _busy = true);
    try {
      await api.advanceLoanImportLineUpdate(
        lineId: line['id'],
        approvedAmount: approved,
        toApprove: toApprove,
      );
      final batch = await api.advanceLoanImportGet(_importId!);
      if (mounted) {
        setState(() {
          _batch = batch;
          _busy = false;
        });
      }
      return true;
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _snack(e.toString());
      }
      return false;
    }
  }

  Future<void> _approve() async {
    if (_importId == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t(_isTip ? 'loanImp.approveTip' : 'loanImp.approveLoan')),
        content: Text(
          _isTip
              ? ctx.t('loanImp.approveBodyTip')
              : ctx.t('loanImp.approveBodyLoan'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.t('loanImp.no')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.t('loanImp.approve')),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      final result = await api.advanceLoanImportApprove(_importId!);
      final batch =
          result['import'] as Map<String, dynamic>? ??
          await api.advanceLoanImportGet(_importId!);
      if (mounted) {
        setState(() {
          _batch = batch;
          _busy = false;
        });
        _snack(
        _isTip
            ? context.t('loanImp.approvedTip', {'count': result['created'] ?? 0})
            : context.t('loanImp.approvedLoan', {'count': result['created'] ?? 0}),
      );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _snack(e.toString());
      }
    }
  }

  Future<void> _sendToOdooAccounts() async {
    if (_importId == null) return;
    if (_batch?['odooAccountsSendId'] != null) {
      _snack(
        context.t('loanImp.alreadySent', {'ref': _batch?['odooSendRef'] ?? _batch?['odooAccountsSendId']}),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t('loanImp.sendToOdoo')),
        content: Text(
          ctx.t('loanImp.sendToOdooBody'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.t('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.t('loanImp.send')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final result = await api.advanceLoanImportSendToOdooAccounts(_importId!);
      final batch = await api.advanceLoanImportGet(_importId!);
      if (!mounted) return;
      setState(() {
        _batch = batch;
        _busy = false;
      });
      final email = (result['email'] as Map?)?.cast<String, dynamic>() ?? {};
      if (email['sent'] == true) {
        _snack(context.t('loanImp.sentOk'));
      } else {
        _snack(
          context.t('loanImp.sentMailPartial'),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _snack(e.toString());
      }
    }
  }

  Future<void> _resendNotificationEmail() async {
    if (_importId == null) return;
    setState(() => _busy = true);
    try {
      final result = await api.advanceLoanImportResendNotificationEmail(
        _importId!,
      );
      final batch = await api.advanceLoanImportGet(_importId!);
      if (!mounted) return;
      final email = (result['email'] as Map?)?.cast<String, dynamic>() ?? {};
      setState(() {
        _batch = batch;
        _busy = false;
      });
      _snack(
        email['sent'] == true
            ? context.t('loanImp.mailOk')
            : context.t('loanImp.mailFail'),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _snack(e.toString());
      }
    }
  }

  String _statusAr(String s) {
    switch (s) {
      case 'ready':
        return context.t('loanImp.stReady');
      case 'not_eligible':
        return context.t('loanImp.stNotEligible');
      case 'missing_in_eligibility':
        return context.t('loanImp.stNotFound');
      case 'no_mapping':
        return context.t('loanImp.stNoMapping');
      case 'approved':
        return context.t('loanImp.stApproved');
      default:
        return s;
    }
  }

  StatusTagType _statusTag(String s) {
    if (s == 'ready' || s == 'approved') return StatusTagType.success;
    if (s == 'no_mapping' || s == 'missing_in_eligibility') {
      return StatusTagType.danger;
    }
    return StatusTagType.warning;
  }

  Widget _buildDrafts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FilledButton.icon(
            onPressed: _busy ? null : _startNewImport,
            icon: const Icon(Icons.add),
            label: Text(context.t(_isTip ? 'loanImp.newImportTip' : 'loanImp.newImportLoan')),
          ),
        ),
        const SizedBox(height: 12),
        if (_drafts.isEmpty)
          SellixCard(
            child: Text(
              _isTip
                  ? context.t('loanImp.noDraftsTip')
                  : context.t('loanImp.noDraftsLoan'),
            ),
          )
        else
          SellixCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < _drafts.length; i++) ...[
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: Text(
                      _sheetHeadlineFromBatch(
                        _drafts[i],
                        preferPrimaryLocation: _isTip,
                      ).isNotEmpty
                          ? _sheetHeadlineFromBatch(
                              _drafts[i],
                              preferPrimaryLocation: _isTip,
                            )
                          : (_drafts[i]['reference']?.toString() ??
                              context.t(_isTip ? 'loanImp.draftTip' : 'loanImp.draftLoan')),
                    ),
                    subtitle: Text(
                      '${_drafts[i]['locationName'] ?? context.t('loanImp.noBranch')}'
                      ' • ${context.t('loanImp.employeeCount', {'count': _drafts[i]['lineCount'] ?? 0})}'
                      ' • ${_drafts[i]['date'] ?? ''}',
                    ),
                    onTap: _busy ? null : () => _openDraft(_drafts[i]),
                    trailing: IconButton(
                      tooltip: context.t('loanImp.deleteDraft'),
                      onPressed: _busy ? null : () => _deleteDraft(_drafts[i]),
                      icon: const Icon(
                        Icons.delete_outline,
                        color: AppColors.danger,
                      ),
                    ),
                  ),
                  if (i < _drafts.length - 1) const Divider(height: 1),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSetup() {
    return SellixCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: _busy ? null : _showDrafts,
              icon: const Icon(Icons.arrow_back, size: 18),
              label: Text(_backLabel),
            ),
          ),
          const SizedBox(height: 8),
          if (_isTip) ...[
            InputDecorator(
              decoration: InputDecoration(
                labelText: context.t('loanImp.branches'),
                border: OutlineInputBorder(),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _tipLocationSummary(),
                      style: TextStyle(
                        fontSize: 13,
                        color: _tipLocationIds.isEmpty
                            ? AppColors.textSecondary
                            : null,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _busy ? null : _pickTipLocations,
                    child: Text(
                      _tipLocationIds.isEmpty
                          ? context.t('loanImp.pickBranches')
                          : context.t('loanImp.editCount', {'count': _tipLocationIds.length}),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (_devices.isNotEmpty)
            ListPickerField<String>(
              label: context.t('loanImp.location'),
              value: _deviceId ?? '',
              options: [
                (value: '', label: context.t('loanImp.allLocations')),
                for (final d in _devices)
                  (value: d['id']?.toString() ?? '', label: _locationLabel(d)),
              ],
              onChanged: (v) =>
                  setState(() => _deviceId = v.isEmpty ? null : v),
            ),
          const SizedBox(height: 8),
          TextField(
            controller: _dateCtrl,
            readOnly: true,
            enabled: !_locked,
            decoration: InputDecoration(
              labelText: context.t(_isTip ? 'loanImp.dateTip' : 'loanImp.dateLoan'),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _reasonCtrl,
            enabled: !_locked,
            decoration: InputDecoration(
              labelText: _isTip
                  ? context.t('loanImp.reasonDefaultTip')
                  : context.t('loanImp.reasonDefaultLoan'),
            ),
          ),
          if (_isTip) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    readOnly: true,
                    controller: _tipsFromCtrl,
                    decoration: InputDecoration(
                      labelText: context.t('loanImp.workDaysFrom'),
                    ),
                    onTap: _busy ? null : () => _pickTipsBound(from: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    readOnly: true,
                    controller: _tipsToCtrl,
                    decoration: InputDecoration(
                      labelText: context.t('loanImp.workDaysTo'),
                    ),
                    onTap: _busy ? null : () => _pickTipsBound(from: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              context.t('loanImp.periodHint'),
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 12),
          if (!_locked) ...[
            OutlinedButton.icon(
              onPressed: _busy ? null : _downloadLoanTemplate,
              icon: const Icon(Icons.download_outlined, size: 18),
              label: Text(
                context.t(_isTip ? 'loanImp.downloadTemplateTip' : 'loanImp.downloadTemplateLoan'),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _busy ? null : _pickLoanAndContinue,
              icon: const Icon(Icons.upload_file_outlined),
              label: Text(
                context.t(_isTip ? 'loanImp.uploadTip' : 'loanImp.uploadLoan'),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isTip
                  ? context.t('loanImp.uploadHintTip')
                  : context.t('loanImp.uploadHintLoan'),
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SellixCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.fact_check_outlined,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isTip
                          ? _tipReviewTitle(context, _batch)
                          : context.t('loanImp.reviewEligTitleRef', {'ref': _batch?['reference'] ?? ''}),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _isTip
                    ? context.t('loanImp.reviewHintTip')
                    : context.t('loanImp.reviewHintLoan'),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              if (_isTip) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        readOnly: true,
                        controller: _tipsFromCtrl,
                        decoration: InputDecoration(
                          labelText: context.t('loanImp.workDaysFrom'),
                        ),
                        onTap: _busy ? null : () => _pickTipsBound(from: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        readOnly: true,
                        controller: _tipsToCtrl,
                        decoration: InputDecoration(
                          labelText: context.t('loanImp.workDaysTo'),
                        ),
                        onTap: _busy ? null : () => _pickTipsBound(from: false),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              if (!_locked)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _showDrafts,
                      icon: const Icon(Icons.arrow_back, size: 18),
                      label: Text(_backLabel),
                    ),
                    if (!_isTip) ...[
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _exportEligibility,
                      icon: const Icon(Icons.download_outlined, size: 18),
                      label: Text(context.t('loanImp.exportEligSheet')),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: _busy ? null : _importEligibility,
                      icon: const Icon(Icons.upload_file_outlined, size: 18),
                      label: Text(context.t('loanImp.importEligSheet')),
                    ),
                    ],
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _reimportLoanSheet,
                      icon: const Icon(Icons.upload_outlined, size: 18),
                      label: Text(
                        context.t(_isTip ? 'loanImp.reuploadTip' : 'loanImp.reuploadLoan'),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _addEmployeeManually,
                      icon: const Icon(
                        Icons.person_add_alt_1_outlined,
                        size: 18,
                      ),
                      label: Text(context.t('loanImp.addEmployee')),
                    ),
                    OutlinedButton.icon(
                      onPressed: _busy || _lines.isEmpty
                          ? null
                          : _exportAccountsSheet,
                      icon: const Icon(Icons.table_view_outlined, size: 18),
                      label: Text(
                        _isTip
                            ? context.t('loanImp.downloadTipSheet')
                            : context.t('loanImp.downloadLoanSheet'),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _busy || _lines.isEmpty ? null : _approve,
                      icon: const Icon(Icons.check, size: 18),
                      label: Text(
                        context.t(_isTip ? 'loanImp.approveTip' : 'loanImp.approveCreateLoans'),
                      ),
                    ),
                  ],
                ),
              if (_locked) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _isTip
                        ? context.t('loanImp.lockedTip')
                        : context.t('loanImp.lockedLoan'),
                    style: const TextStyle(color: AppColors.success),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _showDrafts,
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: Text(_backLabel),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _busy || _lines.isEmpty
                      ? null
                      : _exportAccountsSheet,
                  icon: const Icon(Icons.table_view_outlined, size: 18),
                  label: Text(
                    _isTip
                        ? context.t('loanImp.downloadTipSheet')
                        : context.t('loanImp.downloadLoanSheet'),
                  ),
                ),
                if (_odooIntegrationEnabled && !_isTip) ...[
                  const SizedBox(height: 12),
                  if (_batch?['odooAccountsSendId'] != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${context.t('loanImp.sentToOdooRef', {'ref': _batch?['odooSendRef'] ?? _batch?['odooAccountsSendId']})}'
                          '${_batch?['odooMoveId'] != null ? context.t('loanImp.moveSuffix', {'id': _batch?['odooMoveId']}) : ''}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (_batch?['notificationEmailsSentAt'] != null)
                          Text(
                            context.t('loanImp.mailSentBranches'),
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.success,
                            ),
                          )
                        else if ((_batch?['notificationEmailError']
                                ?.toString()
                                .isNotEmpty ??
                            false)) ...[
                          Text(
                            context.t('loanImp.mailError', {'error': _batch?['notificationEmailError']}),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.warning,
                            ),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _busy ? null : _resendNotificationEmail,
                            icon: const Icon(Icons.refresh, size: 18),
                            label: Text(context.t('loanImp.resendMail')),
                          ),
                        ],
                      ],
                    )
                  else
                    FilledButton.icon(
                      onPressed: _busy ? null : _sendToOdooAccounts,
                      icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                      label: Text(context.t('loanImp.sendToOdoo')),
                    ),
                ],
              ],
            ],
          ),
        ),
        if (_batch?['cashAmount'] != null || _batch?['fawryAmount'] != null) ...[
          const SizedBox(height: 8),
          SellixCard(
            child: Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                if (_isTip) ...[
                  Builder(
                    builder: (context) {
                      final cash =
                          (_batch?['cashAmount'] as num?)?.toDouble() ?? 0;
                      final fawry = _fawryTotalsFromBatch(_batch);
                      return Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        children: [
                          Text(
                            context.t('loanImp.cash', {'amount': _money(cash)}),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            _fawryBreakdownLine(
                              context,
                              approved: fawry.approved,
                              commission: fawry.commission,
                              total: fawry.total,
                            ),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            _cashPlusFawryApprovedLine(
                              context,
                              cash: cash,
                              fawryApproved: fawry.approved,
                            ),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            context.t('loanImp.total', {'amount': _money(_batch?['totalAmount'])}),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                      );
                    },
                  ),
                ] else ...[
                  Text(
                    context.t('loanImp.cash', {'amount': _money(_batch?['cashAmount'])}),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    context.t('loanImp.fawry', {'amount': _money(_batch?['fawryAmount'])}),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    context.t('loanImp.total', {'amount': _money(_batch?['totalAmount'])}),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (_lines.isEmpty)
          SellixCard(child: Text(context.t('loanImp.noLines')))
        else
          SellixCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.end,
                    children: [
                      SizedBox(
                        width: 280,
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: context.t('loanImp.searchCodeNameJob'),
                            hintText: context.t('loanImp.searchHint'),
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: AppThemeV2.surfaceElevated,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 200,
                        child: ListPickerField<String>(
                          label: context.t('loanImp.state'),
                          value: _statusFilter,
                          hint: context.t('loanImp.allStates'),
                          options: [
                            (value: '', label: context.t('loanImp.allStates')),
                            (value: 'ready', label: context.t('loanImp.stReady')),
                            (value: 'not_eligible', label: context.t('loanImp.stNotEligible')),
                            (
                              value: 'missing_in_eligibility',
                              label: context.t('loanImp.stNotFound'),
                            ),
                            (value: 'no_mapping', label: context.t('loanImp.stNoMapping')),
                            (value: 'approved', label: context.t('loanImp.stApproved')),
                          ],
                          onChanged: (v) => setState(() => _statusFilter = v),
                        ),
                      ),
                      SizedBox(
                        width: 180,
                        child: ListPickerField<String>(
                          label: context.t('loanImp.approval'),
                          value: _approveFilter,
                          hint: context.t('loanImp.all'),
                          options: [
                            (value: '', label: context.t('loanImp.all')),
                            (value: 'yes', label: context.t('loanImp.checked')),
                            (value: 'no', label: context.t('loanImp.unchecked')),
                          ],
                          onChanged: (v) => setState(() => _approveFilter = v),
                        ),
                      ),
                      SizedBox(
                        width: 220,
                        child: ListPickerField<String>(
                          label: context.t('loanImp.jobTitle'),
                          value: _jobFilter,
                          hint: context.t('loanImp.allJobs'),
                          options: [
                            (value: '', label: context.t('loanImp.allJobs')),
                            for (final job in _jobTitles)
                              (value: job, label: job),
                          ],
                          onChanged: (v) => setState(() => _jobFilter = v),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_filteredLines.isEmpty)
                  Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Text(context.t('loanImp.noMatches')),
                  )
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      sortColumnIndex: _sortColumnIndex,
                      sortAscending: _sortAscending,
                      columns: [
                        DataColumn(
                          label: Text(context.t('loanImp.colCode')),
                          onSort: (columnIndex, ascending) => setState(() {
                            _sortColumnIndex = columnIndex;
                            _sortAscending = ascending;
                          }),
                        ),
                        DataColumn(label: Text(context.t('loanImp.colName'))),
                        DataColumn(
                          label: Text(context.t('loanImp.jobTitle')),
                          onSort: (columnIndex, ascending) => setState(() {
                            _sortColumnIndex = columnIndex;
                            _sortAscending = ascending;
                          }),
                        ),
                        DataColumn(label: Text(context.t('loanImp.colBranch'))),
                        DataColumn(label: Text(context.t('loanImp.colRequested'))),
                        DataColumn(label: Text(context.t('loanImp.colEligible'))),
                        DataColumn(label: Text(context.t('loanImp.colDays'))),
                        DataColumn(label: Text(context.t('loanImp.colCashFawry'))),
                        DataColumn(label: Text(context.t('loanImp.colApproved'))),
                        DataColumn(label: Text(context.t('loanImp.state'))),
                        DataColumn(label: Text(context.t('loanImp.colApproval'))),
                      ],
                      rows: [
                        for (final line in _filteredLines)
                          DataRow(
                            cells: [
                              DataCell(
                                Text(line['employeeCode']?.toString() ?? ''),
                              ),
                              DataCell(
                                Text(line['employeeName']?.toString() ?? ''),
                              ),
                              DataCell(
                                Text(line['jobTitle']?.toString() ?? ''),
                              ),
                              DataCell(
                                Text(line['locationName']?.toString() ?? ''),
                              ),
                              DataCell(Text(_money(line['requestedAmount']))),
                              DataCell(
                                line['eligibilityOverridden'] == true
                                    ? Tooltip(
                                        message:
                                            context.t('loanImp.manualOverride', {'amount': _money(line['systemEligibleAmount'])}),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(_money(line['eligibleAmount'])),
                                            const SizedBox(width: 4),
                                            const Icon(
                                              Icons.edit_note,
                                              size: 16,
                                              color: AppColors.warning,
                                            ),
                                          ],
                                        ),
                                      )
                                    : Text(_money(line['eligibleAmount'])),
                              ),
                              DataCell(
                                Text('${line['actualWorkingDays'] ?? ''}'),
                              ),
                              DataCell(
                                StatusTag(
                                  label: context.t(line['isFawry'] == true ? 'loanImp.tagFawry' : 'loanImp.tagCash'),
                                  type: line['isFawry'] == true
                                      ? StatusTagType.info
                                      : StatusTagType.success,
                                ),
                              ),
                              DataCell(
                                _locked
                                    ? Text(_money(line['approvedAmount']))
                                    : _ApprovedAmountField(
                                        key: ValueKey(line['id']),
                                        value:
                                            (line['approvedAmount'] as num?) ??
                                            0,
                                        onSubmit: (v) =>
                                            _updateLine(line, approved: v),
                                      ),
                              ),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    StatusTag(
                                      label: _statusAr(
                                        line['compareStatus']?.toString() ?? '',
                                      ),
                                      type: _statusTag(
                                        line['compareStatus']?.toString() ?? '',
                                      ),
                                    ),
                                    if (_showIneligibilityInfo(line))
                                      IconButton(
                                        tooltip: context.t('loanImp.notEligibleReason'),
                                        icon: const Icon(
                                          Icons.info_outline,
                                          size: 18,
                                          color: AppColors.warning,
                                        ),
                                        onPressed: () => showDialog<void>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: Text(
                                              context.t('loanImp.notEligibleReason'),
                                            ),
                                            content: Text(
                                              _ineligibilityReasonText(line),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx),
                                                child: Text(context.t('common.close')),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              DataCell(
                                Checkbox(
                                  value: line['toApprove'] == true,
                                  onChanged: _locked
                                      ? null
                                      : (v) => _updateLine(
                                          line,
                                          toApprove: v ?? false,
                                        ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      scrollable: false,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  PageHeader(
                    title: switch (_phase) {
                      _ImportPhase.drafts =>
                        context.t(_isTip ? 'loanImp.navDraftsTip' : 'loanImp.navDraftsLoan'),
                      _ImportPhase.setup =>
                        context.t(_isTip ? 'loanImp.navUploadTip' : 'loanImp.navUploadLoan'),
                      _ImportPhase.review =>
                        _isTip ? _tipReviewTitle(context, _batch) : context.t('loanImp.reviewEligTitle'),
                    },
                    subtitle: _phase == _ImportPhase.review
                        ? (_isTip
                            ? (_batch?['reference']?.toString() ?? '')
                            : _sheetHeadlineFromBatch(_batch))
                        : (_batch?['reference']?.toString() ?? ''),
                    icon: switch (_phase) {
                      _ImportPhase.drafts => Icons.drafts_outlined,
                      _ImportPhase.setup => Icons.upload_file_outlined,
                      _ImportPhase.review => Icons.fact_check_outlined,
                    },
                  ),
                  if (_busy) const LinearProgressIndicator(),
                  switch (_phase) {
                    _ImportPhase.drafts => _buildDrafts(),
                    _ImportPhase.setup => _buildSetup(),
                    _ImportPhase.review => _buildReview(),
                  },
                ],
              ),
            ),
    );
  }
}

class _AddLoanEmployeeDialog extends StatefulWidget {
  const _AddLoanEmployeeDialog({this.isTip = false});
  final bool isTip;

  @override
  State<_AddLoanEmployeeDialog> createState() => _AddLoanEmployeeDialogState();
}

class _AddLoanEmployeeDialogState extends State<_AddLoanEmployeeDialog> {
  final _amountCtrl = TextEditingController();
  String? _employeeId;
  String _employeeName = '';

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (_employeeId == null || amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t('loanImp.addNeedsInput')),
        ),
      );
      return;
    }
    Navigator.pop(context, (employeeId: _employeeId!, amount: amount));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.t(widget.isTip ? 'loanImp.addEmployeeTip' : 'loanImp.addEmployeeLoan')),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.isTip
                  ? context.t('loanImp.addHintTip')
                  : context.t('loanImp.addHintLoan'),
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            EmployeeSearchField(
              includeInactive: widget.isTip,
              onSelected: (employeeId, name) {
                setState(() {
                  _employeeId = employeeId;
                  _employeeName = name;
                });
              },
            ),
            if (_employeeName.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                context.t('loanImp.employeeLine', {'name': _employeeName}),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: context.t(widget.isTip ? 'loanImp.amountTip' : 'loanImp.amountLoan'),
                prefixIcon: const Icon(Icons.payments_outlined),
              ),
            ),
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
          icon: const Icon(Icons.person_add_alt_1),
          label: Text(context.t('loanImp.addAndCompute')),
        ),
      ],
    );
  }
}

/// Approved amount cell that also saves when the field loses focus, so a typed
/// value is never silently dropped by navigating away without pressing Enter.
class _ApprovedAmountField extends StatefulWidget {
  const _ApprovedAmountField({
    super.key,
    required this.value,
    required this.onSubmit,
  });

  final num value;
  final Future<bool> Function(double) onSubmit;

  @override
  State<_ApprovedAmountField> createState() => _ApprovedAmountFieldState();
}

class _ApprovedAmountFieldState extends State<_ApprovedAmountField> {
  late final TextEditingController _controller = TextEditingController(
    text: formatMoneyField(widget.value),
  );
  final FocusNode _focusNode = FocusNode();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(_ApprovedAmountField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && !_focusNode.hasFocus) {
      _controller.text = formatMoneyField(widget.value);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus) _save();
  }

  Future<void> _save() async {
    if (_saving) return;
    final parsed = parseMoney(_controller.text);
    if (parsed == null || parsed == widget.value) {
      _controller.text = formatMoneyField(widget.value);
      return;
    }
    _saving = true;
    final saved = await widget.onSubmit(parsed);
    _saving = false;
    if (!mounted) return;
    if (!saved) {
      _controller.text = formatMoneyField(widget.value);
    } else {
      _controller.text = formatMoneyField(parsed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 110,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onSubmitted: (_) => _save(),
      ),
    );
  }
}
