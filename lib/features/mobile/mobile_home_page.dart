import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/injection.dart';
import '../../core/router/app_router.dart';
import '../../core/utils/api_error_message.dart';
import '../../core/utils/feature_entitlements.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_cubit.dart';
import '../auth/auth_state.dart';
import '../dashboard/widgets/dashboard_quick_actions.dart';
import '../shell/shell_nav.dart';
import 'mobile_punch_controller.dart';
import 'mobile_ui.dart';
import 'swipe_to_punch.dart';

/// Native mobile home for every role: week strip, today's attendance (own
/// punches for employees, live KPIs for HR / branch managers), swipe-to-punch
/// when the branch allows GPS punches, and recent activity or shortcuts.
class MobileHomePage extends StatefulWidget {
  const MobileHomePage({super.key});

  @override
  State<MobileHomePage> createState() => _MobileHomePageState();
}

class _MobileHomePageState extends State<MobileHomePage> {
  late final DateTime _today = DateUtils.dateOnly(DateTime.now());
  late DateTime _selected = _today;

  final Map<String, Map<String, dynamic>> _byDate = {};
  bool _attendanceLoading = true;
  bool _attendanceFailed = false;

  Map<String, dynamic> _stats = {};
  bool _statsLoading = true;

  final _punch = MobilePunchController();
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
    // Keeps "work hours in progress" ticking while the page is open.
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _punch.dispose();
    super.dispose();
  }

  bool _isStaff(AuthState a) => a.roles.isHrStaff || a.roles.isBranchManager;

  bool _showOwnAttendance(AuthState a) =>
      !_isStaff(a) || a.roles.isEmployee || a.employeeId != null;

  bool _canPunch(BuildContext context, AuthState a) {
    final inMenu = navItemsFromMenus(context, a.menus)
        .any((n) => n.route == AppRoutes.myLocationPunch);
    return (inMenu || a.features.mobileLocationPunch) &&
        isRouteEntitled(a, AppRoutes.myLocationPunch);
  }

  Future<void> _load() async {
    final auth = context.read<AuthCubit>().state;
    await Future.wait([
      if (_showOwnAttendance(auth)) _loadAttendance(),
      if (_isStaff(auth)) _loadStats(),
      if (_canPunch(context, auth)) _punch.refresh(),
    ]);
  }

  Future<void> _loadAttendance() async {
    setState(() => _attendanceLoading = true);
    final weekStart = _today.subtract(const Duration(days: 14));
    final monthStart = DateTime(weekStart.year, weekStart.month, 1);
    try {
      final items = await api.myAttendance(
        dateFrom: isoDate(monthStart),
        dateTo: isoDate(_today),
      );
      if (!mounted) return;
      setState(() {
        _byDate
          ..clear()
          ..addEntries(items.map((e) {
            final d = e['date']?.toString() ?? '';
            return MapEntry(d.length >= 10 ? d.substring(0, 10) : d, e);
          }));
        _attendanceLoading = false;
        _attendanceFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _attendanceLoading = false;
        _attendanceFailed = true;
      });
    }
  }

  Future<void> _loadStats() async {
    setState(() => _statsLoading = true);
    try {
      final stats = await api.dashboardStats();
      if (mounted) setState(() => _stats = stats);
    } catch (_) {
      // KPI tiles fall back to zero.
    } finally {
      if (mounted) setState(() => _statsLoading = false);
    }
  }

  Future<void> _doPunch() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final checkedIn = await _punch.punch();
      messenger.showSnackBar(_snack(
        l10n.t(checkedIn ? 'm.checkedIn' : 'm.checkedOut'),
        success: true,
      ));
      if (mounted && _showOwnAttendance(context.read<AuthCubit>().state)) {
        _loadAttendance();
      }
    } on PunchGeoIssue catch (issue) {
      messenger.showSnackBar(_snack(_geoMessage(l10n, issue)));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(_snack(friendlyApiError(context, e)));
    }
  }

  SnackBar _snack(String text, {bool success = false}) => SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: success ? MobileTone.success : MobileTone.danger,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Row(
          children: [
            Icon(
              success ? Icons.check_circle_rounded : Icons.error_outline_rounded,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text, style: MobileUi.text(14, color: Colors.white)),
            ),
          ],
        ),
      );

  void _open(String route) {
    final auth = context.read<AuthCubit>().state;
    if (!isRouteEntitled(auth, route)) {
      final feat = featureKeyForRoute(route);
      context.go(feat != null
          ? AppRoutes.accessDeniedFeature(feat)
          : AppRoutes.accessDeniedRole());
      return;
    }
    context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthCubit>().state;
    final l10n = AppLocalizations.of(context);
    final staff = _isStaff(auth);
    final own = _showOwnAttendance(auth) && !(staff && _attendanceFailed);
    final canPunch = _canPunch(context, auth);

    var i = 0;
    Widget enter(Widget child) => child
        .animate(delay: Duration(milliseconds: 70 * i++))
        .fadeIn(duration: 380.ms)
        .slideY(begin: 0.06, end: 0, duration: 380.ms, curve: Curves.easeOut);

    return ColoredBox(
      color: MobileUi.background,
      child: RefreshIndicator(
        color: MobileUi.primary,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 48),
          children: [
            enter(_hero(context, own)),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
            if (auth.profileWarning != null) ...[
              _WarningBanner(message: auth.profileWarning!),
              const SizedBox(height: 14),
            ],
            enter(_WeekStrip(
              today: _today,
              selected: _selected,
              hasRecord: (d) => _byDate[isoDate(d)]?['firstCheckIn'] != null ||
                  _byDate[isoDate(d)]?['checkIn'] != null,
              onSelect: own ? (d) => setState(() => _selected = d) : null,
            )),
            const SizedBox(height: 26),
            if (staff) ...[
              enter(_SectionTitle(title: l10n.t('m.todayOverview'))),
              const SizedBox(height: 12),
              enter(_kpiGrid(context, auth)),
              const SizedBox(height: 26),
            ],
            if (canPunch)
              ListenableBuilder(
                listenable: _punch,
                builder: (context, _) => _punchSection(context),
              ),
            if (staff) ...[
              enter(_SectionTitle(title: l10n.t('m.shortcuts'))),
              const SizedBox(height: 12),
              enter(_shortcuts(context, auth)),
              const SizedBox(height: 26),
            ],
            if (own) ...[
              enter(_SectionTitle(
                title: l10n.t('m.yourActivity'),
                action: isRouteEntitled(auth, AppRoutes.myAttendance)
                    ? l10n.t('m.viewAll')
                    : null,
                onAction: () => _open(AppRoutes.myAttendance),
              )),
              const SizedBox(height: 12),
              enter(_activity(context)),
            ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Attendance ────────────────────────────────────────────────────────────

  Widget _attendanceGrid(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final r = _byDate[isoDate(_selected)];
    final inAt = parseWallClock(r?['firstCheckIn'] ?? r?['checkIn']);
    final outAt = parseWallClock(r?['lastCheckOut'] ?? r?['checkOut']);
    final status = (r?['status'] ?? '').toString().toLowerCase();
    final isToday = DateUtils.isSameDay(_selected, _today);

    final (inSub, inColor) = inAt == null
        ? switch (status) {
            'absent' => (l10n.t('m.absent'), MobileTone.danger),
            'leave' || 'off' => (l10n.t('m.leave'), MobileTone.info),
            _ => (l10n.t('m.notYet'), MobileUi.muted),
          }
        : status == 'late'
            ? (l10n.t('m.late'), MobileTone.warning)
            : (l10n.t('m.onTime'), MobileTone.success);

    String hours = '--';
    String hoursSub = '';
    if (inAt != null && outAt != null && outAt.isAfter(inAt)) {
      hours = formatDuration(l10n, outAt.difference(inAt));
    } else if (inAt != null && isToday) {
      hours = formatDuration(l10n, wallClockNow(inAt).difference(inAt));
      hoursSub = l10n.t('m.inProgress');
    }

    final monthDays = _byDate.entries.where((e) {
      final d = DateTime.tryParse(e.key);
      return d != null &&
          d.year == _selected.year &&
          d.month == _selected.month &&
          (e.value['firstCheckIn'] ?? e.value['checkIn']) != null;
    }).length;

    final loading = _attendanceLoading;
    final (String, Color)? state = loading
        ? null
        : inAt == null
            ? switch (status) {
                'absent' => (l10n.t('m.absent'), MobileTone.danger),
                'leave' || 'off' => (l10n.t('m.leave'), MobileTone.info),
                _ => isToday ? (l10n.t('m.notPunched'), MobileTone.warning) : null,
              }
            : outAt == null && isToday
                ? (l10n.t('m.atWork'), MobileTone.success)
                : outAt != null
                    ? (l10n.t('m.dayDone'), MobileUi.primary)
                    : null;

    final dayText = '${weekdayShort(l10n, _selected)}${l10n.isAr ? '،' : ','} '
        '${_selected.day} ${monthShort(l10n, _selected)} ${_selected.year}';

    return _MyDayCard(
      title: isToday
          ? l10n.t('m.myAttendanceCard')
          : l10n.t('m.dayAttendance', {
              'day': '${_selected.day} ${monthShort(l10n, _selected)}',
            }),
      big: isToday
          ? formatClock(l10n, DateTime.now())
          : '${_selected.day} ${monthShort(l10n, _selected)}',
      date: dayText,
      state: state,
      inLabel: l10n.t('m.checkIn'),
      inTime: loading ? '…' : formatClock(l10n, inAt),
      inTag: inAt == null ? null : (inSub, inColor),
      outLabel: l10n.t('m.checkOut'),
      outTime: loading ? '…' : formatClock(l10n, outAt),
      outTag: outAt == null ? null : (l10n.t('m.goHome'), MobileUi.muted),
      hoursLabel: l10n.t('m.workHours'),
      hours: loading ? '…' : hours,
      hoursTag: hoursSub.isEmpty ? null : (hoursSub, MobileUi.primary),
      monthLabel: '${l10n.t('m.totalDays')} · ${l10n.t('m.thisMonth')}',
      monthDays: loading ? '…' : monthDays.toString().padLeft(2, '0'),
    );
  }

  Widget _heroGreeting(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: _MyDayCard.decoration,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatClock(l10n, DateTime.now()),
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: MobileUi.ink,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${weekdayShort(l10n, _today)}${l10n.isAr ? '،' : ','} '
                  '${_today.day} ${monthShort(l10n, _today)} ${_today.year}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: MobileUi.muted,
                  ),
                ),
              ],
            ),
          ),
          const MobileIconBadge(icon: Icons.insights_rounded, size: 48),
        ],
      ),
    );
  }

  Widget _hero(BuildContext context, bool own) {
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 92,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF2357E8), Color(0xFF2A62EE)],
              ),
              borderRadius:
                  BorderRadius.vertical(bottom: Radius.circular(32)),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          child: own ? _attendanceGrid(context) : _heroGreeting(context),
        ),
      ],
    );
  }

  Widget _activity(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_attendanceLoading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
      );
    }
    final since = _today.subtract(const Duration(days: 14));
    final entries = <_ActivityEntry>[];
    final dates = _byDate.keys.toList()..sort((a, b) => b.compareTo(a));
    for (final key in dates) {
      final day = DateTime.tryParse(key);
      if (day == null || day.isBefore(since)) continue;
      final r = _byDate[key]!;
      final inAt = parseWallClock(r['firstCheckIn'] ?? r['checkIn']);
      final outAt = parseWallClock(r['lastCheckOut'] ?? r['checkOut']);
      final late = (r['status'] ?? '').toString().toLowerCase() == 'late';
      if (outAt != null) entries.add(_ActivityEntry(day, outAt, false, false));
      if (inAt != null) entries.add(_ActivityEntry(day, inAt, true, late));
      if (entries.length >= 6) break;
    }

    if (entries.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        decoration: MobileUi.card(),
        child: Column(
          children: [
            const MobileIconBadge(icon: Icons.event_busy_outlined, size: 44),
            const SizedBox(height: 10),
            Text(
              l10n.t('m.noActivity'),
              textAlign: TextAlign.center,
              style: MobileUi.text(13, weight: FontWeight.w500, color: MobileUi.muted),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (final e in entries.take(6))
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ActivityRow(entry: e),
          ),
      ],
    );
  }

  // ── Punch ─────────────────────────────────────────────────────────────────

  String _geoMessage(AppLocalizations l10n, PunchGeoIssue issue) =>
      switch (issue) {
        PunchGeoIssue.serviceOff => l10n.t('m.gpsOff'),
        PunchGeoIssue.denied => l10n.t('m.gpsDenied'),
        PunchGeoIssue.error => l10n.t('m.gpsError'),
      };

  Widget _punchSection(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = _punch;
    if (p.loading && p.context == null) return const SizedBox.shrink();
    if (!p.enabled) return const SizedBox.shrink();

    final distance = p.distance;
    final String hint;
    final Color hintColor;
    if (p.geoIssue != null) {
      hint = _geoMessage(l10n, p.geoIssue!);
      hintColor = MobileTone.warning;
    } else if (distance == null) {
      hint = l10n.t('m.locating');
      hintColor = MobileUi.muted;
    } else if (p.inside) {
      hint = l10n.t('m.insideRange', {'distance': distance.round()});
      hintColor = MobileTone.success;
    } else {
      hint = l10n.t('m.outsideRange', {
        'distance': distance.round(),
        'radius': p.radius.round(),
      });
      hintColor = MobileTone.danger;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwipeToPunch(
            label: l10n.t(p.nextIsCheckIn ? 'm.swipeCheckIn' : 'm.swipeCheckOut'),
            busyLabel: l10n.t('m.punching'),
            checkOut: !p.nextIsCheckIn,
            busy: p.busy,
            enabled: p.inside || p.geoIssue != null,
            onCompleted: _doPunch,
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.place_outlined, size: 16, color: hintColor),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  [
                    if (p.branchName.isNotEmpty) p.branchName,
                    hint,
                  ].join(' · '),
                  textAlign: TextAlign.center,
                  style: MobileUi.text(12.5, weight: FontWeight.w600, color: hintColor),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 380.ms);
  }

  // ── Staff ─────────────────────────────────────────────────────────────────

  int _stat(String key, [String? alt]) =>
      ((_stats[key] ?? (alt == null ? null : _stats[alt])) as num?)?.toInt() ?? 0;

  Widget _kpiGrid(BuildContext context, AuthState auth) {
    final l10n = AppLocalizations.of(context);
    String v(int n) => _statsLoading ? '…' : n.toString();
    final tiles = <(String route, Widget tile)>[
      (
        AppRoutes.hrEmployees,
        _StatTile(
          icon: Icons.people_outline_rounded,
          title: l10n.t('employees.title'),
          value: v(_stat('employeesCount', 'employees')),
          subtitle: l10n.t('stat.activeEmployeesSub'),
          onTap: () => _open(AppRoutes.hrEmployees),
        ),
      ),
      (
        AppRoutes.hrAttendance,
        _StatTile(
          icon: Icons.fact_check_outlined,
          color: MobileTone.success,
          title: l10n.t('stat.attendanceToday'),
          value: v(_stat('attendanceToday')),
          subtitle: l10n.t('m.todayAttendance'),
          onTap: () => _open(AppRoutes.hrAttendance),
        ),
      ),
      (
        AppRoutes.requests,
        _StatTile(
          icon: Icons.pending_actions_outlined,
          color: MobileTone.warning,
          title: l10n.t('stat.pendingRequests'),
          value: v(_stat('pendingRequests')),
          subtitle: l10n.t('stat.pendingRequestsSub'),
          onTap: () => _open(AppRoutes.requests),
        ),
      ),
      (
        AppRoutes.hrPayroll,
        _StatTile(
          icon: Icons.payments_outlined,
          color: MobileTone.violet,
          title: l10n.t('stat.payrollsDraft'),
          value: v(_stat('payrollsDraft')),
          subtitle: l10n.t('stat.payrollsDraftSub'),
          onTap: () => _open(AppRoutes.hrPayroll),
        ),
      ),
      if (auth.roles.isBranchManager && !auth.roles.isHrStaff)
        (
          AppRoutes.hrHiringAppointments,
          _StatTile(
            icon: Icons.assignment_ind_outlined,
            color: MobileTone.info,
            title: l10n.t('stat.newHiring'),
            value: v(_stat('hiringUnread')),
            subtitle: l10n.t('stat.newHiringSub'),
            onTap: () => _open(AppRoutes.hrHiringAppointments),
          ),
        ),
    ];
    final menuRoutes = auth.menus.map((m) => m.route).toSet();
    final visible = tiles
        .where((t) =>
            isRouteEntitled(auth, t.$1) &&
            (auth.roles.isHrStaff || menuRoutes.any((r) => t.$1.startsWith(r))))
        .map((t) => t.$2)
        .toList();
    if (visible.isEmpty) return const SizedBox.shrink();
    return _Grid(children: visible);
  }

  Widget _shortcuts(BuildContext context, AuthState auth) {
    final raw = auth.roles.isHrStaff
        ? DashboardQuickActions.hrActions(
            context,
            pendingRequests: _stat('pendingRequests'),
            healthCertAlerts: _stat('healthCertAlerts'),
            hiringUnread: _stat('hiringUnread'),
            unreadAbsences: _stat('absentUnread'),
          )
        : DashboardQuickActions.branchManagerActions(
            context,
            hiringUnread: _stat('hiringUnread'),
          );
    final actions = DashboardQuickActions.entitledOnly(auth, raw);
    if (actions.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(builder: (context, c) {
      const gap = 12.0;
      final w = (c.maxWidth - gap * 2) / 3;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final a in actions)
            SizedBox(
              width: w,
              child: _ShortcutTile(action: a, onTap: () => _open(a.route)),
            ),
        ],
      );
    });
  }
}

