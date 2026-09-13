import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/di/injection.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/file_download.dart';
import '../../core/utils/file_pick.dart';
import '../../core/utils/money_format.dart';
import '../../core/utils/payroll_month.dart';
import '../../l10n/l10n_extension.dart';

/// Odoo-like deductions wizard: multi-branch scope + export + import + mass equal-split.
class DeductionsWizardDialog extends StatefulWidget {
  const DeductionsWizardDialog({
    super.key,
    required this.types,
    required this.locations,
  });

  final List<Map<String, dynamic>> types;
  final List<Map<String, dynamic>> locations;

  @override
  State<DeductionsWizardDialog> createState() => _DeductionsWizardDialogState();
}

class _DeductionsWizardDialogState extends State<DeductionsWizardDialog> {
  final Set<String> _locationIds = {};
  String? _type;
  final Set<String> _selectedJobTitles = {};
  List<String> _availableJobTitles = [];
  late final TextEditingController _dateFrom;
  late final TextEditingController _dateTo;
  late final TextEditingController _deductionDate;
  late final TextEditingController _totalAmount;
  int _monthStartDay = 26;
  String _periodFrom = '';
  String _periodTo = '';
  bool _configLoading = true;
  int _scopeCount = 0;
  bool _busy = false;
  bool _parentRefreshPending = false;
  String? _status;
  List<Map<String, dynamic>> _distributeLines = [];
  List<Map<String, dynamic>> _importSkipped = [];

  List<String> get _selectedLocationIds => _locationIds.toList();

  List<String>? get _apiJobTitles =>
      _selectedJobTitles.isEmpty ? null : _selectedJobTitles.toList();

  String get _locationsSummary {
    if (_locationIds.isEmpty) return context.t('wiz.notSet');
    final names = <String>[];
    for (final loc in widget.locations) {
      final id = loc['id']?.toString() ?? '';
      if (_locationIds.contains(id)) {
        names.add(loc['name']?.toString() ?? id);
      }
    }
    if (names.length <= 2) return names.join(tr('common.listSeparator'));
    return '${names.take(2).join(tr('common.listSeparator'))} +${names.length - 2}';
  }

  String get _jobTitlesSummary {
    if (_selectedJobTitles.isEmpty) return context.t('wiz.allJobTitles');
    if (_selectedJobTitles.length <= 2) {
      return _selectedJobTitles.join(tr('common.listSeparator'));
    }
    return '${_selectedJobTitles.take(2).join(tr('common.listSeparator'))} '
        '+${_selectedJobTitles.length - 2}';
  }

  @override
  void initState() {
    super.initState();
    _dateFrom = TextEditingController();
    _dateTo = TextEditingController();
    _deductionDate = TextEditingController();
    _totalAmount = TextEditingController();
    if (widget.locations.isNotEmpty) {
      final first = widget.locations.first['id']?.toString();
      if (first != null && first.isNotEmpty) _locationIds.add(first);
    }
    if (widget.types.isNotEmpty) {
      _type = widget.types.first['value']?.toString();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _initPeriod());
  }

  DateTime _todayUtc() {
    final n = DateTime.now();
    return DateTime.utc(n.year, n.month, n.day);
  }

  bool get _atCurrentPeriod {
    final current = payrollMonthRange(_todayUtc(), _monthStartDay);
    return _periodFrom == formatIsoDate(current.dateFrom);
  }

  List<({String from, String to})> get _periodChoices {
    final out = <({String from, String to})>[];
    var ref = _todayUtc();
    for (var i = 0; i < 12; i++) {
      final r = payrollMonthRange(ref, _monthStartDay);
      out.add((from: formatIsoDate(r.dateFrom), to: formatIsoDate(r.dateTo)));
      ref = r.dateFrom.subtract(const Duration(days: 1));
    }
    if (_periodFrom.isNotEmpty && !out.any((p) => p.from == _periodFrom)) {
      out.insert(0, (from: _periodFrom, to: _periodTo));
    }
    return out;
  }

