import 'package:flutter/material.dart';

import '../../core/di/injection.dart';
import '../../core/platform/mobile_platform.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme_v2.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/sellix_card.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_extension.dart';
import '../mobile/mobile_ui.dart';

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

  void _shiftWeek(int delta) {
    setState(() => _weekOffset = delta == 0 ? 0 : _weekOffset + delta);
    _load();
  }

  // ---------------------------------------------------------------- mobile

  ({Color color, IconData icon, String status}) _mobileState(Map<String, dynamic> day) {
    if (day['isSick'] == true) {
      return (color: MobileTone.danger, icon: Icons.local_hospital_rounded, status: context.t('m.schedSick'));
    }
    if (day['isLeave'] == true) {
      return (color: MobileTone.info, icon: Icons.beach_access_rounded, status: context.t('m.leave'));
    }
    if (day['isOff'] == true) {
      return (color: MobileTone.violet, icon: Icons.weekend_rounded, status: context.t('m.schedOff'));
    }
    if ((day['shiftId'] ?? '') == '' && (day['label'] ?? '') == '') {
      return (color: MobileUi.muted, icon: Icons.event_busy_rounded, status: context.t('schedule.noShift'));
    }
    return (color: MobileUi.primary, icon: Icons.work_history_rounded, status: '');
  }

  DateTime? _clock(dynamic raw) {
    final parts = (raw?.toString() ?? '').split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return DateTime(2000, 1, 1, h, m);
  }

  String _rangeLabel(AppLocalizations l10n) {
    final from = DateTime.tryParse(_data['dateFrom']?.toString() ?? '');
    final to = DateTime.tryParse(_data['dateTo']?.toString() ?? '');
    if (from == null || to == null) return context.t('schedule.title');
    if (from.month == to.month) {
      return '${from.day} – ${to.day} ${monthShort(l10n, to)} ${to.year}';
    }
    return '${from.day} ${monthShort(l10n, from)} – ${to.day} ${monthShort(l10n, to)}';
  }

  Widget _buildMobile() {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: context.t('schedule.title'),
            icon: Icons.calendar_month_outlined,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 110),
                children: [
                  _mobileWeekCard(l10n),
                  const SizedBox(height: 14),
                  ..._mobileBody(l10n),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobileWeekCard(AppLocalizations l10n) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final days = _days;
    var work = 0, off = 0, leave = 0;
    for (final d in days) {
      if (d['isSick'] == true || d['isLeave'] == true) {
        leave++;
      } else if (d['isOff'] == true) {
        off++;
      } else if ((d['shiftId'] ?? '') != '' || (d['label'] ?? '') != '') {
        work++;
      }
    }

    Widget navButton(IconData icon, String tooltip, VoidCallback onTap) => Tooltip(
          message: tooltip,
          child: Material(
            color: Colors.white.withValues(alpha: 0.16),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _loading ? null : onTap,
              child: SizedBox(
                width: 40,
                height: 40,
                child: Icon(icon, color: Colors.white, size: 24),
              ),
            ),
          ),
        );

    Widget stat(String value, String label, IconData icon) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 15, color: Colors.white70),
                    const SizedBox(width: 5),
                    Text(value, style: MobileUi.text(18, weight: FontWeight.w800, color: Colors.white, height: 1.1)),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MobileUi.text(11.5, weight: FontWeight.w600, color: Colors.white70),
                ),
              ],
            ),
          ),
        );

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        gradient: MobileUi.primaryGradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: MobileUi.primary.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              navButton(
                rtl ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
                context.t('schedule.previousWeek'),
                () => _shiftWeek(-1),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      _rangeLabel(l10n),
                      textAlign: TextAlign.center,
                      style: MobileUi.text(17, weight: FontWeight.w800, color: Colors.white, height: 1.3),
                    ),
                    const SizedBox(height: 4),
                    if (_weekOffset == 0)
                      Text(
                        context.t('schedule.thisWeek'),
                        style: MobileUi.text(12, weight: FontWeight.w600, color: Colors.white70),
                      )
                    else
                      InkWell(
                        onTap: _loading ? null : () => _shiftWeek(0),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.today_rounded, size: 13, color: MobileUi.primary),
                              const SizedBox(width: 4),
                              Text(
                                context.t('schedule.thisWeek'),
                                style: MobileUi.text(11.5, weight: FontWeight.w700, color: MobileUi.primary),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              navButton(
                rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                context.t('schedule.nextWeek'),
                () => _shiftWeek(1),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              stat('$work', context.t('m.schedWork'), Icons.work_history_rounded),
              const SizedBox(width: 8),
              stat('$off', context.t('m.schedOff'), Icons.weekend_rounded),
              const SizedBox(width: 8),
              stat('$leave', context.t('m.leave'), Icons.beach_access_rounded),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _mobileBody(AppLocalizations l10n) {
    if (_loading) {
      return const [
        Padding(
          padding: EdgeInsets.only(top: 48),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2.6)),
        ),
      ];
    }
    if (_error != null) {
      return [
        MobileEmptyState(
          message: _error!,
          icon: Icons.cloud_off_rounded,
          action: FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(context.t('common.retry')),
          ),
        ),
      ];
    }
    if (_data['employeeId'] == null) {
      return [
        MobileEmptyState(
          message: context.t('schedule.noProfile'),
          icon: Icons.person_off_outlined,
        ),
      ];
    }
    final today = isoDate(DateTime.now());
    return [
      for (final day in _days) ...[
        _mobileDay(l10n, day, day['date']?.toString() == today),
        const SizedBox(height: 10),
      ],
      if (_team.isNotEmpty) ...[
        const SizedBox(height: 10),
        Row(
          children: [
            const MobileIconBadge(icon: Icons.groups_rounded, size: 32),
            const SizedBox(width: 10),
            Text(context.t('schedule.teamTitle'), style: MobileUi.sectionTitle),
          ],
        ),
        const SizedBox(height: 10),
        for (final section in _team) ...[
          _mobileTeam(l10n, section),
          const SizedBox(height: 12),
        ],
      ],
    ];
  }

  Widget _mobileDay(AppLocalizations l10n, Map<String, dynamic> day, bool isToday) {
    final state = _mobileState(day);
    final date = DateTime.tryParse(day['date']?.toString() ?? '');
    final start = _clock(day['startTime']);
    final end = _clock(day['endTime']);
    final hasShift = state.status.isEmpty;
    final label = day['label']?.toString() ?? '';
    Duration? length;
    if (start != null && end != null) {
      length = end.difference(start);
      if (length.isNegative) length += const Duration(days: 1);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isToday ? MobileUi.primary.withValues(alpha: 0.55) : Colors.transparent,
          width: 1.4,
        ),
        boxShadow: MobileUi.softShadow,
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 60,
            decoration: BoxDecoration(
              gradient: isToday ? MobileUi.primaryGradient : null,
              color: isToday ? null : state.color.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  date == null ? '—' : '${date.day}',
                  style: MobileUi.text(
                    20,
                    weight: FontWeight.w800,
                    color: isToday ? Colors.white : state.color,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  date == null
                      ? _weekdayName((day['weekday'] as num?)?.toInt() ?? 0)
                      : weekdayShort(l10n, date),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MobileUi.text(
                    11,
                    weight: FontWeight.w700,
                    color: isToday ? Colors.white70 : MobileUi.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        hasShift ? label : state.status,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MobileUi.text(
                          15,
                          weight: FontWeight.w800,
                          color: hasShift ? MobileUi.ink : state.color,
                        ),
                      ),
                    ),
                    if (isToday) ...[
                      const SizedBox(width: 6),
                      MobileChip(label: context.t('m.today'), color: MobileUi.primary),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                if (start != null && end != null)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.schedule_rounded, size: 15, color: MobileUi.muted),
                          const SizedBox(width: 4),
                          Text(
                            '${formatClock(l10n, start)} – ${formatClock(l10n, end)}',
                            textDirection: TextDirection.ltr,
                            style: MobileUi.text(12.5, weight: FontWeight.w700, color: const Color(0xFF475569)),
                          ),
                        ],
                      ),
                      if (length != null && length > Duration.zero)
                        MobileChip(
                          label: formatDuration(l10n, length),
                          icon: Icons.timelapse_rounded,
                          color: MobileTone.success,
                        ),
                    ],
                  )
                else
                  Text(
                    date == null ? '' : '${date.day} ${monthShort(l10n, date)} ${date.year}',
                    style: MobileUi.text(12, weight: FontWeight.w500, color: MobileUi.muted),
                  ),
                if (day['fromPattern'] == true) ...[
                  const SizedBox(height: 6),
                  MobileChip(
                    label: context.t('schedule.fromPattern'),
                    icon: Icons.auto_awesome_rounded,
                    color: MobileTone.violet,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          MobileIconBadge(icon: state.icon, color: state.color, size: 36),
        ],
      ),
    );
  }

  Widget _mobileTeam(AppLocalizations l10n, Map<String, dynamic> section) {
    final members = ((section['members'] as List?) ?? []).cast<Map<String, dynamic>>();
    final dates = [
      for (final d in _days) DateTime.tryParse(d['date']?.toString() ?? ''),
    ];
    return Container(
      decoration: MobileUi.card(),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  section['department']?.toString() ?? '',
                  style: MobileUi.text(15, weight: FontWeight.w800),
                ),
              ),
              MobileChip(label: '${members.length}', icon: Icons.person_rounded),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final d in dates)
                Expanded(
                  child: Text(
                    d == null ? '' : weekdayShort(l10n, d),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: MobileUi.text(10.5, weight: FontWeight.w700, color: MobileUi.muted),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          for (final member in members) _mobileTeamMember(member),
        ],
      ),
    );
  }

  Widget _mobileTeamMember(Map<String, dynamic> member) {
    final self = member['isSelf'] == true;
    final days = ((member['days'] as List?) ?? []).cast<Map<String, dynamic>>();
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: BoxDecoration(
        color: self ? MobileUi.primarySoft : const Color(0xFFF7F9FD),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MobileAvatar(name: member['name']?.toString() ?? '', size: 26),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  member['name']?.toString() ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MobileUi.text(13, weight: self ? FontWeight.w800 : FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final day in days)
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                    decoration: BoxDecoration(
                      color: _mobileState(day).color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      day['label']?.toString().isNotEmpty == true ? day['label'].toString() : '—',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MobileUi.text(10, weight: FontWeight.w700, color: _mobileState(day).color),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isNativeMobile) return _buildMobile();
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
