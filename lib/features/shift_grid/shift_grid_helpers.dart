import 'package:flutter/material.dart';
import '../../l10n/l10n_extension.dart';

import '../../core/utils/shift_calculations.dart';

class WeekGroup {
  const WeekGroup({required this.label, required this.colspan});
  final String label;
  final int colspan;
}

List<WeekGroup> buildWeekGroups(List<Map<String, dynamic>> dates) {
  if (dates.isEmpty) return [];
  final weeks = <WeekGroup>[];
  WeekGroup? current;
  for (final d in dates) {
    final weekday = d['weekday'] as int? ?? 0;
    if (current == null || weekday == 5) {
      current = WeekGroup(
        label: tr('shiftGrid.weekOrdinal', {'n': weeks.length + 1}),
        colspan: 0,
      );
      weeks.add(current);
    }
    current = WeekGroup(label: current.label, colspan: current.colspan + 1);
    weeks[weeks.length - 1] = current;
  }
  for (var i = 0; i < weeks.length; i++) {
    weeks[i] = WeekGroup(
      label: tr('shiftGrid.weekOrdinal', {'n': i + 1}),
      colspan: weeks[i].colspan,
    );
  }
  return weeks;
}

List<MapEntry<String, List<Map<String, dynamic>>>> parseJobGroups(dynamic raw) {
  if (raw is! Map) return [];
  return raw.entries
      .map((e) => MapEntry(e.key.toString(), _employeeList(e.value)))
      .toList();
}

void mergeJobGroups(
  List<MapEntry<String, List<Map<String, dynamic>>>> target,
  dynamic raw,
) {
  final incoming = parseJobGroups(raw);
  for (final entry in incoming) {
    final idx = target.indexWhere((e) => e.key == entry.key);
    if (idx >= 0) {
      target[idx].value.addAll(entry.value);
    } else {
      target.add(MapEntry(entry.key, List<Map<String, dynamic>>.from(entry.value)));
    }
  }
}

List<Map<String, dynamic>> _employeeList(dynamic value) {
  if (value is! List) return [];
  return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
}

List<Map<String, dynamic>> parseDates(dynamic raw) {
  if (raw is! List) return [];
  return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
}

List<Map<String, dynamic>> parseShifts(dynamic raw) {
  if (raw is! List) return [];
  final items = raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  ShiftCalculations.sortShiftsForDisplay(items);
  return items;
}

String stateLabel(String state) {
  switch (state) {
    case 'setup':
      return tr('shiftGrid.state.setup');
    case 'grid':
      return tr('shiftGrid.state.grid');
    case 'confirmed':
      return tr('shiftGrid.state.confirmed');
    default:
      return state;
  }
}

/// Applies a cell/update API response onto the in-memory grid cell map.
void applyShiftGridCellUpdate(
  Map<String, dynamic> cell,
  Map<String, dynamic> response, {
  List<Map<String, dynamic>> shifts = const [],
}) {
  final patch = response['cell'];
  if (patch is Map) {
    cell
      ..clear()
      ..addAll(Map<String, dynamic>.from(patch));
    return;
  }

  final line = response['line'];
  if (line is Map) {
    final m = Map<String, dynamic>.from(line);
    cell['shift_id'] = m['shiftId'] ?? false;
    cell['is_off'] = m['isOff'] == true;
    cell['is_sick'] = m['isSick'] == true;
    cell['is_annual_leave'] = m['isAnnualLeave'] == true;
    cell['is_excluded'] = m['isExcluded'] == true;
    cell['is_bus_delay'] = m['isBusDelay'] == true;
    cell['is_present'] = m['isPresent'] == true;
    cell['is_finished'] = m['isFinished'] == true;
    cell['is_resignation'] = m['isResignation'] == true;
    cell['is_work_absence'] = m['isWorkAbsence'] == true;
    cell['is_work_injury'] = m['isWorkInjury'] == true;
    cell['is_marriage_leave'] = m['isMarriageLeave'] == true;

    final shiftId = cell['shift_id'];
    if (shiftId != null && shiftId != false) {
      final shift = shifts.cast<Map<String, dynamic>?>().firstWhere(
            (s) => s?['id']?.toString() == shiftId.toString(),
            orElse: () => null,
          );
      cell['shift_code'] = shift?['code']?.toString() ?? '';
    } else {
      cell['shift_code'] = '';
    }
  }

  final label = response['display_label']?.toString();
  if (label != null && label.isNotEmpty) {
    cell['display_label'] = label;
  }
}