  void _applyPeriod(String periodFrom) {
    final choice = _periodChoices.firstWhere(
      (p) => p.from == periodFrom,
      orElse: () => _periodChoices.first,
    );
    _periodFrom = choice.from;
    _periodTo = choice.to;
    _dateFrom.text = choice.from;
    _dateTo.text = choice.to;
    _deductionDate.text = choice.to;
  }

  Future<void> _initPeriod() async {
    try {
      final config = await api.configGet();
      _monthStartDay = (config['payrollMonthStartDay'] as num?)?.toInt() ?? 26;
    } catch (_) {}
    _applyPeriod(formatIsoDate(payrollMonthRange(_todayUtc(), _monthStartDay).dateFrom));
    if (!mounted) return;
    setState(() => _configLoading = false);
    await _refreshScope();
  }

  void _selectPeriod(String periodFrom) {
    if (periodFrom == _periodFrom || _busy) return;
    setState(() {
      _applyPeriod(periodFrom);
      _distributeLines = [];
    });
    _refreshScope();
  }

  void _shiftPeriod(int direction) {
    if (_busy || _configLoading) return;
    final from = parseIsoDate(_periodFrom);
    final to = parseIsoDate(_periodTo);
    if (from == null || to == null) return;
    if (direction > 0 && _atCurrentPeriod) return;
    final ref = direction < 0
        ? from.subtract(const Duration(days: 1))
        : to.add(const Duration(days: 1));
    _selectPeriod(formatIsoDate(ref));
  }

  @override
  void dispose() {
    _dateFrom.dispose();
    _dateTo.dispose();
    _deductionDate.dispose();
    _totalAmount.dispose();
    super.dispose();
  }

  Widget _periodSelector() {
    if (_configLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final choices = _periodChoices;
    final currentFrom = formatIsoDate(
      payrollMonthRange(_todayUtc(), _monthStartDay).dateFrom,
    );
    final value = choices.any((p) => p.from == _periodFrom)
        ? _periodFrom
        : (choices.isNotEmpty ? choices.first.from : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.t('wiz.payrollPeriod'),
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            IconButton(
              tooltip: context.t('wiz.previousPeriod'),
              onPressed: _busy || _periodFrom.isEmpty ? null : () => _shiftPeriod(-1),
              icon: const Icon(Icons.arrow_back),
            ),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: value,
                isExpanded: true,
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                items: [
                  for (final p in choices)
                    DropdownMenuItem(
                      value: p.from,
                      child: Text(
                        p.from == currentFrom
                            ? context.t('wiz.periodCurrent', {'from': p.from, 'to': p.to})
                            : '${p.from} → ${p.to}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: _busy ? null : (v) {
                  if (v != null) _selectPeriod(v);
                },
              ),
            ),
            IconButton(
              tooltip: context.t('wiz.nextPeriod'),
              onPressed: _busy || _periodFrom.isEmpty || _atCurrentPeriod
                  ? null
                  : () => _shiftPeriod(1),
              icon: const Icon(Icons.arrow_forward),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _deductionDate,
          readOnly: true,
          decoration: InputDecoration(
            labelText: context.t('wiz.deductionDate'),
            helperText: _periodTo.isEmpty
                ? context.t('wiz.autoDate')
                : context.t('wiz.autoDateWith', {'date': _periodTo}),
            suffixIcon: const Icon(Icons.event_outlined, size: 18),
          ),
        ),
      ],
    );
  }