// ── Pieces ──────────────────────────────────────────────────────────────────

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    required this.today,
    required this.selected,
    required this.hasRecord,
    this.onSelect,
  });

  final DateTime today;
  final DateTime selected;
  final bool Function(DateTime) hasRecord;
  final ValueChanged<DateTime>? onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final days = [for (var i = 4; i >= 0; i--) today.subtract(Duration(days: i))];
    return Row(
      children: [
        for (final d in days) ...[
          if (d != days.first) const SizedBox(width: 10),
          Expanded(
            child: _DayChip(
              day: d,
              weekday: weekdayShort(l10n, d),
              selected: DateUtils.isSameDay(d, selected),
              dot: hasRecord(d),
              onTap: onSelect == null ? null : () => onSelect!(d),
            ),
          ),
        ],
      ],
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.day,
    required this.weekday,
    required this.selected,
    required this.dot,
    this.onTap,
  });

  final DateTime day;
  final String weekday;
  final bool selected;
  final bool dot;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : MobileUi.ink;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: selected ? MobileUi.primaryGradient : null,
          color: selected ? null : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? Colors.transparent : const Color(0xFFEDF1F7),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: MobileUi.primary.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ]
              : MobileUi.softShadow,
        ),
        child: Column(
          children: [
            Text(
              day.day.toString().padLeft(2, '0'),
              style: MobileUi.text(20, weight: FontWeight.w800, color: fg, height: 1.1),
            ),
            const SizedBox(height: 2),
            FittedBox(
              child: Text(
                weekday,
                style: MobileUi.text(
                  11.5,
                  weight: FontWeight.w500,
                  color: selected ? Colors.white.withValues(alpha: 0.85) : MobileUi.muted,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dot
                    ? (selected ? Colors.white : MobileTone.success)
                    : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: MobileUi.sectionTitle)),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Text(
              action!,
              style: MobileUi.text(13, weight: FontWeight.w700, color: MobileUi.primary),
            ),
          ),
      ],
    );
  }
}

