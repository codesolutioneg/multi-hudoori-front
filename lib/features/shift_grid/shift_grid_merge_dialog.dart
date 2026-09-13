import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../core/di/injection.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme_v2.dart';
import '../../core/utils/payroll_month.dart';
import '../../core/widgets/sellix_card.dart';
import '../../l10n/l10n_extension.dart';

/// Merges weekly grids into one monthly grid, or appends a later week into an
/// existing monthly merge.
class ShiftGridMergeDialog extends StatefulWidget {
  const ShiftGridMergeDialog({super.key});

  @override
  State<ShiftGridMergeDialog> createState() => _ShiftGridMergeDialogState();
}

class _LocationGroup {
  _LocationGroup({
    required this.locationId,
    required this.locationName,
    required this.grids,
  });

  final String locationId;
  final String locationName;
  final List<Map<String, dynamic>> grids;
}

class _ShiftGridMergeDialogState extends State<ShiftGridMergeDialog> {
  List<Map<String, dynamic>> _consumed = [];
  List<Map<String, dynamic>> _targets = [];
  List<Map<String, dynamic>> _movers = [];
  List<_LocationGroup> _locationGroups = [];
  final Map<String, String> _gridLocationById = {};
  final Set<String> _selected = {};
  final Set<String> _expandedLocations = {};
  bool _moversExpanded = false;

  /// null / '' = create a new monthly merge; otherwise append into that grid.
  String? _targetGridId;
  Map<String, dynamic>? _preview;
  String _conflictStrategy = 'latest_grid';
  bool _clampToPeriod = true;
  final _nameCtrl = TextEditingController();

  String _periodFrom = '';
  String _periodTo = '';
  /// Date inside the selected payroll month; null = today (current period).
  String? _reference;
  int _monthStartDay = 26;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  bool get _appendMode => (_targetGridId ?? '').isNotEmpty;

  String? get _activeLocationId {
    if (_selected.isEmpty) return null;
    for (final id in _selected) {
      final loc = _gridLocationById[id];
      if (loc != null && loc.isNotEmpty) return loc;
    }
    return null;
  }

  bool get _canMerge {
    if (_busy) return false;
    if (_appendMode) return _selected.isNotEmpty;
    return _selected.length >= 2;
  }

  List<Map<String, dynamic>> get _visibleMovers {
    final loc = _appendMode
        ? _targetLocationId
        : _activeLocationId;
    if (loc == null || loc.isEmpty) return _movers;
    return _movers
        .where((m) => m['homeLocationId']?.toString() == loc)
        .toList();
  }

  String? get _targetLocationId {
    if (!_appendMode) return null;
    for (final t in _targets) {
      if (t['id']?.toString() == _targetGridId) {
        return t['locationId']?.toString();
      }
    }
    return null;
  }

  List<_LocationGroup> get _visibleLocationGroups {
    final targetLoc = _targetLocationId;
    if (targetLoc == null || targetLoc.isEmpty) return _locationGroups;
    return _locationGroups
        .where((g) => g.locationId == targetLoc)
        .toList();
  }

  List<Map<String, dynamic>> _consumedForLocation(String locationId) {
    return _consumed
        .where((g) => (g['locationId']?.toString() ?? '') == locationId)
        .toList();
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
    for (var i = 0; i < 8; i++) {
      final r = payrollMonthRange(ref, _monthStartDay);
      out.add((from: formatIsoDate(r.dateFrom), to: formatIsoDate(r.dateTo)));
      ref = r.dateFrom.subtract(const Duration(days: 1));
    }
    if (_periodFrom.isNotEmpty && !out.any((p) => p.from == _periodFrom)) {
      out.insert(0, (from: _periodFrom, to: _periodTo));
    }
    return out;
  }

  void _selectPeriod(String periodFrom) {
    if (periodFrom == _periodFrom || _busy) return;
    _loadCandidates(reference: periodFrom);
  }