  Future<void> _pickLocations() async {
    final selected = await showDialog<Set<String>>(
      context: context,
      builder: (ctx) {
        final selectedIds = Set<String>.from(_locationIds);
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final allIds = widget.locations
                .map((loc) => loc['id']?.toString() ?? '')
                .where((id) => id.isNotEmpty)
                .toList();
            return AlertDialog(
              title: Text(context.t('wiz.pickBranches')),
              content: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      context.t('wiz.branchesHint'),
                      style: const TextStyle(fontSize: 13, height: 1.35),
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
                          child: Text(context.t('common.selectAll')),
                        ),
                        TextButton(
                          onPressed: selectedIds.isEmpty
                              ? null
                              : () => setLocal(() => selectedIds.clear()),
                          child: Text(context.t('common.clearSelection')),
                        ),
                        const Spacer(),
                        Text(
                          context.t('grid.selectedCount', {'count': selectedIds.length}),
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 320),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: widget.locations.length,
                        itemBuilder: (_, i) {
                          final loc = widget.locations[i];
                          final id = loc['id']?.toString() ?? '';
                          if (id.isEmpty) return const SizedBox.shrink();
                          final name = loc['name']?.toString() ?? id;
                          final checked = selectedIds.contains(id);
                          return CheckboxListTile(
                            dense: true,
                            value: checked,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(name, overflow: TextOverflow.ellipsis),
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
                  child: Text(context.t('common.cancel')),
                ),
                FilledButton(
                  onPressed: selectedIds.isEmpty
                      ? null
                      : () => Navigator.pop(ctx, selectedIds),
                  child: Text(context.t('common.apply')),
                ),
              ],
            );
          },
        );
      },
    );
    if (selected == null) return;
    setState(() {
      _locationIds
        ..clear()
        ..addAll(selected);
      _selectedJobTitles.clear();
      _distributeLines = [];
    });
    await _refreshScope();
  }

  Future<void> _pickJobTitles() async {
    if (_availableJobTitles.isEmpty) {
      setState(() => _status = context.t('wiz.noJobTitlesInScope'));
      return;
    }
    final selected = await showDialog<Set<String>>(
      context: context,
      builder: (ctx) {
        final selectedTitles = Set<String>.from(_selectedJobTitles);
        return StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            title: Text(context.t('wiz.pickJobTitles')),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.t('wiz.jobTitlesHint'),
                    style: TextStyle(fontSize: 13, height: 1.35),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => setLocal(() => selectedTitles.clear()),
                        child: Text(context.t('wiz.allJobTitles')),
                      ),
                      TextButton(
                        onPressed: () => setLocal(() {
                          selectedTitles
                            ..clear()
                            ..addAll(_availableJobTitles);
                        }),
                        child: Text(context.t('common.selectAll')),
                      ),
                      const Spacer(),
                      Text(
                        selectedTitles.isEmpty
                            ? context.t('common.all')
                            : context.t('grid.selectedCount', {'count': selectedTitles.length}),
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
                      itemCount: _availableJobTitles.length,
                      itemBuilder: (_, i) {
                        final title = _availableJobTitles[i];
                        return CheckboxListTile(
                          dense: true,
                          value: selectedTitles.contains(title),
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(title, overflow: TextOverflow.ellipsis),
                          onChanged: (v) => setLocal(() {
                            if (v == true) {
                              selectedTitles.add(title);
                            } else {
                              selectedTitles.remove(title);
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
                child: Text(context.t('common.cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, selectedTitles),
                child: Text(context.t('common.apply')),
              ),
            ],
          ),
        );
      },
    );
    if (selected == null) return;
    setState(() {
      _selectedJobTitles
        ..clear()
        ..addAll(selected);
      _distributeLines = [];
    });
    await _refreshScope();
  }

  Future<void> _refreshScope() async {
    final locs = _selectedLocationIds;
    if (locs.isEmpty) {
      setState(() {
        _scopeCount = 0;
        _availableJobTitles = [];
        _selectedJobTitles.clear();
      });
      return;
    }
    try {
      final from = _dateFrom.text.trim();
      final to = _dateTo.text.trim();
      final countData = await api.deductionScopeCount(
        locationIds: locs,
        dateFrom: from.isEmpty ? null : from,
        dateTo: to.isEmpty ? null : to,
        jobTitles: _apiJobTitles,
      );
      final jobs = await api.deductionJobTitles(
        locationIds: locs,
        dateFrom: from.isEmpty ? null : from,
        dateTo: to.isEmpty ? null : to,
      );
      if (!mounted) return;
      setState(() {
        _scopeCount = (countData['count'] as num?)?.toInt() ?? 0;
        _availableJobTitles = jobs;
        _selectedJobTitles.removeWhere((t) => !jobs.contains(t));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = e.toString());
    }
  }

  Future<bool> _confirm(String title, String body) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.t('common.cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(context.t('common.confirm'))),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _exportTemplate() async {
    final locs = _selectedLocationIds;
    final type = _type;
    if (locs.isEmpty) {
      setState(() => _status = context.t('wiz.pickAtLeastOneBranch'));
      return;
    }
    if (type == null || type.isEmpty) {
      setState(() => _status = context.t('wiz.pickDeductionType'));
      return;
    }
    if (_scopeCount <= 0) {
      setState(() => _status = context.t('wiz.noEmployeesToExport'));
      return;
    }
    final ok = await _confirm(
      context.t('wiz.exportTemplate'),
      context.t('wiz.exportTemplateQuestion', {'count': _scopeCount, 'branches': _locationIds.length}),
    );
    if (!ok) return;

    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      final result = await api.deductionExportBranchTemplate(
        locationIds: locs,
        deductionType: type,
        dateFrom: _dateFrom.text.trim().isEmpty ? null : _dateFrom.text.trim(),
        dateTo: _dateTo.text.trim().isEmpty ? null : _dateTo.text.trim(),
        jobTitles: _apiJobTitles,
        date: _deductionDate.text.trim(),
      );
      final base64 = result['base64']?.toString() ?? '';
      final filename = result['filename']?.toString() ?? 'deduction.xlsx';
      if (base64.isEmpty) throw Exception(context.t('common.emptyFile'));
      downloadBase64File(
        base64,
        filename,
        result['mimeType']?.toString() ??
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      if (!mounted) return;
      setState(() => _status = context.t('wiz.downloadedWithCount', {'file': filename, 'count': result['count']}));
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importExcel() async {
    final locs = _selectedLocationIds;
    final type = _type;
    final from = _dateFrom.text.trim();
    final to = _dateTo.text.trim();
    if (locs.isEmpty) {
      setState(() => _status = context.t('wiz.pickAtLeastOneBranch'));
      return;
    }
    if (from.isEmpty || to.isEmpty) {
      setState(() => _status = context.t('wiz.periodRequiredImport'));
      return;
    }

    setState(() {
      _busy = true;
      _status = null;
      _importSkipped = [];
    });
    try {
      final base64 = await pickExcelBase64();
      if (base64 == null || base64.isEmpty) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      final preview = await api.deductionPreviewBranchXlsx(
        base64,
        locationIds: locs,
        dateFrom: from,
        dateTo: to,
        deductionType: type,
      );
      final lines = ((preview['lines'] as List?) ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final skipped = ((preview['skipped'] as List?) ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      if (!mounted) return;
      setState(() => _importSkipped = skipped);

      final okLines = lines.where((l) => l['ok'] == true && l['selected'] != false).toList();
      if (okLines.isEmpty) {
        setState(() {
          _busy = false;
          _status = context.t('wiz.noValidRows') +
              (skipped.isNotEmpty
                  ? context.t('wiz.skippedSuffix', {'count': skipped.length})
                  : '');
        });
        return;
      }

      final sum = okLines.fold<double>(
        0,
        (s, l) => s + ((l['amount'] as num?)?.toDouble() ?? 0),
      );
      final confirmed = await _confirm(
        context.t('wiz.confirmImport'),
        context.t('wiz.createDeductions', {
              'count': okLines.length,
              'amount': formatMoney(sum),
            }) +
            (skipped.isNotEmpty
                ? context.t('wiz.skippedRowsSuffix', {'count': skipped.length})
                : ''),
      );
      if (!confirmed) {
        setState(() => _busy = false);
        return;
      }

      final result = await api.deductionConfirmBranchImport(
        lines: [
          for (final l in okLines)
            {
              'employeeId': l['employeeId'],
              'type': l['type'] ?? type,
              'amount': l['amount'],
              'note': l['note'] ?? '',
            },
        ],
        date: _deductionDate.text.trim(),
      );
      if (!mounted) return;
      setState(() => _status = result['message']?.toString() ?? context.t('common.imported'));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _calculateDistribute() async {
    final locs = _selectedLocationIds;
    final type = _type;
    final from = _dateFrom.text.trim();
    final to = _dateTo.text.trim();
    final total = parseMoney(_totalAmount.text) ?? 0;
    if (locs.isEmpty || type == null) {
      setState(() => _status = context.t('wiz.pickBranchesAndType'));
      return;
    }
    if (from.isEmpty || to.isEmpty) {
      setState(() => _status = context.t('wiz.periodRequiredDistribute'));
      return;
    }
    if (total <= 0) {
      setState(() => _status = context.t('wiz.amountAboveZero'));
      return;
    }

    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      final result = await api.deductionDistributePreview(
        locationIds: locs,
        dateFrom: from,
        dateTo: to,
        deductionType: type,
        totalAmount: total,
        date: _deductionDate.text.trim(),
        jobTitles: _apiJobTitles,
      );
      var lines = ((result['lines'] as List?) ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final selectedJobs = {
        for (final t in _selectedJobTitles) t.trim().toLowerCase(),
      }..removeWhere((t) => t.isEmpty);
      if (selectedJobs.isNotEmpty) {
        lines = lines
            .where((l) {
              final jt = (l['jobTitle']?.toString() ?? '').trim().toLowerCase();
              return selectedJobs.contains(jt);
            })
            .toList();
      }
      if (!mounted) return;
      if (lines.isEmpty) {
        setState(() {
          _distributeLines = [];
          _status = selectedJobs.isEmpty
              ? context.t('wiz.noEmployeesInScope')
              : context.t('wiz.noEmployeesForJobTitles');
        });
        return;
      }
      setState(() {
        _distributeLines = lines;
        _status =
            context.t('wiz.previewShare', {'count': lines.length, 'amount': formatMoney(result['perPersonAmount'])});
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _distributeLines = [];
        _status = e.toString();
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeDistributeLine(int index) async {
    if (index < 0 || index >= _distributeLines.length) return;
    final remaining = [..._distributeLines]..removeAt(index);
    final total = parseMoney(_totalAmount.text) ?? 0;
    if (remaining.isEmpty) {
      setState(() => _distributeLines = []);
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await api.deductionDistributeRecalc(
        employeeIds: [
          for (final l in remaining) l['employeeId']?.toString() ?? '',
        ].where((id) => id.isNotEmpty).toList(),
        totalAmount: total,
        note: remaining.first['note']?.toString(),
      );
      final amounts = ((result['lines'] as List?) ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final byId = {
        for (final a in amounts) a['employeeId']?.toString() ?? '': a,
      };
      if (!mounted) return;
      setState(() {
        _distributeLines = [
          for (final l in remaining)
            {
              ...l,
              'amount': byId[l['employeeId']?.toString()]?['amount'] ?? l['amount'],
            },
        ];
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmDistribute() async {
    final locs = _selectedLocationIds;
    final type = _type;
    if (locs.isEmpty || type == null || _distributeLines.isEmpty) return;
    final total = parseMoney(_totalAmount.text) ?? 0;
    final sum = _distributeLines.fold<double>(
      0,
      (s, l) => s + ((l['amount'] as num?)?.toDouble() ?? 0),
    );
    final per = _distributeLines.isEmpty
        ? 0.0
        : sum / _distributeLines.length;
    final ok = await _confirm(
      context.t('wiz.approveDistribution'),
      context.t('wiz.distributionSummary', {
        'count': _distributeLines.length,
        'branches': _locationIds.length,
        'total': formatMoney(total),
        'per': formatMoney(per),
      }),
    );
    if (!ok) return;

    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      final result = await api.deductionDistributeConfirm(
        locationIds: locs,
        dateFrom: _dateFrom.text.trim(),
        dateTo: _dateTo.text.trim(),
        deductionType: type,
        totalAmount: total,
        date: _deductionDate.text.trim(),
        jobTitles: _apiJobTitles,
        lines: [
          for (final l in _distributeLines)
            {
              'employeeId': l['employeeId'],
              'amount': l['amount'],
              'note': l['note'] ?? '',
            },
        ],
      );
      if (!mounted) return;
      setState(() {
        _status = result['message']?.toString() ?? context.t('wiz.distributionApproved');
        _distributeLines = [];
        _totalAmount.clear();
        _parentRefreshPending = true;
      });
      await _refreshScope();
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.t('wiz.title')),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.t('wiz.intro'),
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              InputDecorator(
                decoration: InputDecoration(
                  labelText: context.t('wiz.branches'),
                  border: OutlineInputBorder(),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _locationsSummary,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton(
                      onPressed: _busy ? null : _pickLocations,
                      child: Text(
                        _locationIds.isEmpty
                            ? context.t('wiz.pickBranches')
                            : context.t('wiz.editCount', {'count': _locationIds.length}),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                isExpanded: true,
                value: _type,
                decoration: InputDecoration(labelText: context.t('ded.typeFilter')),
                items: [
                  for (final t in widget.types)
                    DropdownMenuItem(
                      value: t['value']?.toString(),
                      child: Text(t['label']?.toString() ?? '', overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: _busy
                    ? null
                    : (v) => setState(() {
                          _type = v;
                          _distributeLines = [];
                        }),
              ),
              const SizedBox(height: 8),
              InputDecorator(
                decoration: InputDecoration(
                  labelText: context.t('wiz.jobTitlesOptional'),
                  border: OutlineInputBorder(),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _jobTitlesSummary,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton(
                      onPressed: _busy ? null : _pickJobTitles,
                      child: Text(
                        _selectedJobTitles.isEmpty
                            ? context.t('wiz.pickJobTitles')
                            : context.t('wiz.editCount', {'count': _selectedJobTitles.length}),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _periodSelector(),
              const SizedBox(height: 8),
              Text(
                context.t('wiz.scopeCount', {'count': _scopeCount}) +
                    (_locationIds.isNotEmpty
                        ? context.t('wiz.scopeBranches', {'count': _locationIds.length})
                        : '') +
                    (_selectedJobTitles.isNotEmpty
                        ? context.t('wiz.scopeJobTitles', {'count': _selectedJobTitles.length})
                        : ''),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const Divider(height: 28),
              Text(context.t('wiz.step1'), style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _exportTemplate,
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: Text(context.t('wiz.exportExcel')),
                ),
              ),
              const Divider(height: 28),
              Text(context.t('wiz.step2'), style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _importExcel,
                  icon: const Icon(Icons.upload_file_outlined, size: 18),
                  label: Text(context.t('wiz.pickFileAndPreview')),
                ),
              ),
              if (_importSkipped.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  context.t('wiz.skippedPreview', {
                        'count': _importSkipped.length,
                        'reasons': _importSkipped
                            .take(5)
                            .map((s) => s['reason'])
                            .join(' | '),
                      }) +
                      (_importSkipped.length > 5 ? '…' : ''),
                  style: const TextStyle(fontSize: 12, color: AppColors.danger),
                ),
              ],
              const Divider(height: 28),
              Text(context.t('wiz.step3'), style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              TextField(
                controller: _totalAmount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: InputDecoration(labelText: context.t('wiz.totalAmount')),
                onChanged: (_) => setState(() => _distributeLines = []),
                onEditingComplete: () {
                  final parsed = parseMoney(_totalAmount.text);
                  if (parsed != null) {
                    _totalAmount.text = formatMoneyField(parsed);
                  }
                },
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonal(
                    onPressed: _busy ? null : _calculateDistribute,
                    child: Text(context.t('wiz.calculateDistribution')),
                  ),
                  FilledButton(
                    onPressed: _busy || _distributeLines.isEmpty ? null : _confirmDistribute,
                    child: Text(context.t('wiz.approveDistribution')),
                  ),
                ],
              ),
              if (_distributeLines.isNotEmpty) ...[
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _distributeLines.length,
                    itemBuilder: (_, i) {
                      final l = _distributeLines[i];
                      return ListTile(
                        dense: true,
                        title: Text('${l['employeeName']} (${l['employeeCode']})'),
                        subtitle: Text('${l['jobTitle'] ?? ''}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              formatMoney(l['amount']),
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            IconButton(
                              tooltip: context.t('wiz.removeAndRedistribute'),
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: _busy ? null : () => _removeDistributeLine(i),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
              if (_busy) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
              if (_status != null) ...[
                const SizedBox(height: 12),
                Text(_status!, style: const TextStyle(fontSize: 13, height: 1.35)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, _parentRefreshPending),
          child: Text(context.t('common.close')),
        ),
      ],
    );
  }
}