/// Two-column grid whose rows size to their tallest tile.
class _Grid extends StatelessWidget {
  const _Grid({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += 2) {
      if (i > 0) rows.add(const SizedBox(height: 12));
      rows.add(IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: children[i]),
            const SizedBox(width: 12),
            Expanded(
              child: i + 1 < children.length ? children[i + 1] : const SizedBox(),
            ),
          ],
        ),
      ));
    }
    return Column(children: rows);
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    this.color = MobileUi.primary,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MobileUi.radius),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: MobileUi.card(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  MobileIconBadge(icon: icon, color: color, size: 32),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: MobileUi.text(12.5, weight: FontWeight.w700, color: MobileUi.muted, height: 1.25),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              const SizedBox(height: 12),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  value,
                  textDirection: TextDirection.ltr,
                  style: MobileUi.text(22, weight: FontWeight.w800, height: 1.1),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: MobileUi.text(
                  11.5,
                  weight: FontWeight.w600,
                  color: MobileUi.muted,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The signed-in employee's day: status plus check-in and check-out times.
class _MyDayCard extends StatelessWidget {
  const _MyDayCard({
    required this.title,
    required this.big,
    required this.date,
    required this.state,
    required this.inLabel,
    required this.inTime,
    required this.inTag,
    required this.outLabel,
    required this.outTime,
    required this.outTag,
    required this.hoursLabel,
    required this.hours,
    required this.hoursTag,
    required this.monthLabel,
    required this.monthDays,
  });

  static final decoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(26),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF1E3A8A).withValues(alpha: 0.14),
        blurRadius: 26,
        offset: const Offset(0, 12),
      ),
    ],
  );

  final String title;
  final String big;
  final String date;
  final (String, Color)? state;
  final String inLabel;
  final String inTime;
  final (String, Color)? inTag;
  final String outLabel;
  final String outTime;
  final (String, Color)? outTag;
  final String hoursLabel;
  final String hours;
  final (String, Color)? hoursTag;
  final String monthLabel;
  final String monthDays;

  Widget _bigText() {
    final cut = big.lastIndexOf(' ');
    if (!big.contains(':') || cut < 0) {
      return Text(big, style: MobileUi.text(30, weight: FontWeight.w800, height: 1.15));
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          big.substring(0, cut),
          textDirection: TextDirection.ltr,
          style: MobileUi.text(32, weight: FontWeight.w800, height: 1.15),
        ),
        const SizedBox(width: 6),
        Text(
          big.substring(cut + 1),
          style: MobileUi.text(15, weight: FontWeight.w700, color: MobileUi.muted),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final divider = Container(
      width: 1,
      margin: const EdgeInsets.symmetric(vertical: 6),
      color: const Color(0xFFE3E9F5),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: decoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.fingerprint_rounded, size: 17, color: MobileUi.primary),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            title,
                            style: MobileUi.text(12.5, weight: FontWeight.w800, color: MobileUi.primary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: _bigText(),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      date,
                      style: MobileUi.text(12, weight: FontWeight.w600, color: MobileUi.muted),
                    ),
                  ],
                ),
              ),
              if (state != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.fromLTRB(11, 6, 11, 6),
                  decoration: BoxDecoration(
                    color: state!.$2.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: state!.$2.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(color: state!.$2, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        state!.$1,
                        style: MobileUi.text(12, weight: FontWeight.w800, color: state!.$2, height: 1.2),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F8FE),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE8EEF9)),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _HeroStat(
                      icon: Icons.login_rounded,
                      color: MobileTone.success,
                      label: inLabel,
                      value: inTime,
                      tag: inTag,
                    ),
                  ),
                  divider,
                  Expanded(
                    child: _HeroStat(
                      icon: Icons.logout_rounded,
                      color: const Color(0xFFF2552C),
                      label: outLabel,
                      value: outTime,
                      tag: outTag,
                    ),
                  ),
                  divider,
                  Expanded(
                    child: _HeroStat(
                      icon: Icons.timer_outlined,
                      color: MobileUi.primary,
                      label: hoursLabel,
                      value: hours,
                      tag: hoursTag,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: MobileTone.violet.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.calendar_month_rounded, size: 16, color: MobileTone.violet),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  monthLabel,
                  style: MobileUi.text(12.5, weight: FontWeight.w700, color: MobileUi.muted),
                ),
              ),
              Text(
                monthDays,
                style: MobileUi.text(17, weight: FontWeight.w800, color: MobileTone.violet),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.tag,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final (String, Color)? tag;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: MobileUi.text(11.5, weight: FontWeight.w700, color: MobileUi.muted, height: 1.2),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              textDirection: TextDirection.ltr,
              style: MobileUi.text(16, weight: FontWeight.w800, height: 1.15),
            ),
          ),
          if (tag != null) ...[
            const SizedBox(height: 3),
            Text(
              tag!.$1,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MobileUi.text(10.5, weight: FontWeight.w700, color: tag!.$2),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActivityEntry {
  const _ActivityEntry(this.day, this.time, this.checkIn, this.late);
  final DateTime day;
  final DateTime time;
  final bool checkIn;
  final bool late;
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.entry});
  final _ActivityEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final e = entry;
    final color = e.checkIn ? MobileUi.primary : const Color(0xFFF2552C);
    final (tag, tagColor) = !e.checkIn
        ? (l10n.t('m.goHome'), MobileUi.muted)
        : e.late
            ? (l10n.t('m.late'), MobileTone.warning)
            : (l10n.t('m.onTime'), MobileTone.success);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: MobileUi.card(r: 16),
      child: Row(
        children: [
          MobileIconBadge(
            icon: e.checkIn ? Icons.login_rounded : Icons.logout_rounded,
            color: color,
            size: 42,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.t(e.checkIn ? 'm.checkIn' : 'm.checkOut'),
                  style: MobileUi.text(15, weight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '${weekdayShort(l10n, e.day)}${l10n.isAr ? '،' : ','} ${e.day.day} ${monthShort(l10n, e.day)}',
                  style: MobileUi.text(12, weight: FontWeight.w500, color: MobileUi.muted),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatClock(l10n, e.time),
                textDirection: TextDirection.ltr,
                style: MobileUi.text(15, weight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                tag,
                style: MobileUi.text(12, weight: FontWeight.w600, color: tagColor),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile({required this.action, required this.onTap});

  final DashboardQuickAction action;
  final VoidCallback onTap;

  Color get _color => switch (action.tone) {
        QuickActionTone.success => MobileTone.success,
        QuickActionTone.warning => MobileTone.warning,
        QuickActionTone.info => MobileTone.info,
        QuickActionTone.primary => MobileUi.primary,
      };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MobileUi.radius),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(8, 14, 8, 12),
          decoration: MobileUi.card(),
          child: Column(
            children: [
              Badge(
                isLabelVisible: action.badge != null,
                label: Text(action.badge ?? ''),
                child: MobileIconBadge(icon: action.icon, color: _color, size: 44),
              ),
              const SizedBox(height: 8),
              Text(
                action.label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: MobileUi.text(12.5, weight: FontWeight.w700, height: 1.25),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WarningBanner extends StatelessWidget {
  const _WarningBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFFB45309), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: MobileUi.text(12.5, weight: FontWeight.w500, color: const Color(0xFF92400E)),
            ),
          ),
        ],
      ),
    );
  }
}