  void _shiftPeriod(int direction) {
    if (_busy) return;
    final from = parseIsoDate(_periodFrom);
    final to = parseIsoDate(_periodTo);
    if (from == null || to == null) return;
    if (direction > 0 && _atCurrentPeriod) return;
    final ref = direction < 0
        ? from.subtract(const Duration(days: 1))
        : to.add(const Duration(days: 1));
    _loadCandidates(reference: formatIsoDate(ref));
  }

  @override
  void initState() {
    super.initState();
    _loadCandidates();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _rebuildIndex() {
    _gridLocationById.clear();
    for (final group in _locationGroups) {
      for (final grid in group.grids) {
        _gridLocationById[grid['id'].toString()] = group.locationId;
      }
    }
  }

  List<_LocationGroup> _parseLocationGroups(Map<String, dynamic> data) {
    final rawGroups = (data['locationGroups'] as List?) ?? [];
    if (rawGroups.isNotEmpty) {
      return rawGroups.map((g) {
        final map = Map<String, dynamic>.from(g as Map);
        return _LocationGroup(
          locationId: map['locationId']?.toString() ?? '',
          locationName: map['locationName']?.toString() ?? context.t('shiftGrid.unknownBranch'),
          grids: ((map['grids'] as List?) ?? [])
              .cast<Map<String, dynamic>>(),
        );
      }).toList();
    }
    final grids =
        ((data['grids'] as List?) ?? []).cast<Map<String, dynamic>>();
    final byId = <String, _LocationGroup>{};
    for (final grid in grids) {
      final locId = grid['locationId']?.toString() ?? '';
      final locName = grid['locationName']?.toString() ?? context.t('shiftGrid.unknownBranch');
      final bucket = byId.putIfAbsent(
        locId,
        () => _LocationGroup(
          locationId: locId,
          locationName: locName,
          grids: [],
        ),
      );
      bucket.grids.add(grid);
    }
    final groups = byId.values.toList()
      ..sort((a, b) => a.locationName.compareTo(b.locationName));
    return groups;
  }

  Future<void> _loadCandidates({String? reference}) async {
    if (reference != null) _reference = reference;
    setState(() {
      _loading = true;
      _error = null;
      _preview = null;
    });
    try {
      final data = await api.shiftGridMergeCandidates(reference: _reference);
      if (!mounted) return;
      final targets =
          ((data['targets'] as List?) ?? []).cast<Map<String, dynamic>>();
      setState(() {
        _locationGroups = _parseLocationGroups(data);
        _rebuildIndex();
        _consumed =
            ((data['consumed'] as List?) ?? []).cast<Map<String, dynamic>>();
        _targets = targets;
        _movers =
            ((data['movers'] as List?) ?? []).cast<Map<String, dynamic>>();
        _periodFrom = data['dateFrom']?.toString() ?? '';
        _periodTo = data['dateTo']?.toString() ?? '';
        final startDay = (data['monthStartDay'] as num?)?.toInt();
        if (startDay != null && startDay >= 1 && startDay <= 31) {
          _monthStartDay = startDay;
        }
        if (_periodFrom.isNotEmpty) _reference = _periodFrom;
        _targetGridId = null;
        _selected.clear();
        _expandedLocations
          ..clear()
          ..addAll(_locationGroups.map((g) => g.locationId));
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _onTargetChanged(String? value) {
    setState(() {
      _targetGridId = value;
      if (_appendMode) {
        final loc = _targetLocationId;
        _selected.removeWhere(
          (id) => _gridLocationById[id] != loc,
        );
        if (loc != null && loc.isNotEmpty) {
          _expandedLocations.add(loc);
        }
      }
    });
    if (_canMerge) {
      _loadPreview();
    } else {
      setState(() => _preview = null);
    }
  }

  void _toggleWeek(String id, String locationId, bool? checked) {
    setState(() {
      if (checked == true) {
        if (_activeLocationId != null && _activeLocationId != locationId) {
          _selected.removeWhere(
            (sid) => _gridLocationById[sid] != locationId,
          );
        }
        _selected.add(id);
      } else {
        _selected.remove(id);
      }
    });
    if (_canMerge) {
      _loadPreview();
    } else {
      setState(() => _preview = null);
    }
  }

  void _selectAllInLocation(_LocationGroup group, {required bool select}) {
    setState(() {
      if (select) {
        _selected.removeWhere(
          (sid) => _gridLocationById[sid] != group.locationId,
        );
        _selected.addAll(group.grids.map((g) => g['id'].toString()));
      } else {
        _selected.removeWhere(
          (sid) => _gridLocationById[sid] == group.locationId,
        );
      }
    });
    if (_canMerge) {
      _loadPreview();
    } else {
      setState(() => _preview = null);
    }
  }

  Future<void> _loadPreview() async {
    if (_appendMode) {
      if (_selected.isEmpty) {
        setState(() => _preview = null);
        return;
      }
    } else if (_selected.length < 2) {
      setState(() => _preview = null);
      return;
    }
    setState(() => _busy = true);
    try {
      final data = await api.shiftGridMergePreview(
        _selected.toList(),
        targetGridId: _appendMode ? _targetGridId : null,
        periodFrom: _clampToPeriod ? _periodFrom : null,
        periodTo: _clampToPeriod ? _periodTo : null,
      );
      if (!mounted) return;
      setState(() {
        _preview = data;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _preview = null;
        _error = e.toString();
      });
    }
  }

  Future<void> _merge() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = await api.shiftGridMerge(
        _selected.toList(),
        targetGridId: _appendMode ? _targetGridId : null,
        name: _appendMode || _nameCtrl.text.trim().isEmpty
            ? null
            : _nameCtrl.text.trim(),
        conflictStrategy: _conflictStrategy,
        periodFrom: _clampToPeriod ? _periodFrom : null,
        periodTo: _clampToPeriod ? _periodTo : null,
      );
      if (!mounted) return;
      Navigator.of(context).pop(data);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
  }

  String _rangeLabel(Map<String, dynamic> grid) {
    final from = DateTime.tryParse('${grid['dateFrom']}');
    final to = DateTime.tryParse('${grid['dateTo']}');
    final span =
        (from != null && to != null) ? to.difference(from).inDays + 1 : null;
    final range = '${grid['dateFrom']} → ${grid['dateTo']}';
    return span != null
        ? '$range  ·  ${context.t('grid.mergeSpanDays', {'days': '$span'})}'
        : range;
  }

  Widget _previewSummary() {
    final preview = _preview;
    if (preview == null) return const SizedBox.shrink();
    final missing = ((preview['missingDates'] as List?) ?? []).length;
    final overlaps = (preview['overlappingDayCount'] as num?)?.toInt() ?? 0;
    final crossMode = preview['crossLocationMode']?.toString() ?? '';
    final crossLines = (preview['crossLocationLineCount'] as num?)?.toInt() ?? 0;
    final crossEmps = (preview['crossLocationEmployeeCount'] as num?)?.toInt() ?? 0;
    final excluded = (preview['excludedEmployeeCount'] as num?)?.toInt() ?? 0;
    final mFrom = DateTime.tryParse(preview['dateFrom']?.toString() ?? '');
    final mTo = DateTime.tryParse(preview['dateTo']?.toString() ?? '');
    final mSpan = (mFrom != null && mTo != null)
        ? mTo.difference(mFrom).inDays + 1
        : null;
    final branchName = _appendMode
        ? (_targets
                .where((t) => t['id']?.toString() == _targetGridId)
                .map((t) => t['locationName']?.toString() ?? '')
                .cast<String>()
                .where((n) => n.isNotEmpty)
                .isNotEmpty
            ? _targets
                .firstWhere((t) => t['id']?.toString() == _targetGridId)['locationName']
                ?.toString()
            : null)
        : (_locationGroups
                .where((g) => g.locationId == _activeLocationId)
                .map((g) => g.locationName)
                .isNotEmpty
            ? _locationGroups
                .firstWhere((g) => g.locationId == _activeLocationId)
                .locationName
            : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if ((branchName ?? '').isNotEmpty)
          Text(
            context.t('shiftGrid.branchLabel', {'branch': branchName}),
            style: AppThemeV2.caption.copyWith(fontWeight: FontWeight.w600),
          ),
        Text(
          context.t('grid.mergePeriod', {
                'from': preview['dateFrom']?.toString() ?? '',
                'to': preview['dateTo']?.toString() ?? '',
              }) +
              (mSpan != null
                  ? '  ·  ${context.t('grid.mergeSpanDays', {'days': '$mSpan'})}'
                  : ''),
          style: AppThemeV2.caption,
        ),
        Text(
          context.t('grid.mergeTotals', {
            'employees': '${preview['employeeCount'] ?? 0}',
            'days': '${preview['lineCount'] ?? 0}',
          }),
          style: AppThemeV2.caption,
        ),
        if (crossMode == 'last_week')
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              [
                context.t('shiftGrid.optionA'),
                if (crossLines > 0)
                  context.t('shiftGrid.crossDays', {'count': crossLines}),
                if (crossEmps > 0)
                  context.t('shiftGrid.crossEmployees', {'count': crossEmps}),
                if (excluded > 0)
                  context.t('shiftGrid.excludedCount', {'count': excluded}),
              ].join(' · '),
              style: AppThemeV2.caption.copyWith(color: AppColors.primary),
            ),
          ),
        if (overlaps > 0)
          _warning(
            context.t('grid.mergeOverlaps', {'count': '$overlaps'}),
            AppColors.warning,
          ),
        if (missing > 0)
          _warning(
            context.t('grid.mergeMissingDays', {'count': '$missing'}),
            AppColors.warning,
          ),
        if (((preview['outOfPeriodLineCount'] as num?)?.toInt() ?? 0) > 0)
          _warning(
            context.t('grid.mergeOutOfPeriod', {
              'count': '${preview['outOfPeriodLineCount']}',
            }),
            AppColors.textSecondary,
          ),
      ],
    );
  }

  Widget _warning(String message, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(message, style: TextStyle(fontSize: 12, color: color)),
          ),
        ],
      ),
    );
  }

  Widget _branchHintBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppThemeV2.primarySoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppThemeV2.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: AppThemeV2.primary),
          const Gap(8),
          Expanded(
            child: Text(
              _appendMode
                  ? context.t('shiftGrid.mergeAddWeeks')
                  : context.t('shiftGrid.mergeHint'),
              style: AppThemeV2.caption,
            ),
          ),
        ],
      ),
    );
  }

  Widget _moversSection() {
    final visible = _visibleMovers;
    if (visible.isEmpty) return const SizedBox.shrink();
    return SellixCard(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        initiallyExpanded: _moversExpanded,
        onExpansionChanged: (v) => setState(() => _moversExpanded = v),
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        leading: const Icon(Icons.swap_horiz, size: 20, color: AppThemeV2.primary),
        title: Text(
          context.t('shiftGrid.moveWithinMonth', {'count': visible.length}),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          context.t('shiftGrid.mainBranchRule'),
          style: AppThemeV2.caption,
        ),
        children: visible
            .map(
              (m) => ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(
                  '${m['employeeName'] ?? ''} (${m['employeeCode'] ?? ''})',
                  style: const TextStyle(fontSize: 13),
                ),
                subtitle: Text(
                  '→ ${m['homeLocationName'] ?? ''}',
                  style: AppThemeV2.caption,
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _locationSection(_LocationGroup group) {
    final expanded = _expandedLocations.contains(group.locationId);
    final selectedInGroup = group.grids
        .where((g) => _selected.contains(g['id'].toString()))
        .length;
    final consumed = _consumedForLocation(group.locationId);
    final isActive =
        _activeLocationId == null || _activeLocationId == group.locationId;
    final dimmed = !isActive && _activeLocationId != null;

    return Opacity(
      opacity: dimmed ? 0.45 : 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setState(() {
                  if (expanded) {
                    _expandedLocations.remove(group.locationId);
                  } else {
                    _expandedLocations.add(group.locationId);
                  }
                });
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: selectedInGroup > 0
                      ? AppThemeV2.primarySoft
                      : AppThemeV2.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selectedInGroup > 0
                        ? AppThemeV2.primary.withValues(alpha: 0.25)
                        : AppThemeV2.border,
                  ),
                ),
                child: Row(
                  children: [
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(
                        Icons.expand_more_rounded,
                        size: 22,
                        color: AppThemeV2.primary,
                      ),
                    ),
                    const Gap(6),
                    const Icon(
                      Icons.storefront_outlined,
                      size: 18,
                      color: AppThemeV2.primary,
                    ),
                    const Gap(8),
                    Expanded(
                      child: Text(
                        group.locationName,
                        style: AppThemeV2.body.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (!dimmed) ...[
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => _selectAllInLocation(group, select: true),
                        child: Text(context.t('common.selectAll')),
                      ),
                      if (selectedInGroup > 0)
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () =>
                                  _selectAllInLocation(group, select: false),
                          child: Text(context.t('grid.clearSelection')),
                        ),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppThemeV2.border),
                      ),
                      child: Text(
                        selectedInGroup > 0
                            ? context.t('shiftGrid.weeksCountSelected', {'count': group.grids.length, 'selected': selectedInGroup})
                            : context.t('shiftGrid.weeksCount', {'count': group.grids.length}),
                        style: AppThemeV2.caption.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (expanded) ...[
            const Gap(6),
            SellixCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < group.grids.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        color: AppThemeV2.border.withValues(alpha: 0.6),
                      ),
                    CheckboxListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(group.grids[i]['name']?.toString() ?? ''),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _rangeLabel(group.grids[i]),
                            style: AppThemeV2.caption,
                          ),
                          Text(
                            context.t('grid.mergeDayCount', {
                              'count': '${group.grids[i]['lineCount'] ?? 0}',
                            }),
                            style: AppThemeV2.caption,
                          ),
                        ],
                      ),
                      value: _selected.contains(
                        group.grids[i]['id'].toString(),
                      ),
                      onChanged: _busy || dimmed
                          ? null
                          : (checked) => _toggleWeek(
                                group.grids[i]['id'].toString(),
                                group.locationId,
                                checked,
                              ),
                    ),
                  ],
                  if (consumed.isNotEmpty) ...[
                    Divider(
                      height: 1,
                      color: AppThemeV2.border.withValues(alpha: 0.6),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.t('grid.mergeConsumedWeeks'),
                            style: AppThemeV2.caption.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Gap(4),
                          ...consumed.map(
                            (grid) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.check_circle_outline,
                                    size: 16,
                                    color: AppColors.success,
                                  ),
                                  const Gap(6),
                                  Expanded(
                                    child: Text(
                                      '${grid['name']} — ${context.t('grid.mergeAlreadyIn', {
                                            'name': '${grid['mergedIntoName'] ?? ''}',
                                          })}',
                                      style: AppThemeV2.caption,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const Gap(10),
        ],
      ),
    );
  }

  Widget _targetsSection() {
    if (_targets.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String?>(
          value: _targetGridId,
          decoration: InputDecoration(
            labelText: context.t('grid.mergeTarget'),
            helperText: context.t('shiftGrid.mergedOnlyHint'),
          ),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text(context.t('grid.mergeTargetNew')),
            ),
            ..._targets.map(
              (t) => DropdownMenuItem<String?>(
                value: t['id']?.toString(),
                child: Text(
                  '${t['locationName'] ?? t['name']} — ${t['name']} (${t['dateFrom']} → ${t['dateTo']})',
                ),
              ),
            ),
          ],
          onChanged: _busy ? null : _onTargetChanged,
        ),
        Text(
          context.t('grid.mergeTargetHint'),
          style: AppThemeV2.caption,
        ),
        const Gap(12),
      ],
    );
  }

  Widget _periodSelector() {
    final choices = _periodChoices;
    final value = choices.any((p) => p.from == _periodFrom)
        ? _periodFrom
        : (choices.isNotEmpty ? choices.first.from : null);
    final currentFrom = formatIsoDate(
      payrollMonthRange(_todayUtc(), _monthStartDay).dateFrom,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.t('grid.mergeSelectPeriod'),
          style: AppThemeV2.caption.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            IconButton(
              tooltip: context.t('grid.mergePrevPeriod'),
              onPressed: _busy || _loading || _periodFrom.isEmpty
                  ? null
                  : () => _shiftPeriod(-1),
              icon: const Icon(Icons.arrow_back),
            ),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: value,
                isExpanded: true,
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                ),
                items: [
                  for (final p in choices)
                    DropdownMenuItem(
                      value: p.from,
                      child: Text(
                        p.from == currentFrom
                            ? '${p.from} → ${p.to} (${context.t('grid.mergeCurrentPeriod')})'
                            : '${p.from} → ${p.to}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: _busy || _loading
                    ? null
                    : (v) {
                        if (v != null) _selectPeriod(v);
                      },
              ),
            ),
            IconButton(
              tooltip: context.t('grid.mergeNextPeriod'),
              onPressed: _busy ||
                      _loading ||
                      _periodFrom.isEmpty ||
                      _atCurrentPeriod
                  ? null
                  : () => _shiftPeriod(1),
              icon: const Icon(Icons.arrow_forward),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final firstLoad = _loading && _periodFrom.isEmpty;
    return AlertDialog(
      title: Text(context.t('grid.mergeTitle')),
      content: SizedBox(
        width: 560,
        child: firstLoad
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _periodSelector(),
                    const Gap(10),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else ...[
                    _branchHintBanner(),
                    const Gap(12),
                    _targetsSection(),
                    if (_visibleMovers.isNotEmpty) ...[
                      _moversSection(),
                      const Gap(8),
                    ],
                    if (_visibleLocationGroups.isEmpty &&
                        _consumed.isEmpty)
                      Text(context.t('grid.mergeNoCandidates'))
                    else ...[
                      Text(
                        context.t('grid.mergeAvailableWeeks'),
                        style: AppThemeV2.caption.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Gap(8),
                      ..._visibleLocationGroups.map(_locationSection),
                    ],
                    const Divider(height: 24),
                    if (!_appendMode)
                      TextField(
                        controller: _nameCtrl,
                        decoration: InputDecoration(
                          labelText: context.t('grid.mergeName'),
                          hintText: context.t('grid.mergeNameHint'),
                        ),
                      ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(context.t('grid.mergeClampToPeriod')),
                      subtitle: Text(
                        context.t('grid.mergeClampToPeriodHint'),
                        style: AppThemeV2.caption,
                      ),
                      value: _clampToPeriod,
                      onChanged: _busy || _periodFrom.isEmpty
                          ? null
                          : (checked) {
                              setState(() => _clampToPeriod = checked ?? true);
                              _loadPreview();
                            },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _conflictStrategy,
                      decoration: InputDecoration(
                        labelText: context.t('grid.mergeConflict'),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'latest_grid',
                          child: Text(context.t('grid.mergeConflictLatest')),
                        ),
                        DropdownMenuItem(
                          value: 'earliest_grid',
                          child: Text(context.t('grid.mergeConflictEarliest')),
                        ),
                        DropdownMenuItem(
                          value: 'fail',
                          child: Text(context.t('grid.mergeConflictFail')),
                        ),
                      ],
                      onChanged: _busy
                          ? null
                          : (v) {
                              if (v != null) {
                                setState(() => _conflictStrategy = v);
                              }
                            },
                    ),
                    const SizedBox(height: 12),
                    if (_busy)
                      const LinearProgressIndicator(minHeight: 2),
                    _previewSummary(),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: AppColors.danger,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(context.t('common.cancel')),
        ),
        FilledButton(
          onPressed: _canMerge ? _merge : null,
          child: Text(
            _appendMode
                ? context.t('grid.mergeAppendConfirm')
                : context.t('grid.mergeConfirm'),
          ),
        ),
      ],
    );
  }
}