/// Groups shift grids by their date range (dateFrom → dateTo), newest periods first.
List<MapEntry<String, List<Map<String, dynamic>>>> groupShiftGridsByPeriod(
  List<Map<String, dynamic>> items,
) {
  final buckets = <String, List<Map<String, dynamic>>>{};
  for (final item in items) {
    final from = item['dateFrom']?.toString() ?? '';
    final to = item['dateTo']?.toString() ?? '';
    final key = (from.isEmpty && to.isEmpty) ? tr('shiftGrid.noDate') : '$from → $to';
    buckets.putIfAbsent(key, () => []).add(item);
  }

  final groups = buckets.entries.toList();
  groups.sort((a, b) {
    final aFrom = a.value.first['dateFrom']?.toString() ?? '';
    final bFrom = b.value.first['dateFrom']?.toString() ?? '';
    return bFrom.compareTo(aFrom);
  });

  for (final group in groups) {
    group.value.sort((a, b) {
      final aName = a['deviceName']?.toString() ?? a['name']?.toString() ?? '';
      final bName = b['deviceName']?.toString() ?? b['name']?.toString() ?? '';
      return aName.compareTo(bName);
    });
  }

  return groups;
}

/// Keeps multiple horizontal [ScrollView]s aligned to the same offset.
class HorizontalScrollLinker {
  final List<ScrollController> _controllers = [];
  double _offset = 0;
  bool _syncing = false;

  ScrollController attach() {
    final controller = ScrollController(initialScrollOffset: _offset);
    controller.addListener(() => _onScroll(controller));
    _controllers.add(controller);
    return controller;
  }

  void detach(ScrollController controller) {
    _controllers.remove(controller);
    controller.dispose();
  }

  void _onScroll(ScrollController source) {
    if (_syncing || !source.hasClients) return;
    final offset = source.offset;
    if ((offset - _offset).abs() < 0.5) return;
    _offset = offset;
    _syncing = true;
    for (final controller in _controllers) {
      if (identical(controller, source) || !controller.hasClients) continue;
      if ((controller.offset - offset).abs() > 0.5) {
        controller.jumpTo(offset);
      }
    }
    _syncing = false;
  }

  double get offset => _offset;

  double get maxExtent {
    var max = 0.0;
    for (final controller in _controllers) {
      if (!controller.hasClients) continue;
      final extent = controller.position.maxScrollExtent;
      if (extent > max) max = extent;
    }
    return max;
  }

  void scrollBy(double delta) {
    jumpTo(_offset + delta);
  }

  void jumpTo(double offset) {
    final max = maxExtent;
    final clamped = offset.clamp(0.0, max);
    if ((clamped - _offset).abs() < 0.5 && max > 0) return;
    _offset = clamped;
    _syncing = true;
    for (final controller in _controllers) {
      if (!controller.hasClients) continue;
      final localMax = controller.position.maxScrollExtent;
      final target = clamped.clamp(0.0, localMax);
      if ((controller.offset - target).abs() > 0.5) {
        controller.jumpTo(target);
      }
    }
    _syncing = false;
  }

  void dispose() {
    for (final controller in List<ScrollController>.from(_controllers)) {
      detach(controller);
    }
  }
}

class SyncHorizontalScrollView extends StatefulWidget {
  const SyncHorizontalScrollView({
    super.key,
    required this.linker,
    required this.width,
    required this.child,
  });

  final HorizontalScrollLinker linker;
  final double width;
  final Widget child;

  @override
  State<SyncHorizontalScrollView> createState() => _SyncHorizontalScrollViewState();
}

class _SyncHorizontalScrollViewState extends State<SyncHorizontalScrollView> {
  late final ScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.linker.attach();
  }

  @override
  void dispose() {
    widget.linker.detach(_controller);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      controller: _controller,
      child: SizedBox(
        width: widget.width,
        child: widget.child,
      ),
    );
  }
}
