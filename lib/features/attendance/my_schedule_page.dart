import 'package:flutter/material.dart';

import '../../core/di/injection.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme_v2.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/sellix_card.dart';
import '../../l10n/l10n_extension.dart';

/// The employee's own weekly schedule, plus their department's week when HR
/// allows it. This is the sheet staff previously only saw on paper.
class MySchedulePage extends StatefulWidget {
  const MySchedulePage({super.key});

  @override
  State<MySchedulePage> createState() => _MySchedulePageState();
}

class _MySchedulePageState extends State<MySchedulePage> {
  /// Weeks away from the current one: negative is past, positive is future.
  int _weekOffset = 0;
  Map<String, dynamic> _data = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // The first load lets the server pick the week so the configured start day
      // decides it; navigation then shifts by whole weeks from what came back.
      Map<String, dynamic> data;
      if (_weekOffset == 0) {
        data = await api.mySchedule();
      } else {
        final base = await api.mySchedule();
        final from = DateTime.parse('${base['dateFrom']}T00:00:00Z')
            .add(Duration(days: 7 * _weekOffset));
        data = await api.mySchedule(
          dateFrom: _iso(from),
          dateTo: _iso(from.add(const Duration(days: 6))),
        );
      }
      if (!mounted) return;
      setState(() {
        _data = data;
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

  List<Map<String, dynamic>> get _days =>
      ((_data['days'] as List?) ?? []).cast<Map<String, dynamic>>();

  List<Map<String, dynamic>> get _team =>
      ((_data['team'] as List?) ?? []).cast<Map<String, dynamic>>();

  String _weekdayName(int weekday) => context.t('settings.weekday.$weekday');

  Color _dayColor(Map<String, dynamic> day) {
    if (day['isSick'] == true) return AppColors.danger;
    if (day['isLeave'] == true) return AppColors.info;
    if (day['isOff'] == true) return AppColors.textSecondary;
    if ((day['shiftId'] ?? '') == '' && (day['label'] ?? '') == '') {
      return AppColors.textSecondary;
    }
    return AppColors.success;
  }

  String _dayText(Map<String, dynamic> day) {
    final label = day['label']?.toString() ?? '';
    if (label.isNotEmpty) return label;
    return context.t('schedule.noShift');
  }

  /// Shows the hours only when a real shift is scheduled.
  String _dayTime(Map<String, dynamic> day) {
    final start = day['startTime']?.toString() ?? '';
    final end = day['endTime']?.toString() ?? '';
    if (start.isEmpty || end.isEmpty) return '';
    return '$start → $end';
  }

  Widget _myWeek() {
    return SellixCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final day in _days) ...[
            ListTile(
              dense: true,
              leading: SizedBox(
                width: 64,
                child: Text(
                  _weekdayName((day['weekday'] as num?)?.toInt() ?? 0),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
              title: Text(
                _dayText(day),
                style: TextStyle(color: _dayColor(day), fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                [
                  day['date']?.toString() ?? '',
                  if (_dayTime(day).isNotEmpty) _dayTime(day),
                  // Flagged so nobody mistakes a projection for a posted roster.
                  if (day['fromPattern'] == true) context.t('schedule.fromPattern'),
                ].join('  •  '),
                style: AppThemeV2.caption,
              ),
            ),
            if (day != _days.last) const Divider(height: 1),
          ],
        ],
      ),
    );
  }

  Widget _teamSection(Map<String, dynamic> section) {
    final members = ((section['members'] as List?) ?? []).cast<Map<String, dynamic>>();
    return SellixCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            section['department']?.toString() ?? '',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 18,
              columns: [
                DataColumn(label: Text(context.t('reports.column.name'))),
                for (final day in _days)
                  DataColumn(
                    label: Text(
                      _weekdayName((day['weekday'] as num?)?.toInt() ?? 0),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],
              rows: [
                for (final member in members)
                  DataRow(
                    color: member['isSelf'] == true
                        ? WidgetStatePropertyAll(AppColors.success.withValues(alpha: 0.07))
                        : null,
                    cells: [
                      DataCell(
                        Text(
                          member['name']?.toString() ?? '',
                          style: TextStyle(
                            fontWeight: member['isSelf'] == true
                                ? FontWeight.w700
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      for (final day
                          in ((member['days'] as List?) ?? []).cast<Map<String, dynamic>>())
                        DataCell(
                          Text(
                            day['label']?.toString().isNotEmpty == true
                                ? day['label'].toString()
                                : '—',
                            style: TextStyle(fontSize: 12, color: _dayColor(day)),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final from = _data['dateFrom']?.toString() ?? '';
    final to = _data['dateTo']?.toString() ?? '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: context.t('schedule.title'),
            subtitle: from.isEmpty ? null : '$from → $to',
            icon: Icons.calendar_month_outlined,
            actions: [
              IconButton(
                tooltip: context.t('schedule.previousWeek'),
                onPressed: _loading
                    ? null
                    : () {
                        setState(() => _weekOffset--);
                        _load();
                      },
                icon: const Icon(Icons.chevron_right),
              ),
              if (_weekOffset != 0)
                TextButton(
                  onPressed: _loading
                      ? null
                      : () {
                          setState(() => _weekOffset = 0);
                          _load();
                        },
                  child: Text(context.t('schedule.thisWeek')),
                ),
              IconButton(
                tooltip: context.t('schedule.nextWeek'),
                onPressed: _loading
                    ? null
                    : () {
                        setState(() => _weekOffset++);
                        _load();
                      },
                icon: const Icon(Icons.chevron_left),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
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
    if (_data['employeeId'] == null) {
      return SellixCard(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_off_outlined, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text(context.t('schedule.noProfile'), textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return ListView(
      children: [
        _myWeek(),
        if (_team.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(context.t('schedule.teamTitle'), style: AppThemeV2.caption),
          const SizedBox(height: 8),
          for (final section in _team) ...[
            _teamSection(section),
            const SizedBox(height: 12),
          ],
        ],
      ],
    );
  }
}
